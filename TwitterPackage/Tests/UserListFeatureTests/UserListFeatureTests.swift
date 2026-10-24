import ComposableArchitecture
import Testing

@testable import Models
@testable import Routing
@testable import TwitterClient
@testable import UserListFeature

@MainActor
struct UserListFeatureTests {
    let source = UserListSource.followers(userID: User.mock.id)

    @Test
    func pagesUntilTheCursorRunsOut() async {
        let firstPage = Array(User.mockCrowd.prefix(6))
        let secondPage = Array(User.mockCrowd.dropFirst(6).prefix(2))
        let cursors = LockIsolated<[String?]>([])
        let store = TestStore(initialState: UserListFeature.State(source: source)) {
            UserListFeature()
        } withDependencies: {
            $0[TwitterClient.self].users = { [source] requested, cursor in
                #expect(requested == source)
                cursors.withValue { $0.append(cursor) }
                return cursor == nil
                    ? UserPage(users: firstPage, bottomCursor: "page-2")
                    : UserPage(users: secondPage, bottomCursor: nil)
            }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(\.pageResponse) {
            $0.isLoading = false
            $0.hasLoaded = true
            $0.users = IdentifiedArray(uniqueElements: firstPage)
            $0.bottomCursor = "page-2"
        }
        // Far from the end: nothing to fetch yet.
        await store.send(.rowAppeared(firstPage[0].id))
        await store.send(.rowAppeared(firstPage[4].id)) {
            $0.isLoading = true
        }
        await store.receive(\.pageResponse) {
            $0.isLoading = false
            $0.users.append(contentsOf: secondPage)
            $0.bottomCursor = nil
        }
        // The list has ended.
        await store.send(.rowAppeared(secondPage[1].id))
        #expect(cursors.value == [nil, "page-2"])
    }

    @Test
    func aPageOfNobodyNewEndsTheList() async {
        let users = Array(User.mockCrowd.prefix(3))
        var state = UserListFeature.State(source: source)
        state.hasLoaded = true
        state.users = IdentifiedArray(uniqueElements: users)
        state.bottomCursor = "page-2"
        let store = TestStore(initialState: state) {
            UserListFeature()
        } withDependencies: {
            $0[TwitterClient.self].users = { _, _ in UserPage(users: users, bottomCursor: "page-3") }
        }

        await store.send(.rowAppeared(users[2].id)) {
            $0.isLoading = true
        }
        await store.receive(\.pageResponse) {
            $0.isLoading = false
            $0.bottomCursor = nil
        }
    }

    @Test
    func refreshReplacesTheList() async {
        let fresh = [User.mockFriend]
        var state = UserListFeature.State(source: source)
        state.hasLoaded = true
        state.users = IdentifiedArray(uniqueElements: User.mockCrowd.prefix(3))
        let store = TestStore(initialState: state) {
            UserListFeature()
        } withDependencies: {
            $0[TwitterClient.self].users = { _, cursor in
                #expect(cursor == nil)
                return UserPage(users: fresh, bottomCursor: "next")
            }
        }

        await store.send(.refreshPulled) {
            $0.isLoading = true
        }
        await store.receive(\.pageResponse) {
            $0.isLoading = false
            $0.users = IdentifiedArray(uniqueElements: fresh)
            $0.bottomCursor = "next"
        }
    }

    @Test
    func followIsOptimisticAndRevertsOnFailure() async {
        struct Failure: Error {}
        let user = User.mockCrowd[1]
        #expect(!user.isFollowing)
        let calls = LockIsolated<[Bool]>([])
        var state = UserListFeature.State(source: source)
        state.users = [user]
        let store = TestStore(initialState: state) {
            UserListFeature()
        } withDependencies: {
            $0[TwitterClient.self].setFollowing = { isFollowing, userID in
                #expect(userID == user.id)
                calls.withValue { $0.append(isFollowing) }
                if !isFollowing { throw Failure() }
            }
        }

        await store.send(.followButtonTapped(user.id)) {
            $0.users[id: user.id]?.isFollowing = true
        }
        await store.send(.followButtonTapped(user.id)) {
            $0.users[id: user.id]?.isFollowing = false
        }
        await store.receive(\.followFailed) {
            $0.users[id: user.id]?.isFollowing = true
        }
        #expect(calls.value == [true, false])
    }

    @Test
    func failureShowsTheErrorAndRetryLoadsAgain() async {
        struct Failure: Error {}
        let fails = LockIsolated(true)
        let store = TestStore(initialState: UserListFeature.State(source: source)) {
            UserListFeature()
        } withDependencies: {
            $0[TwitterClient.self].users = { _, _ in
                if fails.value { throw Failure() }
                return UserPage(users: [.mockFriend], bottomCursor: nil)
            }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(\.pageResponse) {
            $0.isLoading = false
            $0.hasLoaded = true
            $0.errorMessage = Failure().localizedDescription
        }
        fails.setValue(false)
        await store.send(.retryButtonTapped) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(\.pageResponse) {
            $0.isLoading = false
            $0.users = [.mockFriend]
        }
    }

    @Test
    func tappingARowOpensTheProfile() async {
        let store = TestStore(initialState: UserListFeature.State(source: source)) {
            UserListFeature()
        }

        await store.send(.userTapped(.mockFriend))
        await store.receive(\.delegate, .open(.profile(.mockFriend)))
    }
}
