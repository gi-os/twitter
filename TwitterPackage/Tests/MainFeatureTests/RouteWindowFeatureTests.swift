import ComposableArchitecture
import DependenciesTestSupport
import Testing

@testable import MainFeature
@testable import Models
@testable import Routing
@testable import TwitterClient

@MainActor
@Suite(.dependencies)
struct RouteWindowFeatureTests {
    @Test
    func signedOutWindowSaysSo() async {
        let store = TestStore(initialState: RouteWindowFeature.State(route: .thread(tweetID: "1"))) {
            RouteWindowFeature()
        } withDependencies: {
            $0[TwitterClient.self].restoreSession = { nil }
        }

        await store.send(.task)
        await store.receive(\.restoreSessionResponse) {
            $0.status = .signedOut
        }
    }

    @Test
    func windowStepsAsideWhenTheAccountSignsOutElsewhere() async {
        let store = TestStore(initialState: RouteWindowFeature.State(route: .profile(screenName: "pointfreeco"))) {
            RouteWindowFeature()
        } withDependencies: {
            $0[TwitterClient.self].restoreSession = { .mock }
        }

        await store.send(.task)
        await store.receive(\.restoreSessionResponse) {
            $0.status = .ready
            $0.$viewer.withLock { $0 = .mock }
        }
        await store.receive(\.viewerChanged)

        @Shared(.viewer) var viewer
        $viewer.withLock { $0 = nil }
        await store.receive(\.viewerChanged) {
            $0.status = .signedOutElsewhere
        }
    }

    @Test
    func rememberedAccountShowsRightAwayWhileTheSessionIsChecked() async {
        @Shared(.viewer) var viewer
        $viewer.withLock { $0 = .mock }

        let store = TestStore(initialState: RouteWindowFeature.State(route: .thread(tweetID: "1"))) {
            RouteWindowFeature()
        } withDependencies: {
            $0[TwitterClient.self].restoreSession = { .mock }
        }
        #expect(store.state.status == .ready)

        await store.send(.task)
        await store.receive(\.viewerChanged)
        await store.receive(\.restoreSessionResponse)

        $viewer.withLock { $0 = nil }
        await store.receive(\.viewerChanged) {
            $0.status = .signedOutElsewhere
        }
    }

    @Test
    func rememberedAccountRejectedByTwitterSignsTheWindowOut() async {
        @Shared(.viewer) var viewer
        $viewer.withLock { $0 = .mock }

        let store = TestStore(initialState: RouteWindowFeature.State(route: .thread(tweetID: "1"))) {
            RouteWindowFeature()
        } withDependencies: {
            $0[TwitterClient.self].restoreSession = { nil }
        }

        await store.send(.task)
        await store.receive(\.viewerChanged)
        await store.receive(\.restoreSessionResponse) {
            $0.status = .signedOut
        }
    }
}
