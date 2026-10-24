import Foundation
import Routing

/// A recognized element of post text.
package enum PostEntity: Hashable, Codable, Sendable {
    case cashtag(String)
    case hashtag(String)
    /// The screen name, without its `@`.
    case mention(String)
    case url(URL)

    /// Where tapping it goes: the URL itself, or an in-app `twitter-client://` route that ``Route/init(url:)`` reads.
    package var destination: URL? {
        var components = URLComponents()
        components.scheme = Route.scheme
        switch self {
        case .url(let url):
            return url
        case .mention(let screenName):
            components.host = "user"
            components.path = "/\(screenName)"
        case .hashtag(let tag), .cashtag(let tag):
            components.host = "search"
            components.queryItems = [URLQueryItem(name: "q", value: tag)]
        }
        return components.url
    }
}

/// Inline styling a run of post text carries.
package struct PostTextEmphasis: OptionSet, Hashable, Sendable {
    package let rawValue: UInt8

    package init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    package static let bold = PostTextEmphasis(rawValue: 1 << 0)
    package static let italic = PostTextEmphasis(rawValue: 1 << 1)
    package static let code = PostTextEmphasis(rawValue: 1 << 2)
    package static let strikethrough = PostTextEmphasis(rawValue: 1 << 3)

    var presentationIntent: InlinePresentationIntent? {
        var intent: InlinePresentationIntent = []
        if contains(.bold) { intent.insert(.stronglyEmphasized) }
        if contains(.italic) { intent.insert(.emphasized) }
        if contains(.code) { intent.insert(.code) }
        if contains(.strikethrough) { intent.insert(.strikethrough) }
        return intent.isEmpty ? nil : intent
    }
}

/// Tags the runs of a typeset string with the entity they render, so callers (and tests) can find mentions, tags and
/// links without re-parsing. SwiftUI's `Text` ignores it.
package enum PostEntityAttribute: CodableAttributedStringKey {
    package typealias Value = PostEntity
    package static let name = "gold.samhenri.twitter.postEntity"
}

extension AttributeScopes {
    package struct PostTextAttributes: AttributeScope {
        package let postEntity: PostEntityAttribute
        package let foundation: FoundationAttributes
    }

    package var postText: PostTextAttributes.Type { PostTextAttributes.self }
}

extension AttributeDynamicLookup {
    package subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeScopes.PostTextAttributes, T>
    ) -> T {
        self[T.self]
    }
}
