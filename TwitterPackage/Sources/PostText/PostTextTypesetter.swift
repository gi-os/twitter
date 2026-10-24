import Foundation
import Synchronization

/// Post text typeset into an attributed string: links on every entity, Twitter's bold/italic and Markdown styling as
/// inline presentation intents, and each entity tagged with ``PostEntityAttribute``.
package struct TypesetPostText: Equatable, Sendable {
    /// A stretch of the text that is either all one mention or has none, so a view can tag mention runs.
    package struct Segment: Equatable, Sendable {
        package let text: AttributedString
        /// The screen name, when this segment is a mention.
        package let mention: String?
    }

    package let input: PostTextInput
    package let attributedString: AttributedString
    /// The text split around mentions, in order; empty when it has none.
    package let segments: [Segment]

    package var hasMentions: Bool { !segments.isEmpty }

    /// Typesetting is deterministic, so equal inputs are equal outputs.
    package static func == (lhs: TypesetPostText, rhs: TypesetPostText) -> Bool {
        lhs.input == rhs.input
    }
}

/// Parses and typesets post text, and keeps what it built.
///
/// Modeled on the transcript app's payload transform: the work is a pure function of an `Equatable` input, it runs
/// off the main actor, and its results live in a cache keyed by the input itself (never a hash of it), so a row the
/// lazy stack recycles finds its text on its first frame. Views read ``cachedOrInline(_:)`` synchronously and fall
/// back to ``prepare(_:)`` for text too long to typeset inside a frame.
package enum PostTextTypesetter {
    /// Text up to this many UTF-16 units typesets inline on a cache miss: a few hundred microseconds, cheaper than a
    /// placeholder frame and the restyle that follows it. Longer text (note posts run to 25,000 characters) goes off
    /// the main actor.
    package static let inlineBudget = 600

    private static let cache = Mutex(GenerationalCache<PostTextInput, TypesetPostText>(capacity: 2_000))

    /// The cached result for `input`, if it was typeset before.
    package static func cached(_ input: PostTextInput) -> TypesetPostText? {
        cache.withLock { $0[input] }
    }

    /// The cached result, or one built now when `input` is within ``inlineBudget``; `nil` means call ``prepare(_:)``.
    package static func cachedOrInline(_ input: PostTextInput) -> TypesetPostText? {
        if let hit = cached(input) { return hit }
        guard input.text.utf16.count <= inlineBudget else { return nil }
        return typeset(input)
    }

    /// Typesets `input` on the caller's thread, through the cache.
    package static func typeset(_ input: PostTextInput) -> TypesetPostText {
        if let hit = cached(input) { return hit }
        // Built outside the lock: racing builders produce equal values.
        let value = build(input)
        cache.withLock { $0[input] = value }
        return value
    }

    /// Typesets `input` off the main actor, through the cache.
    @concurrent package static func prepare(_ input: PostTextInput) async -> TypesetPostText {
        typeset(input)
    }

    /// Fills the cache ahead of display, e.g. when a page of posts arrives.
    @concurrent package static func prewarm(_ inputs: [PostTextInput]) async {
        for input in inputs {
            if Task.isCancelled { return }
            _ = typeset(input)
        }
    }

    /// Parse and typeset without the cache.
    package static func build(_ input: PostTextInput) -> TypesetPostText {
        let pieces = PostTextParser.pieces(for: input)
        var string = AttributedString()
        var segments: [TypesetPostText.Segment] = []
        var pending = AttributedString()
        let hasMentions = pieces.contains {
            if case .mention = $0.entity { true } else { false }
        }

        for piece in pieces {
            var run = AttributedString(piece.text)
            if let entity = piece.entity {
                run.link = entity.destination
                run[PostEntityAttribute.self] = entity
            }
            if let intent = piece.emphasis.presentationIntent {
                run.inlinePresentationIntent = intent
            }
            string.append(run)
            guard hasMentions else { continue }
            if case .mention(let screenName) = piece.entity {
                if !pending.characters.isEmpty {
                    segments.append(.init(text: pending, mention: nil))
                    pending = AttributedString()
                }
                segments.append(.init(text: run, mention: screenName))
            } else {
                pending.append(run)
            }
        }
        if hasMentions, !pending.characters.isEmpty {
            segments.append(.init(text: pending, mention: nil))
        }
        return TypesetPostText(input: input, attributedString: string, segments: segments)
    }
}

/// Two generations of entries: lookups promote from the old one, and when the new one fills it becomes the old one.
/// An approximate LRU with O(1) work per operation and no per-entry bookkeeping.
struct GenerationalCache<Key: Hashable, Value> {
    let capacity: Int
    private var current: [Key: Value] = [:]
    private var previous: [Key: Value] = [:]

    init(capacity: Int) {
        self.capacity = capacity
    }

    subscript(key: Key) -> Value? {
        mutating get {
            if let value = current[key] { return value }
            guard let value = previous.removeValue(forKey: key) else { return nil }
            insert(value, for: key)
            return value
        }
        set {
            if let newValue { insert(newValue, for: key) } else { current[key] = nil }
        }
    }

    private mutating func insert(_ value: Value, for key: Key) {
        current[key] = value
        if current.count >= capacity {
            previous = current
            current = [:]
            current.reserveCapacity(capacity)
        }
    }
}

extension GenerationalCache: Sendable where Key: Sendable, Value: Sendable {}
