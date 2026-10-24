import ComposableArchitecture
import Foundation
import Routing

/// A web page opened from a link, as Twitter for iPad's web panel: a column of its own beside the one it came from.
///
/// The page itself (its `WebPage`, history and loading) lives in the view; the feature keeps what the app needs to
/// know about it: which page it was opened for and is on now, so asking for it again focuses it, and links back into
/// Twitter open as columns instead of loading x.com.
@Reducer
package struct WebFeature {
    @ObservableState
    package struct State: Equatable, Identifiable {
        /// The page the panel was opened for.
        package let url: URL
        /// The page it's showing now, once it has navigated.
        package var currentURL: URL?
        package var title = ""

        package var id: URL { url }

        package init(url: URL) {
            self.url = url
        }

        /// Whether the panel shows the page at `other`, either the one it opened or the one it's on now.
        package func shows(_ other: URL) -> Bool {
            url.isSamePage(as: other) || currentURL.map { $0.isSamePage(as: other) } == true
        }

        /// The page to share or hand to Safari: wherever the reader has got to.
        package var pageURL: URL { currentURL ?? url }
    }

    package enum Action {
        case delegate(ContentDelegate)
        /// The page asked to go somewhere that has a home in the app (a post, a profile).
        case inAppLinkTapped(Route)
        case openInSafariButtonTapped
        case pageChanged(url: URL?, title: String)
    }

    @Dependency(\.openURL) var openURL

    package init() {}

    package var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

            case .inAppLinkTapped(let route):
                return .send(.delegate(.open(route)))

            case .openInSafariButtonTapped:
                return .run { [url = state.pageURL] _ in await openURL(url) }

            case .pageChanged(let url, let title):
                if let url { state.currentURL = url }
                state.title = title
                return .none
            }
        }
    }
}

extension URL {
    /// The same page, ignoring a trailing slash, letter case in the host and a fragment.
    fileprivate func isSamePage(as other: URL) -> Bool {
        func key(_ url: URL) -> String? {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            components.fragment = nil
            components.host = components.host?.lowercased()
            components.scheme = components.scheme?.lowercased()
            if components.path.hasSuffix("/") { components.path.removeLast() }
            return components.string
        }
        return key(self) == key(other)
    }
}
