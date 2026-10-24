import Foundation
import Testing

@testable import PostText

/// Precedence between what the API recognized and what the patterns find.
@Suite(.tags(.parser))
struct EntityScannerTests {
    @Test
    func knownLinkBeatsABareURLStartingAtTheSamePlace() throws {
        let destination = try #require(URL(string: "https://example.com/full"))
        let text = "go https://example.com/x now"
        let tokens = EntityScanner.tokens(in: text, links: ["https://example.com/x": destination], tags: [])
        #expect(entities(tokens, in: text) == [Found("https://example.com/x", .url(destination))])
    }

    @Test
    func longerKnownLinkWinsAndRepeatsAreAllFound() throws {
        let short = try #require(URL(string: "https://a.co"))
        let long = try #require(URL(string: "https://a.co/long"))
        let text = "a.co/long and a.co and a.co/long"
        let tokens = EntityScanner.tokens(in: text, links: ["a.co": short, "a.co/long": long], tags: [])
        #expect(
            entities(tokens, in: text) == [
                Found("a.co/long", .url(long)), Found("a.co", .url(short)), Found("a.co/long", .url(long))
            ])
    }

    @Test
    func knownTagsNeedWordBoundaries() {
        // A digits-only tag the pattern rejects still links when the API recognized it, on word boundaries only.
        let text = "#٣ C#٣ #٣_ #٣"
        let tokens = EntityScanner.tokens(in: text, links: [:], tags: ["#٣"])
        #expect(entities(tokens, in: text) == [Found("#٣", .hashtag("#٣")), Found("#٣", .hashtag("#٣"))])
    }

    @Test
    func tokensCoverTheWholeString() {
        let text = "hi @a, see #b and $CD."
        let tokens = EntityScanner.tokens(in: text, links: [:], tags: ["#b"])
        #expect(tokens.map { String(text[$0.range]) }.joined() == text)
        #expect(zip(tokens, tokens.dropFirst()).allSatisfy { $0.range.upperBound == $1.range.lowerBound })
    }

    // MARK: Helpers

    private struct Found: Equatable {
        let text: String
        let entity: PostEntity

        init(_ text: String, _ entity: PostEntity) {
            self.text = text
            self.entity = entity
        }
    }

    private func entities(_ tokens: [EntityScanner.Token], in text: String) -> [Found] {
        tokens.compactMap { token in token.entity.map { Found(String(text[token.range]), $0) } }
    }
}
