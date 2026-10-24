import ComposableArchitecture
import Routing
import SwiftUI
import TwitterUI
import WebKit

/// Twitter for iPad's web panel: the page in a column of its own, with Twitter for iPad's web bar (title, back and
/// forward, reload) in its column bar, and sharing beside it. Links to posts and profiles open as columns after it instead of loading x.com.
package struct WebPanelView: View {
    let store: StoreOf<WebFeature>
    @State private var holder = WebPageHolder()
    @Environment(\.hasClassicSidebar) private var hasClassicSidebar
    @Environment(\.isFrontmostColumn) private var isFrontmostColumn

    package init(store: StoreOf<WebFeature>) {
        self.store = store
    }

    package var body: some View {
        let page = holder.page { [store] route in store.send(.inAppLinkTapped(route)) }
        WebView(page)
            // A sideways swipe slides the columns; it can't also mean "back".
            .webViewBackForwardNavigationGestures(.disabled)
            .overlay(alignment: .top) {
                LoadingBar(page: page)
            }
            .navigationTitle(page.title.isEmpty ? store.url.displayHost : page.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ClassicWebBar(
                        siteName: page.title.isEmpty ? (page.url ?? store.url).displayHost : page.title,
                        address: (page.url ?? store.url).displayAddress,
                        canGoBack: !page.backForwardList.backList.isEmpty,
                        canGoForward: !page.backForwardList.forwardList.isEmpty,
                        isLoading: page.isLoading,
                        back: { if let item = page.backForwardList.backList.last { page.load(item) } },
                        forward: { if let item = page.backForwardList.forwardList.first { page.load(item) } },
                        reload: { page.reload() },
                        stop: { page.stopLoading() }
                    )
                    .frame(maxWidth: 520)
                }
                .sharedBackgroundVisibility(.hidden)

                ClassicColumnMenuToolbarItem(
                    "Share",
                    glyph: .action,
                    isFrontmostColumn: isFrontmostColumn,
                    hasClassicSidebar: hasClassicSidebar
                ) {
                    WebPanelMenuItems(store: store)
                }
            }
            .task {
                // Once per page: a pushed panel that reappears keeps where the reader got to.
                if page.url == nil { page.load(store.url) }
            }
            .onChange(of: page.url) { reportPage(page) }
            .onChange(of: page.title) { reportPage(page) }
    }

    private func reportPage(_ page: WebPage) {
        store.send(.pageChanged(url: page.url, title: page.title))
    }
}

/// A web panel's share menu, for the page it's showing now.
package struct WebPanelMenuItems: View {
    let store: StoreOf<WebFeature>

    package init(store: StoreOf<WebFeature>) {
        self.store = store
    }

    package var body: some View {
        let url = store.currentURL ?? store.url
        ShareLink(item: url)

        Button("Open in Safari", systemImage: "safari") {
            store.send(.openInSafariButtonTapped)
        }

        Button("Copy Link", systemImage: "link") {
            UIPasteboard.general.url = url
        }
    }
}

/// Safari's thin progress line under the bar. Its own view, so progress ticks redraw only the line.
private struct LoadingBar: View {
    let page: WebPage

    var body: some View {
        ProgressView(value: page.estimatedProgress)
            .progressViewStyle(.linear)
            .opacity(page.isLoading ? 1 : 0)
            .animation(.easeOut(duration: 0.25), value: page.isLoading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Makes the panel's `WebPage` once, the first time the view needs it, and keeps it for the panel's life.
@MainActor
private final class WebPageHolder {
    private var page: WebPage?

    func page(openingInApp open: @escaping @MainActor (Route) -> Void) -> WebPage {
        if let page { return page }
        let page = WebPage(navigationDecider: InAppLinkDecider(open: open))
        self.page = page
        return page
    }
}

/// Sends links to posts and profiles to the app instead of loading them in the page.
private struct InAppLinkDecider: WebPage.NavigationDeciding {
    let open: @MainActor (Route) -> Void

    func decidePolicy(
        for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences
    ) async -> WKNavigationActionPolicy {
        // Only what the reader tapped: a redirect through x.com on the way to a page still loads.
        guard
            action.navigationType == .linkActivated,
            action.target?.isMainFrame ?? true,
            let url = action.request.url,
            let route = Route(url: url)
        else { return .allow }
        open(route)
        return .cancel
    }
}

extension URL {
    /// The address without its scheme, as Safari's bar shows it: "nytimes.com/2026/10/24/…".
    package var displayAddress: String {
        var address = displayHost + path()
        if address.hasSuffix("/") { address.removeLast() }
        return address
    }

    /// The site, as people say it: "nytimes.com", not "www.nytimes.com".
    package var displayHost: String {
        guard let host = host() else { return absoluteString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
