import ComposableArchitecture
import Models
import Routing
import TwitterClient
import TwitterUI

@Reducer
package struct ComposeFeature {
    @ObservableState
    package struct State: Equatable {
        let draft: Draft
        var errorMessage: String?
        var isPosting = false
        var text = ""

        package init(draft: Draft) {
            self.draft = draft
        }

        static let characterLimit = 280

        var remainingCharacters: Int { Self.characterLimit - text.count }
        var canPost: Bool {
            !isPosting && remainingCharacters >= 0
                && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    package enum Action: BindableAction {
        case binding(BindingAction<State>)
        case cancelButtonTapped
        case postButtonTapped
        case postResponse(Result<String, any Error>)
    }

    @Dependency(TwitterClient.self) var client
    @Dependency(\.dismiss) var dismiss

    package init() {}

    package var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .cancelButtonTapped:
                return .run { _ in await dismiss() }

            case .postButtonTapped:
                guard state.canPost else { return .none }
                state.isPosting = true
                state.errorMessage = nil
                let text = state.text
                let draft = state.draft
                return .run { send in
                    await send(
                        .postResponse(
                            Result {
                                try await client.post(text, draft.replyingTo?.id, draft.quoting?.url, [])
                            }
                        )
                    )
                }

            case .postResponse(.success):
                state.isPosting = false
                return .run { _ in await dismiss() }

            case .postResponse(.failure(let error)):
                state.isPosting = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
    }
}
