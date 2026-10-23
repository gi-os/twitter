import Models
import Sharing

package enum Interaction: Hashable, Sendable, CaseIterable {
    case bookmark
    case like
    case repost
}

package struct Engagement: Equatable, Sendable {
    package struct Toggle: Equatable, Sendable {
        package var desired: Bool
        package var server: Bool
        package var serverCount: Int

        package init(isOn: Bool, count: Int) {
            desired = isOn
            server = isOn
            serverCount = count
        }

        package var isOn: Bool { desired }

        package var count: Int {
            guard desired != server else { return serverCount }
            return max(serverCount + (desired ? 1 : -1), 0)
        }

        package var needsSync: Bool { desired != server }

        package mutating func confirm(_ value: Bool) {
            guard value != server else { return }
            serverCount = max(serverCount + (value ? 1 : -1), 0)
            server = value
        }

        package mutating func revert() {
            desired = server
        }

        mutating func refresh(isOn: Bool, count: Int) {
            guard !needsSync else { return }
            self = Toggle(isOn: isOn, count: count)
        }
    }

    package var bookmark: Toggle
    package var like: Toggle
    package var repost: Toggle

    package init(tweet: Tweet) {
        bookmark = Toggle(isOn: tweet.isBookmarked, count: tweet.bookmarkCount)
        like = Toggle(isOn: tweet.isLiked, count: tweet.likeCount)
        repost = Toggle(isOn: tweet.isRetweeted, count: tweet.retweetCount)
    }

    package subscript(interaction: Interaction) -> Toggle {
        get {
            switch interaction {
            case .bookmark: bookmark
            case .like: like
            case .repost: repost
            }
        }
        set {
            switch interaction {
            case .bookmark: bookmark = newValue
            case .like: like = newValue
            case .repost: repost = newValue
            }
        }
    }

    package mutating func refresh(from tweet: Tweet) {
        bookmark.refresh(isOn: tweet.isBookmarked, count: tweet.bookmarkCount)
        like.refresh(isOn: tweet.isLiked, count: tweet.likeCount)
        repost.refresh(isOn: tweet.isRetweeted, count: tweet.retweetCount)
    }
}

extension SharedKey where Self == InMemoryKey<[String: Engagement]>.Default {
    package static var engagements: Self {
        Self[.inMemory("engagements"), default: [:]]
    }
}

extension [String: Engagement] {
    package func engagement(for tweet: Tweet) -> Engagement {
        self[tweet.id] ?? Engagement(tweet: tweet)
    }

    package mutating func toggle(_ interaction: Interaction, for tweet: Tweet) {
        self[tweet.id, default: Engagement(tweet: tweet)][interaction].desired.toggle()
    }

    package mutating func refresh(from tweets: some Sequence<Tweet>) {
        for tweet in tweets {
            self[tweet.id]?.refresh(from: tweet)
        }
    }
}
