import ComposableArchitecture
import Testing

@testable import Models
@testable import ProfileFeature
@testable import TwitterClient

@MainActor
struct ProfileFeatureTests {
    @Test
    func taskFetchesUserOnlyOnce() async {
        let fetches = LockIsolated(0)
        let store = TestStore(initialState: ProfileFeature.State(user: .mockFriend)) {
            ProfileFeature()
        } withDependencies: {
            $0[TwitterClient.self].user = { _ in
                fetches.withValue { $0 += 1 }
                return .mockFriend
            }
        }

        await store.send(.task)
        await store.receive(\.userResponse) {
            $0.hasFetchedUser = true
        }
        await store.send(.task)
        #expect(fetches.value == 1)
    }

    @Test
    func failedFetchCanBeRetried() async {
        struct Failure: Error {}
        let store = TestStore(initialState: ProfileFeature.State(screenName: "pointfreeco")) {
            ProfileFeature()
        } withDependencies: {
            $0[TwitterClient.self].user = { _ in throw Failure() }
        }
        store.exhaustivity = .off

        await store.send(.task)
        await store.receive(\.userResponse)
        #expect(store.state.errorMessage != nil)

        store.dependencies[TwitterClient.self].user = { _ in .mockFriend }
        await store.send(.task)
        await store.receive(\.userResponse) {
            $0.user = .mockFriend
            $0.hasFetchedUser = true
            $0.errorMessage = nil
        }
    }
}
