import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import AppFeature
@testable import MainFeature
@testable import Models
@testable import SignInFeature
@testable import TwitterClient
@testable import TwitterDatabase

@MainActor
@Suite(.dependencies)
struct AppFeatureTests {
    @Test
    func rememberedAccountOpensStraightToMainThenFreshensIt() async {
        @Shared(.viewer) var viewer
        $viewer.withLock { $0 = .mock }
        var freshened = User.mock
        freshened.name = "Point-Free (new name)"

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: { [freshened] in
            $0[TwitterClient.self].restoreSession = { freshened }
        }
        #expect(store.state == .main(MainFeature.State(viewer: .mock)))

        await store.send(.task)
        await store.receive(\.restoreSessionResponse) {
            $0.modify(\.main) { $0.viewer = freshened }
        }
        #expect(viewer == freshened)
    }

    @Test
    func rememberedAccountSignsOutWhenTwitterRejectsTheSession() async {
        @Shared(.viewer) var viewer
        $viewer.withLock { $0 = .mock }
        let cleared = LockIsolated(false)

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0[TwitterClient.self].restoreSession = { nil }
            $0[TimelineCache.self].clear = { cleared.setValue(true) }
        }

        await store.send(.task)
        await store.receive(\.restoreSessionResponse) {
            $0 = .signIn(SignInFeature.State())
        }
        #expect(viewer == nil)
        #expect(cleared.value)
    }

    @Test
    func rememberedAccountStaysWhenOffline() async {
        @Shared(.viewer) var viewer
        $viewer.withLock { $0 = .mock }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0[TwitterClient.self].restoreSession = { throw URLError(.notConnectedToInternet) }
        }

        await store.send(.task)
        await store.receive(\.restoreSessionResponse)
        #expect(viewer == .mock)
    }

    @Test
    func withoutARememberedAccountLaunchWaitsForTheRestore() async {
        @Shared(.viewer) var viewer

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0[TwitterClient.self].restoreSession = { .mock }
        }
        #expect(store.state == .launching)

        await store.send(.task)
        await store.receive(\.restoreSessionResponse) {
            $0 = .main(MainFeature.State(viewer: .mock))
        }
        #expect(viewer == .mock)
    }

    @Test
    func withoutARememberedAccountOfflineLaunchFails() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0[TwitterClient.self].restoreSession = { throw URLError(.notConnectedToInternet) }
        }

        await store.send(.task)
        await store.receive(\.restoreSessionResponse) {
            $0 = .launchFailed(URLError(.notConnectedToInternet).localizedDescription)
        }
    }

    @Test
    func withoutAStoredSessionLaunchShowsSignIn() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0[TwitterClient.self].restoreSession = { nil }
        }

        await store.send(.task)
        await store.receive(\.restoreSessionResponse) {
            $0 = .signIn(SignInFeature.State())
        }
    }

    @Test
    func signingOutCancelsTheBackgroundRestore() async {
        @Shared(.viewer) var viewer
        $viewer.withLock { $0 = .mock }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0[TwitterClient.self].restoreSession = {
                try await Task.never()
                return nil
            }
        }

        await store.send(.task)
        await store.send(.main(.delegate(.signedOut))) {
            $0 = .signIn(SignInFeature.State())
        }
        #expect(viewer == nil)
    }
}
