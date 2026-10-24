import Foundation

/// A conservative inline Markdown scanner for free text people didn't write as Markdown: delimiters only count when
/// they flank a word the way CommonMark requires, no delimiter splits a word (`snake_case`, `2*3*4`), and URLs and
/// mentions are skipped whole so their punctuation is never read as styling.
///
/// Recognized: `**strong**` / `__strong__`, `*emphasis*` / `_emphasis_`, `~~strikethrough~~`, `` `code` `` (any
/// backtick run length), `[label](https://…)`, `<https://…>` autolinks and backslash escapes. Blocks (headings,
/// lists, quotes) are not: line breaks stay as written.
enum InlineMarkdownScanner {
    struct Segment: Equatable {
        var text: String
        var emphasis: PostTextEmphasis
        var link: URL?
    }

    static func segments(in text: String) -> [Segment] {
        var scanner = Scanner(characters: Array(text))
        scanner.parse(0..<scanner.characters.count, emphasis: [])
        scanner.flush(emphasis: [])
        return scanner.segments
    }

    private struct Scanner {
        let characters: [Character]
        var segments: [Segment] = []
        var buffer = ""

        init(characters: [Character]) {
            self.characters = characters
        }

        mutating func flush(emphasis: PostTextEmphasis, link: URL? = nil) {
            guard !buffer.isEmpty else { return }
            segments.append(Segment(text: buffer, emphasis: emphasis, link: link))
            buffer = ""
        }

        mutating func parse(_ range: Range<Int>, emphasis: PostTextEmphasis, link: URL? = nil) {
            var index = range.lowerBound
            while index < range.upperBound {
                let character = characters[index]
                switch character {
                case "\\" where index + 1 < range.upperBound && isEscapable(characters[index + 1]):
                    buffer.append(characters[index + 1])
                    index += 2
                    continue
                case "`":
                    if let end = codeSpan(at: index, in: range, emphasis: emphasis, link: link) {
                        index = end
                        continue
                    }
                case "[" where link == nil:
                    if let end = inlineLink(at: index, in: range, emphasis: emphasis) {
                        index = end
                        continue
                    }
                case "<" where link == nil:
                    if let end = autolink(at: index, in: range, emphasis: emphasis) {
                        index = end
                        continue
                    }
                case "h" where isWordStart(index):
                    if let end = bareURLEnd(at: index, in: range) {
                        buffer += String(characters[index..<end])
                        index = end
                        continue
                    }
                case "@", "＠":
                    if isWordStart(index), let end = mentionEnd(at: index, in: range) {
                        buffer += String(characters[index..<end])
                        index = end
                        continue
                    }
                case "*", "_", "~":
                    if let end = emphasisSpan(at: index, in: range, emphasis: emphasis, link: link) {
                        index = end
                        continue
                    }
                    // An unmatched run is literal, all of it, so its tail can't open a span on the next pass.
                    let run = runLength(of: character, at: index, in: range)
                    buffer += String(repeating: character, count: run)
                    index += run
                    continue
                default:
                    break
                }
                buffer.append(character)
                index += 1
            }
            flush(emphasis: emphasis, link: link)
        }

        // MARK: Spans

        /// `` `code` ``: a backtick run closed by a run of the same length; one space either side is trimmed when
        /// both are there. Returns the index after the closer.
        private mutating func codeSpan(
            at start: Int, in range: Range<Int>, emphasis: PostTextEmphasis, link: URL?
        ) -> Int? {
            let length = runLength(of: "`", at: start, in: range)
            var index = start + length
            while index < range.upperBound {
                guard characters[index] == "`" else {
                    index += 1
                    continue
                }
                let closing = runLength(of: "`", at: index, in: range)
                if closing == length {
                    var body = String(characters[(start + length)..<index])
                    if body.count > 2, body.first == " ", body.last == " " {
                        body = String(body.dropFirst().dropLast())
                    }
                    guard !body.isEmpty else { return nil }
                    flush(emphasis: emphasis, link: link)
                    segments.append(Segment(text: body, emphasis: emphasis.union(.code), link: link))
                    return index + closing
                }
                index += closing
            }
            return nil
        }

        /// `[label](https://…)` on one line; the label keeps its own inline styling.
        private mutating func inlineLink(at start: Int, in range: Range<Int>, emphasis: PostTextEmphasis) -> Int? {
            guard let close = firstIndex(of: "]", from: start + 1, in: range, stopAtNewline: true),
                close > start + 1, close + 1 < range.upperBound, characters[close + 1] == "(",
                let end = firstIndex(of: ")", from: close + 2, in: range, stopAtNewline: true),
                let url = webURL(String(characters[(close + 2)..<end]))
            else { return nil }
            flush(emphasis: emphasis)
            parse((start + 1)..<close, emphasis: emphasis, link: url)
            return end + 1
        }

