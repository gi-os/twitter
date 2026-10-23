import ComposableArchitecture
import Foundation
import Testing

@testable import FeedFeature
@testable import Models
@testable import Routing
@testable import TweetEngagement
@testable import TwitterClient

@MainActor
struct FeedFeatureTests {
    @Test
    func taskLoadsFirstPage() async {
        let page = FeedPage(items: [.tweet(FeedTweet(tweet: Tweet.mocks[0]))], bottomCursor: "next", topCursor: nil)
        let store = TestStore(initialState: FeedFeature.State(source: .home(following: false))) {
            FeedFeature()
        } withDependencies: {
            $0[TwitterClient.self].feed = { _, cursor in
                #expect(cursor == nil)
                return page
            }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(\.pageResponse) {
            $0.isLoading = false
            $0.hasLoaded = true
            $0.items = IdentifiedArray(uniqueElements: page.items)
            $0.bottomCursor = "next"
        }
    }

    @Test
    func rowNearBottomLoadsNextPage() async {
        let first = Tweet.mocks[0]
        let second = Tweet.mocks[1]
        var state = FeedFeature.State(
            source: .home(following: true),
            items: [.tweet(FeedTweet(tweet: first))]
        )
        state.bottomCursor = "cursor-1"
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            FeedFeature()
        } withDependencies: {
            $0[TwitterClient.self].feed = { _, cursor in
                #expect(cursor == "cursor-1")
                return FeedPage(items: [.tweet(FeedTweet(tweet: second))], bottomCursor: nil, topCursor: nil)
            }
        }

        await store.send(.rowAppeared(FeedItem.tweet(FeedTweet(tweet: first)).id)) {
            $0.isLoading = true
        }
        await store.receive(\.pageResponse) {
            $0.isLoading = false
            $0.items.append(.tweet(FeedTweet(tweet: second)))
            $0.bottomCursor = nil
        }
    }

    @Test
    func likeUpdatesSharedEngagementAndSyncs() async {
        let tweet = Tweet.mocks[0]
        let synced = LockIsolated<[String]>([])
        let store = TestStore(
            initialState: FeedFeature.State(source: .bookmarks, items: [.tweet(FeedTweet(tweet: tweet))])
        ) {
            FeedFeature()
        } withDependencies: {
            $0[TweetEngagementSync.self].sync = { tweetID, interaction in
                synced.withValue { $0.append("\(tweetID)-\(interaction)") }
            }
        }

        await store.send(.likeButtonTapped(tweet)) {
            $0.$engagements.withLock { $0.toggle(.like, for: tweet) }
        }
        #expect(store.state.engagements[tweet.id]?.like.count == tweet.likeCount + 1)
        await store.finish()
        #expect(synced.value == ["\(tweet.id)-like"])
    }

    @Test
    func tappingTweetOpensThread() async {
        let tweet = Tweet.mocks[0]
        let store = TestStore(initialState: FeedFeature.State(source: .home(following: false))) {
            FeedFeature()
        }

        await store.send(.tweetTapped(tweet))
        await store.receive(\.delegate, .open(.thread(tweet)))
    }

    @Test
    func tappingFocusedTweetInThreadDoesNothing() async {
        let tweet = Tweet.mocks[0]
        let store = TestStore(initialState: FeedFeature.State(source: .thread(tweetID: tweet.id))) {
            FeedFeature()
        }

        await store.send(.tweetTapped(tweet))
    }

    @Test
    func mentionLinkOpensProfile() async throws {
        let store = TestStore(initialState: FeedFeature.State(source: .home(following: false))) {
            FeedFeature()
        }
        let url = try #require(URL(string: "\(Route.scheme)://user/pointfreeco"))

        await store.send(.linkTapped(url))
        await store.receive(\.delegate, .open(.profileHandle("pointfreeco")))
    }
}
