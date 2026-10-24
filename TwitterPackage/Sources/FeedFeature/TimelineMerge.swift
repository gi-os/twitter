import IdentifiedCollections
import Models

/// Folds a fresh first page into what's already on screen without moving the reader, like Twitter for iPad: newer
/// posts go above, everything the reader has scrolled to stays, and when the fresh page doesn't reach what's there,
/// a gap row marks what's missing and fills in when tapped.
struct TimelineMerge: Equatable {
    var bottomCursor: String?
    var items: IdentifiedArrayOf<FeedItem>
    /// Posts that weren't on screen before, above everything that was.
    var newCount: Int

    init(
        fresh page: FeedPage,
        onScreen existing: IdentifiedArrayOf<FeedItem>,
        existingCursor: String?
    ) {
        let fresh = IdentifiedArray(page.items, uniquingIDsWith: { first, _ in first })
        guard !existing.isEmpty else {
            self.init(items: fresh, bottomCursor: page.items.isEmpty ? nil : page.bottomCursor, newCount: 0)
            return
        }
        let overlap = fresh.firstIndex { existing[id: $0.id] != nil }
        let newer = fresh.prefix(upTo: overlap ?? fresh.endIndex)
        let newCount = newer.count { if case .tweet = $0 { true } else { false } }
        var items = fresh
        if overlap == nil, let gapCursor = page.bottomCursor {
            items.append(.showMore(Self.gap(cursor: gapCursor)))
        }
        for item in existing where items[id: item.id] == nil {
            items.append(item)
        }
        self.init(items: items, bottomCursor: existingCursor ?? page.bottomCursor, newCount: newCount)
    }

    private init(items: IdentifiedArrayOf<FeedItem>, bottomCursor: String?, newCount: Int) {
        self.bottomCursor = bottomCursor
        self.items = items
        self.newCount = newCount
    }

    /// A gap's row: loading its cursor fills in the posts between the fresh page and what was already there.
    static func gap(cursor: String) -> ShowMoreCursor {
        ShowMoreCursor(id: "\(gapPrefix)\(cursor)", cursor: cursor, label: "Load more posts")
    }

    static let gapPrefix = "gap-"
}
