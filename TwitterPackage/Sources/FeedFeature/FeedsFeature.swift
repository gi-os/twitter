import ComposableArchitecture
import Models
import Routing
import TwitterClient
import TwitterUI

@Reducer
package struct FeedsFeature {
    @ObservableState
    package struct State: Equatable {
        var feeds: IdentifiedArrayOf<FeedFeature.State>
        var selection: FeedSource

        package init(sources: [FeedSource], selection: FeedSource? = nil) {
            precondition(!sources.isEmpty)
            feeds = IdentifiedArray(uniqueElements: sources.map { FeedFeature.State(source: $0) })
            self.selection = selection ?? sources[0]
        }

        package init(feed: FeedFeature.State) {
            feeds = [feed]
            selection = feed.source
        }

        var title: String {
            feeds.count == 1 ? selection.title : ""
        }
    }

    package enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(ContentDelegate)
        case feeds(IdentifiedActionOf<FeedFeature>)
    }

    package init() {}

    package var body: some Reducer<State, Action> {
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
