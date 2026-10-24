import Foundation

extension User {
    package static let mock = User(
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

    package static let mockFriend = User(
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

extension Tweet {
    package static func mock(
        id: String,
        author: User = .mockFriend,
        text: String,
        secondsAgo: TimeInterval = 60
    ) -> Tweet {
        Tweet(
            id: id,
            author: author,
            text: text,
            createdAt: Date(timeIntervalSinceNow: -secondsAgo),
            replyCount: 12,
            repostCount: 34,
            likeCount: 560,
            viewCount: 12_345
        )
    }

    package static let mocks: [Tweet] = [
        .mock(
            id: "100",
            text:
                "The Composable Architecture 1.26 is out, with first-class support for Swift 6.4. https://pointfree.co",
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
        )
    ]
}

extension User {
    package static let mockBusiness = User(
        id: "3",
        name: "Apple",
        screenName: "apple",
        hasSquareAvatar: true,
        followersCount: 9_800_000,
        isVerified: true,
        verifiedType: "Business"
    )

    package static let mockGovernment = User(
        id: "4",
        name: "NASA",
        screenName: "nasa",
        followersCount: 88_000_000,
        isVerified: true,
        verifiedType: "Government"
    )

    package static let mockAffiliate = User(
        id: "5",
        name: "Tim Cook",
        screenName: "tim_cook",
        followersCount: 14_000_000,
        isVerified: true,
        affiliate: AffiliateLabel(description: "Apple", url: URL(string: "https://x.com/apple"))
    )

    package static let mockBlocked = User(
        id: "6",
        name: "Reply Guy",
        screenName: "replyguy",
        bio: "Well, actually…",
        followersCount: 12,
        followingCount: 4_800,
        isBlocking: true
    )

    package static let mockBlockedBy = User(
        id: "7",
        name: "Not a Fan",
        screenName: "notafan",
        followersCount: 300,
        blocksViewer: true
    )

    package static let mocks: [User] = [
        .mock, .mockFriend, .mockBusiness, .mockGovernment, .mockAffiliate, .mockBlocked, .mockBlockedBy
    ]
}

extension Tweet {
    package static let mockLongText = """
        Some notes on building for a phone that unfolds into two screens.

        First, never read the screen size. Read the size of the window you were given, because on a foldable \
        that changes while the app runs and it is never the whole display.

        Second, keep state in the reducer, not in the view. When the layout flips from one column to two, \
        every view is rebuilt, and anything that lived in @State goes with it.

        Third, test it folded, unfolded, and halfway in between. #SwiftUI $AAPL
        """

    package static let mockLongPost: Tweet = {
        var tweet = Tweet.mock(id: "103", author: .mockAffiliate, text: mockLongText, secondsAgo: 7_200)
        let scalars = Array(mockLongText.unicodeScalars)
        func range(of word: String) -> Range<Int> {
            let needle = Array(word.unicodeScalars)
            let start =
                (0...(scalars.count - needle.count)).first { scalars[$0..<($0 + needle.count)].elementsEqual(needle) }
                ?? 0
            return start..<(start + needle.count)
        }
        tweet.styles = [
            TextStyleRange(range: range(of: "First"), isBold: true),
            TextStyleRange(range: range(of: "Second"), isBold: true),
            TextStyleRange(range: range(of: "Third"), isBold: true),
            TextStyleRange(range: range(of: "the window you were given"), isItalic: true)
        ]
        tweet.hashtags = ["#SwiftUI"]
        tweet.cashtags = ["$AAPL"]
        return tweet
    }()

    package static let mockCommunityNote: Tweet = {
        var tweet = Tweet.mock(
            id: "104", author: .mockGovernment, text: "The Moon is made of cheese. Confirmed. #space",
            secondsAgo: 10_800)
        tweet.hashtags = ["#space"]
        tweet.communityNote = CommunityNote(
            title: "Readers added context they thought people might want to know",
            shortTitle: "Readers added context",
            text: "Lunar samples returned by Apollo missions are made of rock, not cheese. nasa.gov/moon",
            links: ["nasa.gov/moon": URL(string: "https://www.nasa.gov/moon")!],
            footer: "Context is written by people who use Twitter, and they choose which notes appear.",
            destinationURL: URL(string: "https://x.com/i/birdwatch")
        )
        return tweet
    }()

    package static let mockPoll: Tweet = {
        var tweet = Tweet.mock(id: "105", author: .mockBusiness, text: "Which layout do you prefer?", secondsAgo: 1_800)
        tweet.poll = Poll(
            choices: [
                .init(label: "One column", count: 1_204),
                .init(label: "Two columns", count: 3_870),
                .init(label: "It depends", count: 512)
            ],
            endsAt: Date(timeIntervalSinceNow: 5 * 3_600),
            selectedChoiceIndex: 1
        )
        return tweet
    }()

    package static let mockFinalPoll: Tweet = {
        var tweet = Tweet.mock(id: "106", text: "Tabs or spaces?", secondsAgo: 172_800)
        tweet.poll = Poll(
            choices: [.init(label: "Tabs", count: 410), .init(label: "Spaces", count: 1_590)],
            endsAt: Date(timeIntervalSinceNow: -86_400),
            countsAreFinal: true
        )
        return tweet
    }()

    package static let mockRestricted: Tweet = {
        var tweet = Tweet.mock(
            id: "107", author: .mockBusiness, text: "Talking with @pointfreeco about the future of Swift.",
            secondsAgo: 900)
        tweet.replyRestriction = ReplyRestriction(policy: .mentioned, ownerScreenName: "apple", viewerCanReply: false)
        return tweet
    }()

    package static let mockQuotingDeleted: Tweet = {
        var tweet = Tweet.mock(id: "108", author: .mock, text: "Wish I'd screenshotted this one.", secondsAgo: 20_000)
        tweet.quotedTombstone = Tombstone(id: "108-quote", text: "This post was deleted by the post author.")
        return tweet
    }()

    package static let mockReplies: [Tweet] = [
        .mock(id: "201", author: .mockFriend, text: "Congrats on the launch!", secondsAgo: 600),
        .mock(id: "202", author: .mock, text: "Thank you! More to come.", secondsAgo: 500)
    ]
}

extension FeedPage {
    package static let mockShowMoreCursor = "mock-show-more"

    package static func mock(_ source: FeedSource) -> FeedPage {
        mock(source, cursor: nil)
    }

    package static func mock(_ source: FeedSource, cursor: String?) -> FeedPage {
        func item(_ tweet: Tweet) -> FeedItem { .tweet(FeedTweet(id: tweet.id, tweet: tweet)) }
        if cursor == mockShowMoreCursor {
            return FeedPage(
                items: [
                    .tweet(
                        FeedTweet(id: "203", tweet: .mock(id: "203", text: "Late to the party, but this is great."))),
                    .tombstone(Tombstone(id: "tweet-204", text: "This post is unavailable."))
                ],
                bottomCursor: nil,
                topCursor: nil
            )
        }
        if case .thread(let tweetID) = source {
            // The opened post is the thread's focus, so mock threads show it focused like real ones.
            let focused = (Tweet.mocks + [.mockRestricted]).first { $0.id == tweetID } ?? .mockRestricted
            var replies = Tweet.mockReplies.map { FeedTweet(id: $0.id, tweet: $0) }
            replies[0].connectsBelow = true
            replies[1].connectsAbove = true
            return FeedPage(
                items: [
                    item(focused),
                    .tweet(replies[0]),
                    .tweet(replies[1]),
                    .tombstone(Tombstone(id: "tweet-209", text: "This post was hidden by the post author.")),
                    .showMore(ShowMoreCursor(id: "cursor-showmorethreads-1", cursor: mockShowMoreCursor))
                ],
                bottomCursor: nil,
                topCursor: nil
            )
        }
        var items = Tweet.mocks.map(item)
        items.insert(item(.mockLongPost), at: 1)
        items.insert(item(.mockPoll), at: 2)
        items.insert(.tombstone(Tombstone(id: "tweet-109", text: "This post was deleted by the post author.")), at: 3)
        items += [item(.mockCommunityNote), item(.mockRestricted), item(.mockQuotingDeleted), item(.mockFinalPoll)]
        return FeedPage(items: items, bottomCursor: nil, topCursor: nil)
    }
}
