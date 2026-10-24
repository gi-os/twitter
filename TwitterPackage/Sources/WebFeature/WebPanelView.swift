import ComposableArchitecture
import Routing
import SwiftUI
import WebKit

/// Twitter for iPad's web panel: the page in a column of its own, with its title and site in the bar and Safari's
/// controls beneath it. Links to posts and profiles open as columns after it instead of loading x.com.
package struct WebPanelView: View {
    let store: StoreOf<WebFeature>
    @State private var holder = WebPageHolder()

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
            .navigationSubtitle(Text(verbatim: (page.url ?? store.url).displayHost))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if page.isLoading {
                        Button("Stop", systemImage: "xmark") { page.stopLoading() }
                    } else {
                        Button("Reload", systemImage: "arrow.clockwise") { page.reload() }
                    }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Back", systemImage: "chevron.backward") {
                        if let item = page.backForwardList.backList.last { page.load(item) }
                    }
                    .disabled(page.backForwardList.backList.isEmpty)
                    Button("Forward", systemImage: "chevron.forward") {
                        if let item = page.backForwardList.forwardList.first { page.load(item) }
                    }
                    .disabled(page.backForwardList.forwardList.isEmpty)
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItemGroup(placement: .bottomBar) {
                    ShareLink(item: page.url ?? store.url)
                    Button("Open in Safari", systemImage: "safari") {
                        store.send(.openInSafariButtonTapped)
                    }
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
    /// The site, as people say it: "nytimes.com", not "www.nytimes.com".
    package var displayHost: String {
        guard let host = host() else { return absoluteString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