        /// `<https://…>`.
        private mutating func autolink(at start: Int, in range: Range<Int>, emphasis: PostTextEmphasis) -> Int? {
            guard let end = firstIndex(of: ">", from: start + 1, in: range, stopAtNewline: true) else { return nil }
            let body = String(characters[(start + 1)..<end])
            guard !body.contains(" "), let url = webURL(body) else { return nil }
            flush(emphasis: emphasis)
            segments.append(Segment(text: body, emphasis: emphasis, link: url))
            return end + 1
        }

        /// `**strong**`, `*em*`, `__strong__`, `_em_`, `~~strike~~`: an opener followed by a non-space, closed by the
        /// same delimiter after a non-space, within one paragraph, and neither end inside a word (`2*3*4` stays math).
        private mutating func emphasisSpan(
            at start: Int, in range: Range<Int>, emphasis: PostTextEmphasis, link: URL?
        ) -> Int? {
            let delimiter = characters[start]
            let run = runLength(of: delimiter, at: start, in: range)
            let length: Int
            let style: PostTextEmphasis
            switch delimiter {
            case "~":
                guard run == 2 else { return nil }
                (length, style) = (2, .strikethrough)
            default:
                (length, style) = run >= 2 ? (2, .bold) : (1, .italic)
            }
            let contentStart = start + length
            guard contentStart < range.upperBound, !characters[contentStart].isWhitespace else { return nil }
            if start > 0, isWordCharacter(characters[start - 1]) { return nil }

            var index = contentStart + 1
            while index + length <= range.upperBound {
                let character = characters[index]
                if character == "\n", index + 1 < range.upperBound, characters[index + 1] == "\n" { return nil }
                if character == "`", let skip = matchingCodeEnd(at: index, in: range) {
                    index = skip
                    continue
                }
                if character == delimiter,
                    runLength(of: delimiter, at: index, in: range) >= length,
                    !characters[index - 1].isWhitespace,
                    index + length >= characters.count || !isWordCharacter(characters[index + length])
                {
                    flush(emphasis: emphasis, link: link)
                    parse(contentStart..<index, emphasis: emphasis.union(style), link: link)
                    return index + length
                }
                index += 1
            }
            return nil
        }

        // MARK: Atoms skipped whole

        private func bareURLEnd(at start: Int, in range: Range<Int>) -> Int? {
            let prefix = String(characters[start..<min(start + 8, range.upperBound)]).lowercased()
            guard prefix.hasPrefix("https://") || prefix.hasPrefix("http://") else { return nil }
            var end = start
            while end < range.upperBound, !characters[end].isWhitespace { end += 1 }
            return end
        }

        private func mentionEnd(at start: Int, in range: Range<Int>) -> Int? {
            var end = start + 1
            while end < range.upperBound, characters[end].isASCII,
                characters[end].isLetter || characters[end].isNumber || characters[end] == "_"
            {
                end += 1
            }
            return end > start + 1 ? end : nil
        }

        // MARK: Helpers

        private func runLength(of character: Character, at start: Int, in range: Range<Int>) -> Int {
            var end = start
            while end < range.upperBound, characters[end] == character { end += 1 }
            return end - start
        }

        private func matchingCodeEnd(at start: Int, in range: Range<Int>) -> Int? {
            let length = runLength(of: "`", at: start, in: range)
            var index = start + length
            while index < range.upperBound {
                if characters[index] == "`" {
                    let closing = runLength(of: "`", at: index, in: range)
                    if closing == length { return index + closing }
                    index += closing
                } else {
                    index += 1
                }
            }
            return nil
        }

        private func firstIndex(
            of target: Character, from start: Int, in range: Range<Int>, stopAtNewline: Bool
        ) -> Int? {
            var index = start
            while index < range.upperBound {
                let character = characters[index]
                if character == target { return index }
                if stopAtNewline, character.isNewline { return nil }
                index += 1
            }
            return nil
        }

        private func isWordStart(_ index: Int) -> Bool {
            index == 0 || !isWordCharacter(characters[index - 1])
        }

        private func isWordCharacter(_ character: Character) -> Bool {
            character.isLetter || character.isNumber || character == "_"
        }

        private func isEscapable(_ character: Character) -> Bool {
            character.isASCII && character.isPunctuation || "`*_~[]()<>#$@\\".contains(character)
        }

        private func webURL(_ string: String) -> URL? {
            guard let url = URL(string: string), let scheme = url.scheme?.lowercased(),
                scheme == "https" || scheme == "http", url.host() != nil
            else { return nil }
            return url
        }
    }
}
