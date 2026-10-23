import Foundation

package struct XUser: Identifiable, Hashable, Codable, Sendable {
  package var id: String
  package var name: String
  package var screenName: String
  package var avatarURL: URL?
  package var bannerURL: URL?
  package var bio: String = ""
  package var location: String = ""
  package var website: String?
  package var websiteURL: URL?
  package var hasSquareAvatar = false
  package var followersCount: Int = 0
  package var followingCount: Int = 0
  package var postsCount: Int = 0
  package var isVerified: Bool = false
  package var verifiedType: String?
  package var isProtected: Bool = false
  package var isFollowing: Bool = false
  package var followsYou: Bool = false
  package var isMuting: Bool = false
  package var isBlocking: Bool = false
  package var pinnedTweetID: String?
  package var joined: Date?

  /// The avatar variant to fetch for a given display size in points.
  package func avatarURL(forSize size: Double) -> URL? {
    if size > 56 { return largeAvatarURL }
    return avatarURL.flatMap { URL(string: $0.absoluteString.replacingOccurrences(of: "_normal.", with: "_bigger.")) }
  }

  /// A sharper avatar than the 48px `_normal` default.
  package var largeAvatarURL: URL? {
    guard let avatarURL else { return nil }
    return URL(string: avatarURL.absoluteString.replacingOccurrences(of: "_normal.", with: "_400x400."))
  }
}

package struct XMedia: Identifiable, Hashable, Codable, Sendable {
  package enum Kind: String, Codable, Sendable { case photo, video, gif }
  package var id: String
  package var kind: Kind
  package var previewURL: URL
  package var videoURL: URL?
  /// A lighter variant (≤ ~2 Mbps) for muted inline autoplay.
  package var inlineVideoURL: URL?
  package var width: Double
  package var height: Double
  package var altText: String?
  package var durationMillis: Int?

  package var aspectRatio: Double { width > 0 && height > 0 ? width / height : 16 / 9 }

  package var fullSizeURL: URL {
    guard kind == .photo else { return previewURL }
    return URL(string: previewURL.absoluteString + "?name=orig") ?? previewURL
  }
}

package struct XLinkCard: Hashable, Codable, Sendable {
  package var title: String
  package var domain: String
  package var url: URL
  package var imageURL: URL?
}

package struct XTweet: Identifiable, Hashable, Codable, Sendable {
  package var id: String
  package var author: XUser
  package var text: String
  /// Display URL → destination, for linking the shortened URLs shown in `text`.
  package var links: [String: URL] = [:]
  package var createdAt: Date?
  package var replyCount = 0
  package var retweetCount = 0
  package var likeCount = 0
  package var quoteCount = 0
  package var bookmarkCount = 0
  package var viewCount: Int?
  package var isLiked = false
  package var isRetweeted = false
  package var isBookmarked = false
  package var media: [XMedia] = []
  /// Zero or one quoted post (an array keeps the struct non-recursive).
  package var quoted: [XTweet] = []
  package var card: XLinkCard?
  package var replyingTo: [String] = []
  package var conversationId: String?

  package var url: URL { URL(string: "https://x.com/\(author.screenName)/status/\(id)")! }
}

/// A post as it appears in a feed, with the context of how it got there.
package struct FeedTweet: Identifiable, Hashable, Sendable {
  package var id: String
  package var tweet: XTweet
  package var repostedBy: XUser?
  package var socialContext: String?
  /// SF Symbol for the context line ("Pinned", "X liked", "Followed by …").
  package var socialSymbol: String?
  /// Draws a thread line down to the next post (conversation modules and reply chains).
  package var connectsBelow = false
  package var connectsAbove = false
}

package struct XNotification: Identifiable, Hashable, Sendable {
  package var id: String
  package var icon: String
  package var message: String
  /// Unicode-scalar ranges in `message` that X renders bold (the people's names).
  package var boldRanges: [Range<Int>] = []
  package var users: [XUser]
  package var date: Date?
  package var tweet: XTweet?
  package var tweetID: String?
}

package enum FeedItem: Identifiable, Hashable, Sendable {
  case tweet(FeedTweet)
  case notification(XNotification)

  package var id: String {
    switch self {
    case .tweet(let item): "t-\(item.id)"
    case .notification(let item): "n-\(item.id)"
    }
  }
}

package struct FeedPage: Sendable {
  package var items: [FeedItem]
  package var bottomCursor: String?
  package var topCursor: String?
}

package enum XError: LocalizedError, Sendable {
  case notSignedIn
  case unauthorized
  case rateLimited(resetAt: Date?)
  case http(Int, String)
  case api(String)
  case catalog(String)
  case missingOperation(String)

  package var errorDescription: String? {
    switch self {
    case .notSignedIn: "You're not signed in."
    case .unauthorized: "Your X session expired. Sign in again."
    case .rateLimited(let reset):
      if let reset { "X rate limit reached. Try again \(reset.formatted(.relative(presentation: .named)))." }
      else { "X rate limit reached. Try again in a few minutes." }
    case .http(let code, let body): "X returned HTTP \(code). \(body.prefix(200))"
    case .api(let message): message
    case .catalog(let message): message
    case .missingOperation(let name): "X's web client no longer exposes \(name)."
    }
  }
}

extension FeedTweet {
  package init(tweet: XTweet) {
    self.init(id: tweet.id, tweet: tweet)
  }
}
