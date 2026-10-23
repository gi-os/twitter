import ComposableArchitecture
import XAPI

@Reducer
struct MainFeature {
  @ObservableState
  struct State: Equatable {
    var bookmarks = TabStack.State(root: .feeds(FeedsFeature.State(sources: [.bookmarks])))
    @Presents var compose: ComposeFeature.State?
    var explore = TabStack.State(root: .search(SearchFeature.State()))
    var home = TabStack.State(
      root: .feeds(FeedsFeature.State(sources: [.home(following: false), .home(following: true)]))
    )
    var notifications = TabStack.State(
      root: .feeds(
        FeedsFeature.State(sources: [.notifications(mentionsOnly: false), .notifications(mentionsOnly: true)])
      )
    )
    var profile: TabStack.State
    var selectedTab = Tab.home
    var viewer: XUser

    init(viewer: XUser) {
      self.viewer = viewer
      profile = TabStack.State(root: .profile(ProfileFeature.State(user: viewer, isViewer: true)))
    }
  }

  enum Tab: Hashable {
    case bookmarks
    case explore
    case home
    case notifications
    case profile
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case bookmarks(TabStack.Action)
    case compose(PresentationAction<ComposeFeature.Action>)
    case delegate(Delegate)
    case explore(TabStack.Action)
    case home(TabStack.Action)
    case notifications(TabStack.Action)
    case profile(TabStack.Action)

    enum Delegate {
      case signedOut
    }
  }

  @Dependency(XClient.self) var client

  var body: some Reducer<State, Action> {
    BindingReducer()
    Scope(state: \.bookmarks, action: \.bookmarks) { TabStack() }
    Scope(state: \.explore, action: \.explore) { TabStack() }
    Scope(state: \.home, action: \.home) { TabStack() }
    Scope(state: \.notifications, action: \.notifications) { TabStack() }
    Scope(state: \.profile, action: \.profile) { TabStack() }
    Reduce { state, action in
      switch action {
      case .bookmarks(.delegate(let delegate)),
        .explore(.delegate(let delegate)),
        .home(.delegate(let delegate)),
        .notifications(.delegate(let delegate)),
        .profile(.delegate(let delegate)):
        switch delegate {
        case .compose(let draft):
          state.compose = ComposeFeature.State(draft: draft)
          return .none
        case .open:
          return .none
        case .signOut:
          return .run { send in
            await client.signOut()
            await send(.delegate(.signedOut))
          }
        }

      case .binding, .bookmarks, .compose, .delegate, .explore, .home, .notifications, .profile:
        return .none
      }
    }
    .ifLet(\.$compose, action: \.compose) {
      ComposeFeature()
    }
  }
}
