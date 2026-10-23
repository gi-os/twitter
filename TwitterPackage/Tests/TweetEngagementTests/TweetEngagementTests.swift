import ConcurrencyExtras
import Dependencies
import DependenciesTestSupport
import Sharing
import Testing

@testable import Models
@testable import TweetEngagement
@testable import TwitterClient

@Suite(.dependencies)
struct TweetEngagementTests {
    let tweet = Tweet.mocks[0]

    @Test
    func toggleCountsFollowDesiredState() {
        var toggle = Engagement.Toggle(isOn: false, count: 10)
        toggle.desired = true
        #expect(toggle.count == 11)
        toggle.confirm(true)
        #expect(toggle == Engagement.Toggle(isOn: true, count: 11))
        toggle.desired = false
        #expect(toggle.count == 10)
        toggle.revert()
        #expect(toggle == Engagement.Toggle(isOn: true, count: 11))
    }

    @Test
    func doubleTapBeforeSyncSendsNothing() async {
        let calls = LockIsolated<[Bool]>([])
        var client = TwitterClient()
        client.setLiked = { isLiked, _ in calls.withValue { $0.append(isLiked) } }
        @Shared(.engagements) var engagements
        $engagements.withLock {
            $0.toggle(.like, for: tweet)
            $0.toggle(.like, for: tweet)
        }

        await SyncCoordinator(client: client).sync(tweet.id, .like)

        #expect(calls.value.isEmpty)
        #expect(engagements[tweet.id]?.like == Engagement.Toggle(isOn: false, count: tweet.likeCount))
    }

    @Test
    func tapWhileInFlightCoalescesToLatestIntent() async {
        let calls = LockIsolated<[Bool]>([])
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let (gate, gateContinuation) = AsyncStream<Void>.makeStream()
        var client = TwitterClient()
        client.setLiked = { isLiked, _ in
            let count = calls.withValue {
                $0.append(isLiked)
                return $0.count
            }
            guard count == 1 else { return }
            startedContinuation.yield()
            for await _ in gate { break }
        }
        @Shared(.engagements) var engagements
        let coordinator = SyncCoordinator(client: client)

        $engagements.withLock { $0.toggle(.like, for: tweet) }
        let firstSync = Task { await coordinator.sync(tweet.id, .like) }
        for await _ in started { break }

        $engagements.withLock { $0.toggle(.like, for: tweet) }
        await coordinator.sync(tweet.id, .like)
        #expect(engagements[tweet.id]?.like.count == tweet.likeCount)

        gateContinuation.yield()
        await firstSync.value

        #expect(calls.value == [true, false])
        #expect(engagements[tweet.id]?.like == Engagement.Toggle(isOn: false, count: tweet.likeCount))
    }

    @Test
    func failureRevertsToServerState() async {
        struct Failure: Error {}
        var client = TwitterClient()
        client.setBookmarked = { _, _ in throw Failure() }
        @Shared(.engagements) var engagements
        $engagements.withLock { $0.toggle(.bookmark, for: tweet) }
        #expect(engagements[tweet.id]?.bookmark.isOn == true)

        await SyncCoordinator(client: client).sync(tweet.id, .bookmark)

        #expect(engagements[tweet.id]?.bookmark == Engagement.Toggle(isOn: false, count: tweet.bookmarkCount))
    }

    @Test
    func refreshDoesNotClobberPendingIntent() {
        @Shared(.engagements) var engagements
        $engagements.withLock { $0.toggle(.like, for: tweet) }
        var fresh = tweet
        fresh.likeCount = 999

        $engagements.withLock { $0.refresh(from: [fresh]) }

        #expect(engagements[tweet.id]?.like.isOn == true)
        #expect(engagements[tweet.id]?.like.serverCount == tweet.likeCount)
    }
}
