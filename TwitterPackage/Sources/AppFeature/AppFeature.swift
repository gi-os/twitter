import ComposableArchitecture
import MainFeature
import Models
import SignInFeature
import TweetEngagement
import TwitterClient
import TwitterClientLive
import TwitterDatabase

@Reducer
struct AppFeature {
    @CasePathable
    @dynamicMemberLookup
    @ObservableState
    enum State: Equatable {
        case launchFailed(String)
        /// Only when there's no remembered account to show while the session is restored.
        case launching
        case main(MainFeature.State)
        case signIn(SignInFeature.State)

        /// Opens straight to the account signed in last time, if there is one, so the first frame is the app and its
        /// cached timelines rather than a spinner. `task` then checks with Twitter that it's still signed in.
        init() {
            @Shared(.viewer) var viewer
            self = viewer.map { .main(MainFeature.State(viewer: $0)) } ?? .launching
        }
    }

    enum Action {
        case main(MainFeature.Action)
        case retryButtonTapped
        case restoreSessionResponse(Result<User?, any Error>)
        case signIn(SignInFeature.Action)
        case task
    }

    enum CancelID {
        case restore
    }

    @Dependency(TwitterClient.self) var client
    @Dependency(TimelineCache.self) var timelineCache
    @Shared(.engagements) var engagements
    @Shared(.viewer) var viewer

    init() {}

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .main(.delegate(.signedOut)):
                return signedOut(&state)

            case .main:
                return .none

            case .retryButtonTapped:
                state = .launching
                return restoreSession()

            case .restoreSessionResponse(.success(let viewer?)):
                if self.viewer != viewer { $viewer.withLock { $0 = viewer } }
                guard case .main(let main) = state, main.viewer.id == viewer.id else {
                    state = .main(MainFeature.State(viewer: viewer))
                    return .none
                }
                // Already showing the remembered account: just freshen it.
                if main.viewer != viewer { state.modify(\.main) { $0.viewer = viewer } }
                return .none

            case .restoreSessionResponse(.success(nil)):
                // Twitter no longer accepts the stored session (or there isn't one).
                guard case .main = state else {
                    state = .signIn(SignInFeature.State())
                    $viewer.withLock { $0 = nil }
                    return .none
                }
                return signedOut(&state)

            case .restoreSessionResponse(.failure(let error)):
                // Offline with a remembered account: keep showing it and its cached timelines.
                guard case .main = state else {
                    state = .launchFailed(error.localizedDescription)
                    return .none
                }
                return .none

            case .signIn(.delegate(.signedIn(let viewer))):
                state = .main(MainFeature.State(viewer: viewer))
                $viewer.withLock { $0 = viewer }
                return .cancel(id: CancelID.restore)

            case .signIn:
                return .none

            case .task:
                return .merge(
                    restoreSession(),
                    // Housekeeping only: it shouldn't compete with the first timeline for the database.
                    .run(priority: .background) { _ in
                        await withErrorReporting { try await timelineCache.prune() }
                    }
                )
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
            await send(.restoreSessionResponse(Result { try await client.restoreSession() }))
        }
        .cancellable(id: CancelID.restore, cancelInFlight: true)
    }

    private func signedOut(_ state: inout State) -> EffectOf<Self> {
        state = .signIn(SignInFeature.State())
        // Other windows watch the viewer and close; nothing from the old account carries over.
        $viewer.withLock { $0 = nil }
        $engagements.withLock { $0 = [:] }
        return .merge(
            .cancel(id: CancelID.restore),
            .run { _ in
                await withErrorReporting { try await timelineCache.clear() }
            }
        )
    }
}
