import ComposableArchitecture
import FeedFeature
import Routing

@Reducer
package struct SearchFeature {
    @ObservableState
    package struct State: Equatable {
        var query = ""
        @Presents var results: FeedsFeature.State?
        var submittedQuery: String?

        package init() {}

        package init(submitting query: String) {
            self.query = query
            submittedQuery = query
            results = Self.results(for: query)
        }

        static func results(for query: String) -> FeedsFeature.State {
            FeedsFeature.State(sources: [.search(query: query, latest: false), .search(query: query, latest: true)])
        }
    }

    package enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(ContentDelegate)
        case results(PresentationAction<FeedsFeature.Action>)
        case resultsCleared(query: String)
        case searchSubmitted
    }

    package init() {}

    package var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.query):
                if state.query.isEmpty {
                    state.results = nil
                    state.submittedQuery = nil
                }
                return .none

            case .binding, .delegate:
                return .none

            case .results(.presented(.delegate(let delegate))):
                return .send(.delegate(delegate))

            case .results:
                return .none

            case .resultsCleared(let query):
                state.results = State.results(for: query)
                return .none

            case .searchSubmitted:
                let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty, query != state.submittedQuery else { return .none }
                state.submittedQuery = query
                state.results = nil
                return .send(.resultsCleared(query: query))
            }
        }
        .ifLet(\.$results, action: \.results) {
            FeedsFeature()
        }
    }
}
