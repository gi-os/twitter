import ComposableArchitecture
import XAPI

@Reducer
struct ProfileFeature {
  @ObservableState
  struct State: Equatable {
    var errorMessage: String?
    var feeds: FeedsFeature.State?
    var isViewer = false
    let screenName: String
    var user: XUser?

    init(user: XUser, isViewer: Bool = false) {
      screenName = user.screenName
      self.isViewer = isViewer
      self.user = user
      feeds = Self.feeds(for: user, isViewer: isViewer)
    }

    init(screenName: String) {
      self.screenName = screenName
    }

    static func feeds(for user: XUser, isViewer: Bool) -> FeedsFeature.State {
      var sources: [FeedSource] = [
        .userPosts(userID: user.id), .userReplies(userID: user.id), .userMedia(userID: user.id),
      ]
      if isViewer { sources.append(.userLikes(userID: user.id)) }
      return FeedsFeature.State(sources: sources)
    }
  }

  enum Action {
    case delegate(ContentDelegate)
    case feeds(FeedsFeature.Action)
    case followButtonTapped
    case followFailed
    case signOutButtonTapped
    case task
    case userResponse(Result<XUser, any Error>)
  }

  @Dependency(XClient.self) var client

  var body: some Reducer<State, Action> {
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
        let screenName = state.screenName
        return .run { send in
          await send(.userResponse(Result { try await client.user(screenName) }))
        }

      case .userResponse(.success(let user)):
        state.errorMessage = nil
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
