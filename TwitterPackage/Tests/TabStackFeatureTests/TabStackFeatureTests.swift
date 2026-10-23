import ComposableArchitecture
import Testing

@testable import FeedFeature
@testable import Models
@testable import Routing
@testable import TabStackFeature
@testable import TwitterClient

@MainActor
struct TabStackFeatureTests {
    @Test
    func openingFromRootReplacesPath() async {
        let first = Tweet.mocks[0]
        let second = Tweet.mocks[1]
        var state = TabStack.State.home
        state.path.append(Route.thread(first).pathState)
        let store = TestStore(initialState: state) {
            TabStack()
        }
        store.exhaustivity = .off

        await store.send(.root(.feeds(.delegate(.open(.thread(second)))))) {
            $0.path = StackState([Route.thread(second).pathState])
        }
    }

    @Test
    func openingFromPathPushes() async {
        let first = Tweet.mocks[0]
        let second = Tweet.mocks[1]
        var state = TabStack.State.home
        state.path.append(Route.thread(first).pathState)
        let store = TestStore(initialState: state) {
            TabStack()
        }
        store.exhaustivity = .off

        await store.send(.path(.element(id: 0, action: .thread(.delegate(.open(.thread(second))))))) {
            $0.path.append(Route.thread(second).pathState)
        }
    }

    @Test
    func composeFromRootIsForwarded() async {
        let tweet = Tweet.mocks[0]
        let store = TestStore(initialState: TabStack.State.home) {
            TabStack()
        }

        await store.send(.root(.feeds(.delegate(.compose(Draft(replyingTo: tweet))))))
        await store.receive(\.delegate, .compose(Draft(replyingTo: tweet)))
    }
}

@MainActor
struct TabStackCancellationTests {
    @Test
    func replacingPathCancelsInFlightThreadLoad() async {
        let first = Tweet.mocks[0]
        let second = Tweet.mocks[1]
        var state = TabStack.State.home
        state.path.append(Route.thread(first).pathState)
        let store = TestStore(initialState: state) {
            TabStack()
        } withDependencies: {
            $0[TwitterClient.self].feed = { _, _ in
                try await Task.sleep(for: .seconds(60))
                return FeedPage(items: [], bottomCursor: nil, topCursor: nil)
            }
        }

        await store.send(.path(.element(id: 0, action: .thread(.task)))) {
            $0.path[id: 0, case: \.thread]?.isLoading = true
        }
        await store.send(.root(.feeds(.delegate(.open(.thread(second)))))) {
            $0.path = StackState([Route.thread(second).pathState])
        }
    }
}
