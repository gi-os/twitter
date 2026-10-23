import ComposableArchitecture
import MainFeature
import Models
import SignInFeature
import TwitterClient
import TwitterClientLive

@Reducer
struct AppFeature {
    @CasePathable
    @dynamicMemberLookup
    @ObservableState
    enum State: Equatable {
        case launchFailed(String)
        case launching
        case main(MainFeature.State)
        case signIn(SignInFeature.State)

        init() {
            self = .launching
        }
    }

    enum Action {
        case main(MainFeature.Action)
        case retryButtonTapped
        case sessionRestored(Result<User?, any Error>)
        case signIn(SignInFeature.Action)
        case task
    }

    @Dependency(TwitterClient.self) var client

    init() {}

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .main(.delegate(.signedOut)):
                state = .signIn(SignInFeature.State())
                return .none

            case .main:
                return .none

            case .retryButtonTapped:
                state = .launching
                return restoreSession()

            case .sessionRestored(.success(let viewer)):
                state = viewer.map { .main(MainFeature.State(viewer: $0)) } ?? .signIn(SignInFeature.State())
                return .none

            case .sessionRestored(.failure(let error)):
                state = .launchFailed(error.localizedDescription)
                return .none

            case .signIn(.delegate(.signedIn(let viewer))):
                state = .main(MainFeature.State(viewer: viewer))
                return .none

            case .signIn:
                return .none

            case .task:
                return restoreSession()
            }
        }
        .ifCaseLet(\.main, action: \.main) {
            MainFeature()
        }
        .ifCaseLet(\.signIn, action: \.signIn) {
            SignInFeature()
        }
    }

    private func restoreSession() -> EffectOf<Self> {
        .run { send in
            await send(.sessionRestored(Result { try await client.restoreSession() }))
        }
    }
}
