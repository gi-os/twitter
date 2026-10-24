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
        Color(.dogEarLikeStart), Color(.dogEarLikeEnd)
    ])
    fileprivate static let dogEarRepost = Gradient(colors: [
        Color(.dogEarRepostStart), Color(.dogEarRepostEnd)
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
                    colors: [Color(.gapGrooveTop), Color(.gapGrooveBottom)],
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

/// The end of a timeline or thread, said calmly: a fleuron pressed into the page the way Twitter for iPad pressed in
/// its bird (`emboss-bird`): a faint fill, shaded along its top inside edge, with the page's light catching the lip
/// below it.
package struct EndOfTimeline: View {
    package init() {}

    package var body: some View {
        DebossedGlyph(systemName: "fleuron.fill", size: 34)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .accessibilityLabel("End of timeline")
    }
}

/// A symbol pressed into the page: a faint fill, a shadow along its top inside edge (the glyph less itself moved
/// down), and the page's light on the lip below.
private struct DebossedGlyph: View {
    let systemName: String
    let size: CGFloat

    var body: some View {
        let glyph = Image(systemName: systemName).font(.system(size: size))
        glyph
            .foregroundStyle(Color(.debossFill))
            .overlay {
                glyph
                    .foregroundStyle(Color(.debossShadow))
                    .mask {
                        glyph
                            .overlay {
                                glyph.offset(y: 2).blendMode(.destinationOut)
                            }
                            .compositingGroup()
                            .blur(radius: 0.6)
                    }
                    .mask { glyph }
            }
            .background {
                glyph
                    .foregroundStyle(Color(.debossHighlight))
                    .offset(y: 1)
            }
            .accessibilityHidden(true)
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
