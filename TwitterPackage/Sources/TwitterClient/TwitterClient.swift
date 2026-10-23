import Dependencies
import DependenciesMacros
import Foundation
import Models

package struct MediaUpload: Hashable, Sendable {
    package var data: Data
    package var mimeType: String

    package init(data: Data, mimeType: String) {
        self.data = data
        self.mimeType = mimeType
    }
}

@DependencyClient
package struct TwitterClient: Sendable {
    package var deleteTweet: @Sendable (_ id: String) async throws -> Void
    package var feed: @Sendable (_ source: FeedSource, _ cursor: String?) async throws -> FeedPage
    package var post:
        @Sendable (
            _ text: String, _ replyTo: String?, _ quoteURL: URL?, _ media: [MediaUpload]
        ) async throws -> String
    package var restoreSession: @Sendable () async throws -> User?
    package var setBookmarked: @Sendable (_ isBookmarked: Bool, _ tweetID: String) async throws -> Void
    package var setFollowing: @Sendable (_ isFollowing: Bool, _ userID: String) async throws -> Void
    package var setLiked: @Sendable (_ isLiked: Bool, _ tweetID: String) async throws -> Void
    package var setReposted: @Sendable (_ isReposted: Bool, _ tweetID: String) async throws -> Void
    package var signIn: @Sendable (_ cookies: [String: String]) async throws -> User
    package var signOut: @Sendable () async -> Void
    package var user: @Sendable (_ screenName: String) async throws -> User
}

extension TwitterClient: TestDependencyKey {
    package static var testValue: TwitterClient { TwitterClient() }

    package static var previewValue: TwitterClient {
        TwitterClient(
            deleteTweet: { _ in },
            feed: { source, _ in .mock(source) },
            post: { _, _, _, _ in "preview" },
            restoreSession: { .mock },
            setBookmarked: { _, _ in },
            setFollowing: { _, _ in },
            setLiked: { _, _ in },
            setReposted: { _, _ in },
            signIn: { _ in .mock },
            signOut: {},
            user: { _ in .mock }
        )
    }
}
