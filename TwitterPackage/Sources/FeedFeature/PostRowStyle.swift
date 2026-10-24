import ComposableArchitecture
import SwiftUI
import TwitterUI

/// How a post row is laid out.
package enum PostRowStyle: String, CaseIterable, Sendable {
    /// Stacked where the column is narrow for its text size (``TweetMetrics/isNarrowColumn``), classic elsewhere:
    /// decided by the room a column actually has, not by which display or device it's on.
    case automatic
    /// Twitter's timeline: the avatar in its own column, and everything else beside it.
    case classic
    /// The avatar beside the name with the handle under it, and the post below both at the row's full width,
    /// like Twitter's focused post. Gives narrow columns the most room to read.
    case stacked

    package var title: LocalizedStringKey {
        switch self {
        case .automatic: "Automatic"
        case .classic: "Classic"
        case .stacked: "Stacked"
        }
    }

    package var systemImage: String {
        switch self {
        case .automatic: "rectangle.and.arrow.up.right.and.arrow.down.left"
        case .classic: "text.alignleft"
        case .stacked: "rectangle.portrait.topthird.inset.filled"
        }
    }

    /// The layout to draw: ``automatic`` resolved against the column's metrics.
    package func resolved(in metrics: TweetMetrics) -> Self {
        switch self {
        case .automatic: metrics.isNarrowColumn ? .stacked : .classic
        case .classic, .stacked: self
        }
    }
}

extension SharedKey where Self == AppStorageKey<PostRowStyle>.Default {
    /// The row layout the viewer picked, kept across launches.
    package static var postRowStyle: Self {
        Self[.appStorage("postRowStyle"), default: .automatic]
    }
}

/// A picker for ``PostRowStyle``, for a menu.
package struct PostRowStylePicker: View {
    @Shared(.postRowStyle) private var style

    package init() {}

    package var body: some View {
        Picker(selection: Binding($style)) {
            ForEach(PostRowStyle.allCases, id: \.self) { style in
                Label(style.title, systemImage: style.systemImage)
            }
        } label: {
            Label("Post Layout", systemImage: "rectangle.grid.1x2")
        }
        .pickerStyle(.menu)
    }
}
