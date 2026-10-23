import ComposableArchitecture
import XAPI

@Reducer
struct FeedsFeature {
  @ObservableState
  struct State: Equatable {
    var feeds: IdentifiedArrayOf<FeedFeature.State>
    var selection: FeedSource

    init(sources: [FeedSource], selection: FeedSource? = nil) {
      precondition(!sources.isEmpty)
      feeds = IdentifiedArray(uniqueElements: sources.map { FeedFeature.State(source: $0) })
      self.selection = selection ?? sources[0]
    }

    init(feed: FeedFeature.State) {
      feeds = [feed]
      selection = feed.source
    }

    var title: String {
      feeds.count == 1 ? selection.title : ""
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case delegate(ContentDelegate)
    case feeds(IdentifiedActionOf<FeedFeature>)
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding, .delegate:
        return .none

      case .feeds(.element(_, .delegate(let delegate))):
        return .send(.delegate(delegate))

      case .feeds:
        return .none
      }
    }
    .forEach(\.feeds, action: \.feeds) {
      FeedFeature()
    }
  }
}
