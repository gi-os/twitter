import Foundation
import Models

/// A run of parsed post text: uniform styling, and at most one entity.
package struct PostTextPiece: Hashable, Sendable {
    package var text: String
    package var entity: PostEntity?
    package var emphasis: PostTextEmphasis

    package init(text: String, entity: PostEntity? = nil, emphasis: PostTextEmphasis = []) {
        self.text = text
        self.entity = entity
        self.emphasis = emphasis
    }
}

/// Post text → pieces. Pure and synchronous; ``PostTextTypesetter`` decides where it runs and caches the result.
///
/// The passes, in order:
/// 1. **Blocks of styling**: for ``PostTextInput/Flavor/markdown``, the inline Markdown scanner splits the text into
///    emphasized, code and link segments (posts are one segment).
/// 2. **Entities**: each plain segment is tokenized into URLs, mentions, hashtags and cashtags. Entities are atomic:
///    nothing later splits or restyles part of one, except Twitter's own bold/italic ranges.
/// 3. **Twitter styles**: a post's Unicode-scalar bold/italic ranges cut pieces at their edges.
/// 4. **Character references**: `&amp;`-style escapes left in plain text are decoded.
/// 5. **Truncation**, when a character limit is set, at a word boundary and never inside an entity.
package enum PostTextParser {
    package static func pieces(for input: PostTextInput) -> [PostTextPiece] {
        var pieces =
            switch input.flavor {
            case .post: postPieces(input)
            case .markdown: markdownPieces(input)
            }
        if let limit = input.characterLimit {
            pieces = truncate(pieces, limit: limit)
        }
        return coalesce(pieces)
    }

    // MARK: Posts

    private static func postPieces(_ input: PostTextInput) -> [PostTextPiece] {
        let text = input.text
        let scalars = text.unicodeScalars
        let tokens = EntityScanner.tokens(in: text, links: input.links, tags: input.tags)
        guard !input.styles.isEmpty else {
            return tokens.map { token in
                piece(String(scalars[token.range]), entity: token.entity, emphasis: [])
            }
        }

        let count = scalars.count
        let styled: [(range: Range<String.Index>, emphasis: PostTextEmphasis)] = input.styles.compactMap { style in
            let lower = min(max(style.range.lowerBound, 0), count)
            let upper = min(max(style.range.upperBound, lower), count)
            guard lower < upper, style.isBold || style.isItalic else { return nil }
            let start = scalars.index(scalars.startIndex, offsetBy: lower)
            let end = scalars.index(start, offsetBy: upper - lower)
            var emphasis: PostTextEmphasis = []
            if style.isBold { emphasis.insert(.bold) }
            if style.isItalic { emphasis.insert(.italic) }
            return (start..<end, emphasis)
        }
        let boundaries = Set(styled.flatMap { [$0.range.lowerBound, $0.range.upperBound] }).sorted()

        var pieces: [PostTextPiece] = []
        for token in tokens {
            let inner = boundaries.filter { $0 > token.range.lowerBound && $0 < token.range.upperBound }
            let cuts = [token.range.lowerBound] + inner + [token.range.upperBound]
            for (start, end) in zip(cuts, cuts.dropFirst()) {
                let emphasis = styled.reduce(into: PostTextEmphasis()) { emphasis, style in
                    if style.range.lowerBound <= start, end <= style.range.upperBound {
                        emphasis.formUnion(style.emphasis)
                    }
                }
                pieces.append(piece(String(scalars[start..<end]), entity: token.entity, emphasis: emphasis))
            }
        }
        return pieces
    }

    // MARK: Markdown

    private static func markdownPieces(_ input: PostTextInput) -> [PostTextPiece] {
        var pieces: [PostTextPiece] = []
        for segment in InlineMarkdownScanner.segments(in: input.text) {
            if let link = segment.link {
                pieces.append(PostTextPiece(text: segment.text, entity: .url(link), emphasis: segment.emphasis))
            } else if segment.emphasis.contains(.code) {
                pieces.append(PostTextPiece(text: segment.text, emphasis: segment.emphasis))
            } else {
                let scalars = segment.text.unicodeScalars
                for token in EntityScanner.tokens(in: segment.text, links: input.links, tags: input.tags) {
                    pieces.append(
                        piece(String(scalars[token.range]), entity: token.entity, emphasis: segment.emphasis))
                }
            }
        }
        return pieces
    }

    // MARK: Shared passes

    private static func piece(_ text: String, entity: PostEntity?, emphasis: PostTextEmphasis) -> PostTextPiece {
        PostTextPiece(text: entity == nil ? CharacterReferences.decode(text) : text, entity: entity, emphasis: emphasis)
    }

    /// Keeps whole pieces up to `limit` characters, cuts the plain piece that crosses it at a nearby word boundary,
    /// and drops an entity that crosses it rather than show half of one.
    private static func truncate(_ pieces: [PostTextPiece], limit: Int) -> [PostTextPiece] {
        var result: [PostTextPiece] = []
        var used = 0
        for piece in pieces {
            let count = piece.text.count
            if used + count <= limit {
                result.append(piece)
                used += count
                continue
            }
            if piece.entity == nil {
                var prefix = piece.text.prefix(limit - used)
                if let space = prefix.lastIndex(where: \.isWhitespace),
                    prefix.distance(from: space, to: prefix.endIndex) < 40
                {
                    prefix = prefix[..<space]
                }
                var cut = piece
                cut.text = String(prefix)
                result.append(cut)
            }
            break
        }
        while var last = result.popLast() {
            let trimmed = String(last.text.reversed().drop(while: \.isWhitespace).reversed())
            guard !trimmed.isEmpty else { continue }
            last.text = trimmed
            result.append(last)
            break
        }
        result.append(PostTextPiece(text: "…"))
        return result
    }

    /// Joins neighbours that render identically and drops empty pieces.
    private static func coalesce(_ pieces: [PostTextPiece]) -> [PostTextPiece] {
        var result: [PostTextPiece] = []
        result.reserveCapacity(pieces.count)
        for piece in pieces where !piece.text.isEmpty {
            if let last = result.last, last.entity == piece.entity, last.emphasis == piece.emphasis {
                result[result.count - 1].text += piece.text
            } else {
                result.append(piece)
            }
        }
        return result
    }
}

