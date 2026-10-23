import Foundation

extension XUser {
  package static let mock = XUser(
    id: "1",
    name: "Sam Henri Gold",
    screenName: "samhenrigold",
    avatarURL: nil,
    bio: "Building a Twitter client for the iPhone Duo.",
    location: "Brooklyn",
    followersCount: 4_210,
    followingCount: 512,
    postsCount: 9_876,
    isVerified: true,
    joined: Date(timeIntervalSince1970: 1_230_000_000)
  )

  package static let mockFriend = XUser(
    id: "2",
    name: "Point-Free",
    screenName: "pointfreeco",
    bio: "A video series exploring advanced programming topics in Swift.",
    followersCount: 31_000,
    followingCount: 12,
    postsCount: 4_000,
    isFollowing: true
  )
}

extension XTweet {
  package static func mock(
    id: String,
    author: XUser = .mockFriend,
    text: String,
    secondsAgo: TimeInterval = 60
  ) -> XTweet {
    XTweet(
      id: id,
      author: author,
      text: text,
      createdAt: Date(timeIntervalSinceNow: -secondsAgo),
      replyCount: 12,
      retweetCount: 34,
      likeCount: 560,
      viewCount: 12_345
    )
  }

  package static let mocks: [XTweet] = [
    .mock(
      id: "100",
      text: "The Composable Architecture 1.26 is out, with first-class support for Swift 6.4. https://pointfree.co",
      secondsAgo: 120
    ),
    .mock(
      id: "101",
      author: .mock,
      text: "Unfold the phone and the timeline turns into two columns: feed on the left, thread on the right.",
      secondsAgo: 3_600
    ),
    .mock(
      id: "102",
      text: "Swipe actions now work in any scrollable container on iOS 27, not just List.",
      secondsAgo: 86_400
    ),
  ]
}

extension FeedPage {
  package static func mock(_ source: FeedSource) -> FeedPage {
    FeedPage(
      items: XTweet.mocks.map { .tweet(FeedTweet(id: $0.id, tweet: $0)) },
      bottomCursor: nil,
      topCursor: nil
    )
  }
}
