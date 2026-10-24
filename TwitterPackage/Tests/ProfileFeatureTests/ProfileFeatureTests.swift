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
    func blockIsOptimisticAndUnblockRevertsOnFailure() async {
        struct Failure: Error {}
        let calls = LockIsolated<[Bool]>([])
        let store = TestStore(initialState: ProfileFeature.State(user: .mockFriend)) {
            ProfileFeature()
        } withDependencies: {
            $0[TwitterClient.self].setBlocking = { isBlocking, userID in
                #expect(userID == User.mockFriend.id)
                calls.withValue { $0.append(isBlocking) }
                if !isBlocking { throw Failure() }
            }
        }

        await store.send(.blockButtonTapped) {
            $0.user?.isBlocking = true
        }
        await store.send(.viewPostsButtonTapped) {
            $0.isShowingBlockedPosts = true
        }
        await store.send(.blockButtonTapped) {
            $0.user?.isBlocking = false
            $0.isShowingBlockedPosts = false
        }
        await store.receive(\.blockFailed) {
            $0.user?.isBlocking = true
        }
        #expect(calls.value == [true, false])
    }

    @Test
    func unfollowIsOptimisticAndRestoresOnFailure() async {
        struct Failure: Error {}
        let store = TestStore(initialState: ProfileFeature.State(user: .mockFriend)) {
            ProfileFeature()
        } withDependencies: {
            $0[TwitterClient.self].setFollowing = { isFollowing, _ in
                #expect(!isFollowing)
                throw Failure()
            }
        }

        await store.send(.followButtonTapped) {
            $0.user?.isFollowing = false
            $0.user?.followersCount = User.mockFriend.followersCount - 1
        }
        await store.receive(\.followFailed) {
            $0.user?.isFollowing = true
            $0.user?.followersCount = User.mockFriend.followersCount
        }
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
