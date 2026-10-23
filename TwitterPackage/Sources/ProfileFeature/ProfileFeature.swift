import ComposableArchitecture
import FeedFeature
import Models
import Routing
import TwitterClient
import TwitterUI

@Reducer
package struct ProfileFeature {
    @ObservableState
    package struct State: Equatable {
        var errorMessage: String?
        var feeds: FeedsFeature.State?
        var hasFetchedUser = false
        var isViewer = false
        let screenName: String
        var user: User?

        package init(user: User, isViewer: Bool = false) {
            screenName = user.screenName
            self.isViewer = isViewer
            self.user = user
            feeds = Self.feeds(for: user, isViewer: isViewer)
        }

        package init(screenName: String) {
            self.screenName = screenName
        }

        static func feeds(for user: User, isViewer: Bool) -> FeedsFeature.State {
            var sources: [FeedSource] = [
                .userPosts(userID: user.id), .userReplies(userID: user.id), .userMedia(userID: user.id)
            ]
            if isViewer { sources.append(.userLikes(userID: user.id)) }
            return FeedsFeature.State(sources: sources)
        }
    }

    package enum Action {
        case delegate(ContentDelegate)
        case feeds(FeedsFeature.Action)
        case followButtonTapped
        case followFailed
        case signOutButtonTapped
        case task
        case userResponse(Result<User, any Error>)
    }

    @Dependency(TwitterClient.self) var client

    package init() {}

    package var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

            case .feeds(.delegate(let delegate)):
                return .send(.delegate(delegate))

            case .feeds:
                return .none

            case .followButtonTapped:
                guard var user = state.user else { return .none }
                user.isFollowing.toggle()
                user.followersCount += user.isFollowing ? 1 : -1
                state.user = user
                return .run { [user] _ in
                    try await client.setFollowing(user.isFollowing, user.id)
                } catch: { _, send in
                    await send(.followFailed)
                }

            case .followFailed:
                guard var user = state.user else { return .none }
                user.isFollowing.toggle()
                user.followersCount += user.isFollowing ? 1 : -1
                state.user = user
                return .none

            case .signOutButtonTapped:
                return .send(.delegate(.signOut))

            case .task:
                guard !state.hasFetchedUser else { return .none }
                let screenName = state.screenName
                return .run { send in
                    await send(.userResponse(Result { try await client.user(screenName) }))
                }

            case .userResponse(.success(let user)):
                state.errorMessage = nil
                state.hasFetchedUser = true
                state.user = user
                if state.feeds == nil {
                    state.feeds = State.feeds(for: user, isViewer: state.isViewer)
                }
                return .none

            case .userResponse(.failure(let error)):
                if state.user == nil {
                    state.errorMessage = error.localizedDescription
                }
                return .none
            }
        }
        .ifLet(\.feeds, action: \.feeds) {
            FeedsFeature()
        }
    }
}
