import SwiftUI

/// Twitter for iPad's web bar (`iPad-web-bar`), in a web panel's column bar in place of its title: a well pressed into
/// the bar holding the page's title, with back and forward on a dark segment at its leading end once there's somewhere
/// to go, and reload (or stop) at its trailing end.
package struct ClassicWebBar: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let isLoading: Bool
    let title: String
    let back: () -> Void
    let forward: () -> Void
    let reload: () -> Void
    let stop: () -> Void

    package init(
        title: String,
        canGoBack: Bool,
        canGoForward: Bool,
        isLoading: Bool,
        back: @escaping () -> Void,
        forward: @escaping () -> Void,
        reload: @escaping () -> Void,
        stop: @escaping () -> Void
    ) {
        self.back = back
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.forward = forward
        self.isLoading = isLoading
        self.reload = reload
        self.stop = stop
        self.title = title
    }

    @Environment(\.colorScheme) private var colorScheme

    package var body: some View {
        let isDark = colorScheme == .dark
        HStack(spacing: 0) {
            if canGoBack || canGoForward {
                WebBarSegment(canGoBack: canGoBack, canGoForward: canGoForward, back: back, forward: forward)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.webBarTitle))
                .shadow(color: isDark ? .black.opacity(0.6) : .white.opacity(0.8), radius: 0, y: 1)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)

            Button(action: isLoading ? stop : reload) {
                WebBarReloadGlyph(isLoading: isLoading)
                    .frame(width: 34, height: 30)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLoading ? "Stop" : "Reload")
        }
        .frame(height: 30)
        .background {
            // The well: darker than the bar, shaded along its top inside edge.
            Capsule().fill(.black.opacity(isDark ? 0.35 : 0.15))
        }
        .clipShape(.capsule)
        .overlay {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [.black.opacity(isDark ? 0.6 : 0.35), .black.opacity(isDark ? 0.3 : 0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        // The bar's light catching the lip below the well.
        .background {
            Capsule().fill(.white.opacity(isDark ? 0.08 : 0.9)).offset(y: 1)
        }
        .animation(.snappy, value: canGoBack || canGoForward)
    }
}

/// Back and forward on Twitter for iPad's dark segment, as white arrows.
private struct WebBarSegment: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let back: () -> Void
    let forward: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            WebBarArrow(title: "Back", image: "WebBack", action: back)
                .disabled(!canGoBack)

            Color(.webBarSegmentDivider).frame(width: 1)

            WebBarArrow(title: "Forward", image: "WebForward", action: forward)
                .disabled(!canGoForward)
        }
        .background {
            LinearGradient(
                colors: [
                    Color(.webBarSegmentTop),
                    Color(.webBarSegmentBottom)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private struct WebBarArrow: View {
    let title: LocalizedStringKey
    let image: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(image, bundle: .module)
                .shadow(color: .black.opacity(0.45), radius: 0, y: -1)
                .opacity(isEnabled ? 1 : 0.35)
                .frame(width: 36, height: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// 4.x's grey reload arrow, or a stop cross while the page loads.
private struct WebBarReloadGlyph: View {
    let isLoading: Bool

    var body: some View {
        Group {
            if isLoading {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color(.webBarGlyph))
            } else {
                Image("WebReload", bundle: .module)
            }
        }
        .shadow(color: .white.opacity(0.8), radius: 0, y: 1)
    }
}

