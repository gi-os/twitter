import SwiftUI

// Tactile details carried over from Twitter for iPad (2012). The physical ideas stay (a folded corner, a groove,
// letterpress, depth between columns); the bitmaps don't. Glass is for controls, so these live on content surfaces
// and stay low-contrast.

/// Your mark on a post, like folding down the corner of a page: orange for a like, green for a repost, split
/// diagonally for both. Drawn in the row's top-trailing corner.
package struct DogEar: View {
    let isLiked: Bool
    let isReposted: Bool

    package init(isLiked: Bool, isReposted: Bool) {
        self.isLiked = isLiked
        self.isReposted = isReposted
    }

    package var body: some View {
        Canvas { context, size in
            let side = size.width
            var corner = Path()
            corner.move(to: .zero)
            corner.addLine(to: CGPoint(x: side, y: 0))
            corner.addLine(to: CGPoint(x: side, y: side))
            corner.closeSubpath()
            let start = CGPoint(x: side, y: 0)
            let end = CGPoint(x: side / 2, y: side / 2)
            if isLiked, isReposted {
                // The like takes the upper half of the fold, the repost the lower.
                var upper = Path()
                upper.move(to: .zero)
                upper.addLine(to: CGPoint(x: side, y: 0))
                upper.addLine(to: CGPoint(x: side / 2, y: side / 2))
                upper.closeSubpath()
                context.fill(corner, with: .linearGradient(.dogEarRepost, startPoint: start, endPoint: end))
                context.fill(upper, with: .linearGradient(.dogEarLike, startPoint: start, endPoint: end))
            } else {
                context.fill(
                    corner,
                    with: .linearGradient(isLiked ? .dogEarLike : .dogEarRepost, startPoint: start, endPoint: end)
                )
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}

extension Gradient {
    fileprivate static let dogEarLike = Gradient(colors: [
        Color(red: 1, green: 0.533, blue: 0), Color(red: 0.996, green: 0.882, blue: 0.329)
    ])
    fileprivate static let dogEarRepost = Gradient(colors: [
        Color(red: 0.333, green: 0.533, blue: 0.2), Color(red: 0.718, green: 1, blue: 0.518)
    ])
}

/// A tear in the timeline: something is missing here. A shallow groove with lit lips, light from above.
package struct GapGroove: View {
    @Environment(\.colorScheme) private var colorScheme

    package init() {}

    package var body: some View {
        let isDark = colorScheme == .dark
        Rectangle()
            .fill(
                LinearGradient(
                    colors: isDark
                        ? [Color(white: 0.07), Color(white: 0.10)]
                        : [Color(white: 0.898), Color(white: 0.839)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .shadow(.inner(color: .black.opacity(isDark ? 0.6 : 0.18), radius: 3, y: 2))
            )
            .overlay(alignment: .top) {
                Rectangle().fill(.white.opacity(isDark ? 0.06 : 0.9)).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(.white.opacity(isDark ? 0.08 : 0.9)).frame(height: 1)
            }
    }
}

extension View {
    /// Pressed into the surface rather than printed on it: a 1pt highlight below in light mode, shade above in dark.
    package func letterpress() -> some View {
        modifier(Letterpress())
    }
}

private struct Letterpress: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.shadow(
            color: colorScheme == .dark ? .black.opacity(0.8) : .white.opacity(0.9),
            radius: 0,
            y: colorScheme == .dark ? -1 : 1
        )
    }
}

/// The end of a timeline, said calmly: Twitter for iPad's bird, pressed into the page.
package struct EndOfTimeline: View {
    @Environment(\.colorScheme) private var colorScheme

    package init() {}

    package var body: some View {
        Group {
            if colorScheme == .dark {
                // The original is lit for a light page; on a dark one, press a vector bird in instead.
                Image(systemName: "bird.fill")
                    .font(.title)
                    .foregroundStyle(.quaternary)
                    .letterpress()
            } else {
                Image("EmbossedBird", bundle: .module)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .accessibilityLabel("End of timeline")
    }
}

/// The surface the column stack sits on, seen between columns and in the fold: Twitter for iPad's dark woven desk,
/// with columns lying on it like paper.
package struct ColumnBackdrop: View {
    package init() {}

    package var body: some View {
        Image("WovenBackdrop", bundle: .module)
            .resizable(resizingMode: .tile)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
