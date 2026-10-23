import ComposableArchitecture
import XAPI

@Reducer
enum TabRoot {
  case feeds(FeedsFeature)
  case profile(ProfileFeature)
  case search(SearchFeature)
}

extension TabRoot.State: Equatable {}

@Reducer
enum TabStackPath {
  case profile(ProfileFeature)
  case search(SearchFeature)
  case thread(FeedFeature)
}

extension TabStackPath.State: Equatable {}

@Reducer
struct TabStack {
  @ObservableState
  struct State: Equatable {
    var path = StackState<TabStackPath.State>()
    var root: TabRoot.State
  }

  enum Action {
    case composeButtonTapped
    case delegate(ContentDelegate)
    case path(StackActionOf<TabStackPath>)
    case root(TabRoot.Action)
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.root, action: \.root) {
      TabRoot.body
    }
    Reduce { state, action in
      switch action {
      case .composeButtonTapped:
        return .send(.delegate(.compose(Draft())))

      case .delegate:
        return .none

      case .path(.element(_, let action)):
        guard let delegate = action.contentDelegate else { return .none }
        if case .open(let route) = delegate {
          state.path.append(route.pathState)
          return .none
        }
        return .send(.delegate(delegate))

      case .path:
        return .none

      case .root(let action):
        guard let delegate = action.contentDelegate else { return .none }
        if case .open(let route) = delegate {
          state.path = StackState([route.pathState])
          return .none
        }
        return .send(.delegate(delegate))
      }
    }
    .forEach(\.path, action: \.path)
  }
}

extension Route {
  var pathState: TabStackPath.State {
    switch self {
    case .profile(let user):
      .profile(ProfileFeature.State(user: user))
    case .profileHandle(let screenName):
      .profile(ProfileFeature.State(screenName: screenName))
    case .search(let query):
      .search(SearchFeature.State(submitting: query))
    case .thread(let tweet):
      .thread(
        FeedFeature.State(
          source: .thread(tweetID: tweet.id),
          items: [.tweet(FeedTweet(tweet: tweet))]
        )
      )
    }
  }
}

extension TabRoot.Action {
  var contentDelegate: ContentDelegate? {
    switch self {
    case .feeds(.delegate(let delegate)), .profile(.delegate(let delegate)), .search(.delegate(let delegate)):
      delegate
    default:
      nil
    }
  }
}

extension TabStackPath.Action {
  var contentDelegate: ContentDelegate? {
    switch self {
    case .profile(.delegate(let delegate)), .search(.delegate(let delegate)), .thread(.delegate(let delegate)):
      delegate
    default:
      nil
    }
  }
}
