import Dependencies
import Foundation
import Models
import TwitterClient

extension TwitterClient: DependencyKey {
    package static var liveValue: TwitterClient {
        let store = SessionStore()
        return TwitterClient(
            deleteTweet: { try await store.session().deleteTweet(id: $0) },
            feed: { source, cursor in try await store.session().feed(source, cursor: cursor) },
            post: { text, replyTo, quoteURL, media in
                let session = try await store.session()
                var mediaIDs: [String] = []
                for upload in media {
                    let category: TwitterWebSession.MediaCategory =
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
}

private actor SessionStore {
    private var current: TwitterWebSession?

    func restore() async throws -> User? {
        guard let cookies = Keychain.loadCookies() else { return nil }
        let session = makeSession(cookies: cookies)
        do {
            return try await session.viewer()
        } catch TwitterError.unauthorized {
            signOut()
            return nil
        }
    }

    func signIn(cookies: [String: String]) async throws -> User {
        Keychain.saveCookies(cookies)
        return try await makeSession(cookies: cookies).viewer()
    }

    func signOut() {
        current = nil
        Keychain.deleteCookies()
    }

    func session() throws -> TwitterWebSession {
        guard let current else { throw TwitterError.notSignedIn }
        return current
    }

    private func makeSession(cookies: [String: String]) -> TwitterWebSession {
        let session = TwitterWebSession(cookies: cookies) { Keychain.saveCookies($0) }
        current = session
        return session
    }
}

extension TwitterWebSession {
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
