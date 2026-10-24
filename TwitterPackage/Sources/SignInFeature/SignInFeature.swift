import ComposableArchitecture
import Models
import TwitterClient

@Reducer
package struct SignInFeature {
    @ObservableState
    package struct State: Equatable {
        var attempt = 0
        var errorMessage: String?
        var isPageLoading = true
        var isSigningIn = false

        package init() {}
    }

    package enum Action {
        case delegate(Delegate)
        case pageLoadingChanged(Bool)
        case sessionCaptured([String: String])
        case signInResponse(Result<User, any Error>)
        case retryButtonTapped

        package enum Delegate {
            case signedIn(User)
        }
    }

    @Dependency(TwitterClient.self) var client

    package init() {}

    package var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

            case .pageLoadingChanged(let isLoading):
                state.isPageLoading = isLoading
                return .none

            case .sessionCaptured(let cookies):
                guard !state.isSigningIn else { return .none }
                state.isSigningIn = true
                return .run { send in
                    await send(.signInResponse(Result { try await client.signIn(cookies) }))
                }

            case .signInResponse(.success(let viewer)):
                state.isSigningIn = false
                return .send(.delegate(.signedIn(viewer)))

            case .signInResponse(.failure(let error)):
                state.isSigningIn = false
                state.errorMessage = error.localizedDescription
                return .none

            case .retryButtonTapped:
                state.errorMessage = nil
                state.attempt += 1
                return .none
            }
        }
    }
}
