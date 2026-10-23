import ComposableArchitecture
import FeedFeature
import Models
import ProfileFeature
import Routing
import SearchFeature

@Reducer
package enum TabRoot {
    case feeds(FeedsFeature)
    case profile(ProfileFeature)
    case search(SearchFeature)
}

extension TabRoot.State: Equatable {}

@Reducer
package enum TabStackPath {
    case profile(ProfileFeature)
    case search(SearchFeature)
    case thread(FeedFeature)
}

extension TabStackPath.State: Equatable {}

@Reducer
package struct TabStack {
    @ObservableState
    package struct State: Equatable {
        var path = StackState<TabStackPath.State>()
        var root: TabRoot.State
    }

    package enum Action {
        case composeButtonTapped
        case delegate(ContentDelegate)
        case path(StackActionOf<TabStackPath>)
        case root(TabRoot.Action)
    }

    package init() {}

    package var body: some Reducer<State, Action> {
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
    package var pathState: TabStackPath.State {
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
    package var contentDelegate: ContentDelegate? {
        switch self {
        case .feeds(.delegate(let delegate)), .profile(.delegate(let delegate)), .search(.delegate(let delegate)):
            delegate
        default:
            nil
        }
    }
}

extension TabStackPath.Action {
    package var contentDelegate: ContentDelegate? {
        switch self {
        case .profile(.delegate(let delegate)), .search(.delegate(let delegate)), .thread(.delegate(let delegate)):
            delegate
        default:
            nil
        }
    }
}

extension TabStack.State {
    package static var bookmarks: Self {
        Self(root: .feeds(FeedsFeature.State(sources: [.bookmarks])))
    }

    package static var explore: Self {
        Self(root: .search(SearchFeature.State()))
    }

    package static var home: Self {
        Self(root: .feeds(FeedsFeature.State(sources: [.home(following: false), .home(following: true)])))
    }

    package static var notifications: Self {
        Self(
            root: .feeds(
                FeedsFeature.State(sources: [.notifications(mentionsOnly: false), .notifications(mentionsOnly: true)])
            )
        )
    }

    package static func profile(viewer: User) -> Self {
        Self(root: .profile(ProfileFeature.State(user: viewer, isViewer: true)))
    }
}