// MARK: - Entities

/// Finds links, mentions, hashtags and cashtags, covering the whole string with tokens.
enum EntityScanner {
    struct Token: Equatable {
        var range: Range<String.Index>
        var entity: PostEntity?
    }

    /// Group order in every pattern: known links, known tags, bare URLs, mentions, hashtags, cashtags.
    private static let entityPatterns = [
        #"(https?://[^\s<>"“”]+)"#,
        #"((?<![A-Za-z0-9_@＠!#$%&*])[@＠][A-Za-z0-9_]{1,20}(?![A-Za-z0-9_@＠]))"#,
        #"((?<![\w&#＃])[#＃](?=[\p{L}\p{M}\p{N}_]*[\p{L}\p{M}])[\p{L}\p{M}\p{N}_]+)"#,
        #"((?<![\w$])\$[A-Za-z]{1,6}(?:[._][A-Za-z]{1,2})?(?![\w]))"#
    ]
    private static let never = "((?!))"

    /// The pattern for text with no known links or tags, compiled once.
    private static let plainRegex = makeRegex(links: [], tags: [])

    static func tokens(in text: String, links: [String: URL], tags: [String]) -> [Token] {
        guard !text.isEmpty else { return [] }
        let regex =
            links.isEmpty && tags.isEmpty
            ? plainRegex : makeRegex(links: Array(links.keys), tags: tags)
        guard let regex else { return [Token(range: text.startIndex..<text.endIndex, entity: nil)] }

        var tokens: [Token] = []
        var cursor = text.startIndex
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let found = classify(match, in: text, links: links) else { continue }
            var (range, entity) = found
            if case .url = entity, links[String(text[range])] == nil {
                range = trimmingTrailingPunctuation(range, in: text)
                guard let url = URL(string: String(text[range])) else { continue }
                entity = .url(url)
            }
            guard range.lowerBound >= cursor, !range.isEmpty else { continue }
            if cursor < range.lowerBound { tokens.append(Token(range: cursor..<range.lowerBound, entity: nil)) }
            tokens.append(Token(range: range, entity: entity))
            cursor = range.upperBound
        }
        if cursor < text.endIndex { tokens.append(Token(range: cursor..<text.endIndex, entity: nil)) }
        return tokens
    }

    private static func classify(
        _ match: NSTextCheckingResult, in text: String, links: [String: URL]
    ) -> (Range<String.Index>, PostEntity)? {
        for group in 1...6 {
            let nsRange = match.range(at: group)
            guard nsRange.location != NSNotFound, let range = Range(nsRange, in: text) else { continue }
            let token = String(text[range])
            switch group {
            case 1:
                guard let url = links[token] else { return nil }
                return (range, .url(url))
            case 2, 5, 6:
                return (range, token.hasPrefix("$") ? .cashtag(token) : .hashtag(normalizedTag(token)))
            case 3:
                // Resolved (and trimmed) by the caller; the placeholder keeps the group's kind.
                return (range, .url(URL(string: "about:blank")!))
            case 4:
                return (range, .mention(String(token.dropFirst())))
            default:
                return nil
            }
        }
        return nil
    }

    /// Fullwidth `＃` searches as `#`.
    private static func normalizedTag(_ token: String) -> String {
        token.hasPrefix("＃") ? "#" + token.dropFirst() : token
    }

    /// A sentence's closing punctuation isn't part of the URL it ends on; a `)` is, when the URL opened one.
    private static func trimmingTrailingPunctuation(
        _ range: Range<String.Index>, in text: String
    ) -> Range<String.Index> {
        var end = range.upperBound
        while end > range.lowerBound {
            let previous = text.index(before: end)
            let character = text[previous]
            if character == ")" {
                let body = text[range.lowerBound..<previous]
                guard body.count(where: { $0 == "(" }) < body.count(where: { $0 == ")" }) + 1 else { break }
            } else if !".,:;!?'\"…".contains(character) {
                break
            }
            end = previous
        }
        return range.lowerBound..<end
    }

    private static func makeRegex(links: [String], tags: [String]) -> NSRegularExpression? {
        let linkGroup =
            links.isEmpty
            ? never
            : "("
                + links.sorted { $0.count > $1.count }.map(NSRegularExpression.escapedPattern(for:))
                .joined(separator: "|") + ")"
        let tagGroup =
            tags.isEmpty
            ? never
            : #"((?<![\w&@#$])(?:"#
                + tags.sorted { $0.count > $1.count }.map(NSRegularExpression.escapedPattern(for:))
                .joined(separator: "|") + #")(?![\w]))"#
        let pattern = ([linkGroup, tagGroup] + entityPatterns).joined(separator: "|")
        return try? NSRegularExpression(pattern: pattern)
    }
}

// MARK: - Character references

/// Decodes the HTML character references Twitter's API leaves in text: the five named XML ones, `&nbsp;`, and
/// numeric `&#39;` / `&#x27;` forms. Anything else stays as written.
enum CharacterReferences {
    private static let named: [Substring: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}"
    ]

    static func decode(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        result.reserveCapacity(text.utf8.count)
        var index = text.startIndex
        while let ampersand = text[index...].firstIndex(of: "&") {
            result += text[index..<ampersand]
            let afterAmpersand = text.index(after: ampersand)
            guard let semicolon = text[afterAmpersand...].prefix(10).firstIndex(of: ";"),
                let decoded = reference(text[afterAmpersand..<semicolon])
            else {
                result.append("&")
                index = afterAmpersand
                continue
            }
            result += decoded
            index = text.index(after: semicolon)
        }
        result += text[index...]
        return result
    }

    private static func reference(_ name: Substring) -> String? {
        if let named = named[name] { return named }
        guard name.first == "#" else { return nil }
        let digits = name.dropFirst()
        let value =
            digits.first == "x" || digits.first == "X"
            ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits, radix: 10)
        return value.flatMap(Unicode.Scalar.init).map { String(Character($0)) }
    }
}
