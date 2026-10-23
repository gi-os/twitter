import ComposableArchitecture
import XAPI

@Reducer
struct SearchFeature {
  @ObservableState
  struct State: Equatable {
    var query = ""
    var results: FeedsFeature.State?

    init() {}

    init(submitting query: String) {
      self.query = query
      results = Self.results(for: query)
    }

    static func results(for query: String) -> FeedsFeature.State {
      FeedsFeature.State(sources: [.search(query: query, latest: false), .search(query: query, latest: true)])
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case delegate(ContentDelegate)
    case results(FeedsFeature.Action)
    case searchSubmitted
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding(\.query):
        if state.query.isEmpty {
          state.results = nil
        }
        return .none

      case .binding, .delegate:
        return .none

      case .results(.delegate(let delegate)):
        return .send(.delegate(delegate))

      case .results:
        return .none

      case .searchSubmitted:
        let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return .none }
        state.results = State.results(for: query)
        return .none
      }
    }
    .ifLet(\.results, action: \.results) {
      FeedsFeature()
    }
  }
}
