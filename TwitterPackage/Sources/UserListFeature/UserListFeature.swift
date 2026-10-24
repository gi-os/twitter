import ComposableArchitecture
import Models
import Routing
import TwitterClient

/// A profile's followers or followings, or the accounts that reposted or liked a post: a column of people to follow
/// or open, paged by cursor as it scrolls.
@Reducer
package struct UserListFeature {
    @ObservableState
    package struct State: Equatable {
        var bottomCursor: String?
        var errorMessage: String?
        var hasLoaded = false
        var isLoading = false
        package let source: UserListSource
        var users: IdentifiedArrayOf<User> = []

        package init(source: UserListSource) {
            self.source = source
        }
    }

    package enum Action {
        case delegate(ContentDelegate)
        case followButtonTapped(User.ID)
        /// Carries the value to restore, so a failure that lands after another tap can't flip the wrong way.
        case followFailed(userID: User.ID, isFollowing: Bool)
        case pageResponse(Result<UserPage, any Error>, isRefresh: Bool)
        case refreshPulled
        case retryButtonTapped
        case rowAppeared(User.ID)
        case task
        case userTapped(User)
    }

    enum CancelID: Hashable {
        case page(UserListSource)
    }

    /// How close to the end of the list a row has to be for its appearing to fetch the next page.
    static let pagingDistance = 5

    @Dependency(TwitterClient.self) var client

    package init() {}

    package var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

            case .followButtonTapped(let id):
                guard var user = state.users[id: id] else { return .none }
                user.isFollowing.toggle()
                state.users[id: id] = user
                return .run { [user] _ in
                    try await client.setFollowing(user.isFollowing, user.id)
                } catch: { [user] _, send in
                    await send(.followFailed(userID: user.id, isFollowing: !user.isFollowing))
                }

            case .followFailed(let id, let isFollowing):
                state.users[id: id]?.isFollowing = isFollowing
                return .none

            case .pageResponse(.success(let page), let isRefresh):
                state.isLoading = false
                state.hasLoaded = true
                state.errorMessage = nil
                if isRefresh {
                    state.users = IdentifiedArray(page.users, uniquingIDsWith: { first, _ in first })
                    state.bottomCursor = page.bottomCursor
                } else {
                    let count = state.users.count
                    for user in page.users where state.users[id: user.id] == nil {
                        state.users.append(user)
                    }
                    // A page of nobody new means the list has run out, whatever cursor came with it.
                    state.bottomCursor = state.users.count > count ? page.bottomCursor : nil
                }
                return .none

            case .pageResponse(.failure(let error), _):
                state.isLoading = false
                state.hasLoaded = true
                state.errorMessage = error.localizedDescription
                return .none

            case .refreshPulled:
                return loadPage(state: &state, isRefresh: true)

            case .retryButtonTapped:
                return loadPage(state: &state, isRefresh: state.users.isEmpty)

            case .rowAppeared(let id):
                guard
                    let index = state.users.index(id: id),
                    index >= state.users.count - Self.pagingDistance,
                    state.bottomCursor != nil,
                    !state.isLoading,
                    state.errorMessage == nil
                else { return .none }
                return loadPage(state: &state, isRefresh: false)

            case .task:
                guard !state.hasLoaded, !state.isLoading else { return .none }
                return loadPage(state: &state, isRefresh: true)

            case .userTapped(let user):
                return .send(.delegate(.open(.profile(user))))
            }
        }
    }

    private func loadPage(state: inout State, isRefresh: Bool) -> EffectOf<Self> {
        state.isLoading = true
        state.errorMessage = nil
        let source = state.source
        let cursor = isRefresh ? nil : state.bottomCursor
        return .run { send in
            await send(.pageResponse(Result { try await client.users(source, cursor) }, isRefresh: isRefresh))
        }
        .cancellable(id: CancelID.page(source), cancelInFlight: true)
    }
}
