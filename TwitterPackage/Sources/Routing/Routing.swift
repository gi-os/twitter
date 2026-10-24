import Foundation
import Models

package enum Route: Hashable, Sendable {
    case profile(User)
    case profileHandle(String)
    case search(String)
    case thread(Tweet)
    case threadID(String)
    /// A page on the web: a panel of its own beside the columns, or Safari's own view on a single stack.
    case web(URL)

    /// In-app links (mentions, hashtags) and links to posts and profiles on twitter.com or x.com.
    package init?(url: URL) {
        if url.scheme == Route.scheme {
            switch url.host() {
            case "user":
                self = .profileHandle(url.lastPathComponent)
            case "search":
                guard let query = url.queryValue(for: "q") else { return nil }
                self = .search(query)
            default:
                return nil
            }
            return
        }

        guard
            url.scheme == "https" || url.scheme == "http",
            let host = url.host()?.lowercased(),
            Route.webHosts.contains(host)
        else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        switch components.count {
        case 1 where !Route.reservedPaths.contains(components[0].lowercased()):
            self = .profileHandle(components[0])
        case 2 where components[0].lowercased() == "hashtag":
            self = .search("#\(components[1])")
        case 1 where components[0].lowercased() == "search":
            guard let query = url.queryValue(for: "q") else { return nil }
            self = .search(query)
        case 3... where components[1] == "status" && components[2].allSatisfy(\.isNumber):
            self = .threadID(components[2])
        default:
            return nil
        }
    }

    package static let scheme = "twitter-client"

    private static let webHosts: Set<String> = [
        "mobile.twitter.com", "mobile.x.com", "twitter.com", "www.twitter.com", "www.x.com", "x.com"
    ]
    private static let reservedPaths: Set<String> = [
        "compose", "explore", "hashtag", "home", "i", "intent", "messages", "notifications", "search", "settings",
        "share", "tos", "privacy"
    ]

    /// The window that shows this route on its own. Windows are identified by IDs rather than model snapshots, so
    /// opening the same post twice brings its window forward instead of making a second one.
    package var window: WindowRoute {
        switch self {
        case .profile(let user): .profile(screenName: user.screenName.lowercased())
        case .profileHandle(let screenName): .profile(screenName: screenName.lowercased())
        case .search(let query): .search(query)
        case .thread(let tweet): .thread(tweetID: tweet.id)
        case .threadID(let id): .thread(tweetID: id)
        case .web(let url): .web(url)
        }
    }

    /// Where a tapped link goes: in-app routes stay in the app, other web pages open in a web panel, and anything else
    /// (mail, phone numbers, other apps) goes to the system. `nil` means "hand it to the system".
    package static func forLink(_ url: URL) -> Route? {
        if let route = Route(url: url) { return route }
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http", url.host() != nil
        else { return nil }
        return .web(url)
    }
}

/// The value a standalone window is opened with and restored from.
package enum WindowRoute: Codable, Hashable, Sendable {
    case profile(screenName: String)
    case search(String)
    case thread(tweetID: String)
    case web(URL)

    package var route: Route {
        switch self {
        case .profile(let screenName): .profileHandle(screenName)
        case .search(let query): .search(query)
        case .thread(let tweetID): .threadID(tweetID)
        case .web(let url): .web(url)
        }
    }
}

extension URL {
    fileprivate func queryValue(for name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }
}

package struct Draft: Equatable {
    package var quoting: Tweet?
    package var replyingTo: Tweet?

    package init(quoting: Tweet? = nil, replyingTo: Tweet? = nil) {
        self.quoting = quoting
        self.replyingTo = replyingTo
    }
}

package enum ContentDelegate: Equatable {
    case compose(Draft)
    case open(Route)
    case signOut
}

extension FeedSource {
    package var title: String {
        switch self {
        case .bookmarks: "Bookmarks"
        case .home(let following): following ? "Following" : "For You"
        case .notifications(let mentionsOnly): mentionsOnly ? "Mentions" : "All"
        case .search(_, let latest): latest ? "Latest" : "Top"
        case .thread: "Post"
        case .userLikes: "Likes"
        case .userMedia: "Media"
        case .userPosts: "Posts"
        case .userReplies: "Replies"
        }
    }
}
