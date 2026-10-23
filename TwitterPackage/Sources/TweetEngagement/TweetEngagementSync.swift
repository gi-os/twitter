import Dependencies
import DependenciesMacros
import Sharing
import TwitterClient

@DependencyClient
package struct TweetEngagementSync: Sendable {
    package var sync: @Sendable (_ tweetID: String, _ interaction: Interaction) async -> Void
}

extension TweetEngagementSync: DependencyKey {
    package static var liveValue: TweetEngagementSync {
        @Dependency(TwitterClient.self) var client
        let coordinator = SyncCoordinator(client: client)
        return TweetEngagementSync(sync: { await coordinator.sync($0, $1) })
    }

    package static var previewValue: TweetEngagementSync {
        let coordinator = SyncCoordinator(client: .previewValue)
        return TweetEngagementSync(sync: { await coordinator.sync($0, $1) })
    }

    package static var testValue: TweetEngagementSync { TweetEngagementSync() }
}

package actor SyncCoordinator {
    private struct Key: Hashable {
        let interaction: Interaction
        let tweetID: String
    }

    private let client: TwitterClient
    @Shared(.engagements) private var engagements
    private var running: Set<Key> = []

    package init(client: TwitterClient) {
        self.client = client
    }

    /// Sends the latest desired value for a tweet's interaction, coalescing taps made while a request is in flight.
    package func sync(_ tweetID: String, _ interaction: Interaction) async {
        let key = Key(interaction: interaction, tweetID: tweetID)
        guard running.insert(key).inserted else { return }
        await Task { await run(key) }.value
    }

    private func run(_ key: Key) async {
        while let target = nextTarget(key) {
            do {
                try await send(target, key)
                $engagements.withLock { $0[key.tweetID]?[key.interaction].confirm(target) }
            } catch {
                $engagements.withLock { $0[key.tweetID]?[key.interaction].revert() }
                running.remove(key)
                return
            }
        }
    }

    private func nextTarget(_ key: Key) -> Bool? {
        guard let toggle = engagements[key.tweetID]?[key.interaction], toggle.needsSync else {
            running.remove(key)
            return nil
        }
        return toggle.desired
    }

    private func send(_ value: Bool, _ key: Key) async throws {
        switch key.interaction {
        case .bookmark: try await client.setBookmarked(value, key.tweetID)
        case .like: try await client.setLiked(value, key.tweetID)
        case .repost: try await client.setReposted(value, key.tweetID)
        }
    }
}
