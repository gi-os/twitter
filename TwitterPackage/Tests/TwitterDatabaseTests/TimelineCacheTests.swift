import Dependencies
import DependenciesTestSupport
import Foundation
import Testing

@testable import Models
@testable import TwitterDatabase

@Suite(
    .dependencies {
        try $0.bootstrapDatabase()
        $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
    }
)
struct TimelineCacheTests {
    var cache: TimelineCache { .liveValue }

    @Test
    func refreshReplacesAndPagesAppend() async throws {
        let source = FeedSource.home(following: false)
        let first = FeedPage(cachedItems: [.tweet(FeedTweet(tweet: Tweet.mocks[0]))], bottomCursor: "a")
        let second = FeedPage(cachedItems: [.tweet(FeedTweet(tweet: Tweet.mocks[1]))], bottomCursor: "b")

        try await cache.save(source, first, true)
        try await cache.save(source, second, false)
        var loaded = try #require(try await cache.load(source))
        #expect(loaded.items.map(\.id) == (first.items + second.items).map(\.id))
        #expect(loaded.bottomCursor == "b")

        try await cache.save(source, second, true)
        loaded = try #require(try await cache.load(source))
        #expect(loaded.items.map(\.id) == second.items.map(\.id))
    }

    @Test
    func searchesAreNeverCached() async throws {
        let source = FeedSource.search(query: "swift", latest: true)
        try await cache.save(
            source, FeedPage(cachedItems: [.tweet(FeedTweet(tweet: Tweet.mocks[0]))], bottomCursor: nil), true)
        #expect(try await cache.load(source) == nil)
    }

    @Test
    func usersAreFoundByHandleIgnoringCase() async throws {
        try await cache.saveUser(.mock)
        let user = try await cache.user(User.mock.screenName.uppercased())
        #expect(user == .mock)
    }

    @Test
    func clearForgetsEverything() async throws {
        let source = FeedSource.bookmarks
        try await cache.save(
            source, FeedPage(cachedItems: [.tweet(FeedTweet(tweet: Tweet.mocks[0]))], bottomCursor: nil), true)
        try await cache.saveUser(.mock)
        try await cache.clear()
        #expect(try await cache.load(source) == nil)
        #expect(try await cache.user(User.mock.screenName) == nil)
    }
}
