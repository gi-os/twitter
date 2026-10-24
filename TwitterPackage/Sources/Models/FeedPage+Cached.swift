extension FeedPage {
    /// A page rebuilt from storage rather than parsed from a response.
    package init(cachedItems items: [FeedItem], bottomCursor: String?) {
        self.init(items: items, bottomCursor: bottomCursor, topCursor: nil)
    }
}
