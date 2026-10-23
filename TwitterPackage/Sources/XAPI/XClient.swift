import Dependencies
import DependenciesMacros
import Foundation

package enum FeedSource: Hashable, Sendable {
  case bookmarks
  case home(following: Bool)
  case notifications(mentionsOnly: Bool)
  case search(query: String, latest: Bool)
  case thread(tweetID: String)
  case userLikes(userID: String)
  case userMedia(userID: String)
  case userPosts(userID: String)
  case userReplies(userID: String)
}

package struct MediaUpload: Hashable, Sendable {
  package var data: Data
  package var mimeType: String

  package init(data: Data, mimeType: String) {
    self.data = data
    self.mimeType = mimeType
  }
}

@DependencyClient
package struct XClient: Sendable {
  package var deleteTweet: @Sendable (_ id: String) async throws -> Void
  package var feed: @Sendable (_ source: FeedSource, _ cursor: String?) async throws -> FeedPage
  package var post: @Sendable (
    _ text: String, _ replyTo: String?, _ quoteURL: URL?, _ media: [MediaUpload]
  ) async throws -> String
  package var restoreSession: @Sendable () async throws -> XUser?
  package var setBookmarked: @Sendable (_ isBookmarked: Bool, _ tweetID: String) async throws -> Void
  package var setFollowing: @Sendable (_ isFollowing: Bool, _ userID: String) async throws -> Void
  package var setLiked: @Sendable (_ isLiked: Bool, _ tweetID: String) async throws -> Void
  package var setReposted: @Sendable (_ isReposted: Bool, _ tweetID: String) async throws -> Void
  package var signIn: @Sendable (_ cookies: [String: String]) async throws -> XUser
  package var signOut: @Sendable () async -> Void
  package var user: @Sendable (_ screenName: String) async throws -> XUser
}

extension XClient: DependencyKey {
  package static var liveValue: XClient {
    let store = SessionStore()
    return XClient(
      deleteTweet: { try await store.session().deleteTweet(id: $0) },
      feed: { source, cursor in try await store.session().feed(source, cursor: cursor) },
      post: { text, replyTo, quoteURL, media in
        let session = try await store.session()
        var mediaIDs: [String] = []
        for upload in media {
          let category: XWebSession.MediaCategory =
            upload.mimeType.hasPrefix("video") ? .video : upload.mimeType == "image/gif" ? .gif : .image
          mediaIDs.append(
            try await session.uploadMedia(upload.data, mimeType: upload.mimeType, category: category)
          )
        }
        return try await session.post(text: text, replyTo: replyTo, mediaIDs: mediaIDs, quoteURL: quoteURL)
      },
      restoreSession: { try await store.restore() },
      setBookmarked: { try await store.session().setBookmarked($0, tweetID: $1) },
      setFollowing: { try await store.session().setFollowing($0, userID: $1) },
      setLiked: { try await store.session().setLiked($0, tweetID: $1) },
      setReposted: { try await store.session().setReposted($0, tweetID: $1) },
      signIn: { try await store.signIn(cookies: $0) },
      signOut: { await store.signOut() },
      user: { try await store.session().user(screenName: $0) }
    )
  }

  package static var previewValue: XClient {
    XClient(
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

private actor SessionStore {
  private var current: XWebSession?

  func restore() async throws -> XUser? {
    guard let cookies = Keychain.loadCookies() else { return nil }
    let session = makeSession(cookies: cookies)
    do {
      return try await session.viewer()
    } catch XError.unauthorized {
      signOut()
      return nil
    }
  }

  func signIn(cookies: [String: String]) async throws -> XUser {
    Keychain.saveCookies(cookies)
    return try await makeSession(cookies: cookies).viewer()
  }

  func signOut() {
    current = nil
    Keychain.deleteCookies()
  }

  func session() throws -> XWebSession {
    guard let current else { throw XError.notSignedIn }
    return current
  }

  private func makeSession(cookies: [String: String]) -> XWebSession {
    let session = XWebSession(cookies: cookies) { Keychain.saveCookies($0) }
    current = session
    return session
  }
}

extension XWebSession {
  func feed(_ source: FeedSource, cursor: String?) async throws -> FeedPage {
    switch source {
    case .bookmarks:
      try await bookmarks(cursor: cursor)
    case .home(let following):
      try await homeTimeline(following: following, cursor: cursor)
    case .notifications(let mentionsOnly):
      try await notifications(type: mentionsOnly ? "Mentions" : "All", cursor: cursor)
    case .search(let query, let latest):
      try await search(query, latest: latest, cursor: cursor)
    case .thread(let tweetID):
      try await tweetDetail(id: tweetID, cursor: cursor)
    case .userLikes(let userID):
      try await likes(userID: userID, cursor: cursor)
    case .userMedia(let userID):
      try await userMedia(userID: userID, cursor: cursor)
    case .userPosts(let userID):
      try await userTweets(userID: userID, cursor: cursor)
    case .userReplies(let userID):
      try await userReplies(userID: userID, cursor: cursor)
    }
  }
}
