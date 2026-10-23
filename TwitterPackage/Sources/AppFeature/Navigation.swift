import Foundation
import XAPI

enum Route: Equatable {
  case profile(XUser)
  case profileHandle(String)
  case search(String)
  case thread(XTweet)

  init?(url: URL) {
    guard url.scheme == Route.scheme else { return nil }
    switch url.host() {
    case "user":
      self = .profileHandle(url.lastPathComponent)
    case "search":
      guard
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
          .queryItems?.first(where: { $0.name == "q" })?.value
      else { return nil }
      self = .search(query)
    default:
      return nil
    }
  }

  static let scheme = "twitter-client"
}

struct Draft: Equatable {
  var quoting: XTweet?
  var replyingTo: XTweet?
}

enum ContentDelegate: Equatable {
  case compose(Draft)
  case open(Route)
  case signOut
}

extension FeedSource {
  var title: String {
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
