import Foundation
import Models

/// Everything that decides how a piece of post text is typeset; the typesetter's cache is keyed on it by equality.
package struct PostTextInput: Hashable, Sendable {
    /// How the text is read.
    package enum Flavor: Hashable, Sendable {
        /// A post: links, mentions, hashtags and cashtags, with Twitter's own bold/italic ranges. Markdown punctuation
        /// stays literal, as it does on Twitter.
        case post
        /// Free text that may carry inline Markdown (`**strong**`, `*emphasis*`, `` `code` ``, `~~strike~~`,
        /// `[label](https://…)`) on top of everything a post recognizes: community notes and profile bios.
        case markdown
    }

    package var text: String
    /// Substring of `text` → destination (a post's display URLs).
    package var links: [String: URL]
    /// Hashtags and cashtags (with their `#`/`$`) Twitter recognized; others are still found by pattern.
    package var tags: [String]
    /// Bold/italic ranges in Unicode-scalar offsets of `text`.
    package var styles: [TextStyleRange]
    package var flavor: Flavor
    /// When set, the text is cut at a word boundary near this many characters and ends in an ellipsis. A link,
    /// mention or tag is never cut in half: the cut moves to before it.
    package var characterLimit: Int?

    /// `characterLimit` only sticks when the text runs more than 20 characters past it, matching
    /// ``PostTextInput/needsTruncation(_:limit:)``.
    package init(
        text: String,
        links: [String: URL] = [:],
        tags: [String] = [],
        styles: [TextStyleRange] = [],
        flavor: Flavor = .post,
        characterLimit: Int? = nil
    ) {
        self.text = text
        self.links = links
        self.tags = tags
        self.styles = styles
        self.flavor = flavor
        self.characterLimit = characterLimit.flatMap { PostTextInput.needsTruncation(text, limit: $0) ? $0 : nil }
    }

    /// Whether `text` is long enough to cut at `limit`: short overruns read better whole.
    package static func needsTruncation(_ text: String, limit: Int) -> Bool {
        text.count > limit + 20
    }

    /// What to draw before the typeset text is ready: the raw text, cut the same way.
    package var placeholderText: String {
        guard let characterLimit else { return text }
        return PostTextInput.truncated(text, limit: characterLimit) ?? text
    }

    /// `text` cut at a word boundary near `limit` with an ellipsis, or `nil` when it already fits.
    package static func truncated(_ text: String, limit: Int) -> String? {
        guard needsTruncation(text, limit: limit) else { return nil }
        var prefix = text.prefix(limit)
        if let space = prefix.lastIndex(where: \.isWhitespace), prefix.distance(from: space, to: prefix.endIndex) < 40 {
            prefix = prefix[..<space]
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
