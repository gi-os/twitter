import SwiftUI
import UIKit

/// The window's layout margins and safe area, as UIKit lays its root view out: SwiftUI exposes the safe area but not
/// the margins inside it (the system's minimum, plus the safe area where it has one).
package struct WindowMargins: Equatable, Sendable {
    package var layoutMargins = EdgeInsets()
    package var safeArea = EdgeInsets()

    package init() {}

    /// Margins as an inset from the safe area: room the system leaves beside content that's already clear of the
    /// display's edges, the camera and the side bar.
    package var beyondSafeArea: EdgeInsets {
        EdgeInsets(
            top: max(layoutMargins.top - safeArea.top, 0),
            leading: max(layoutMargins.leading - safeArea.leading, 0),
            bottom: max(layoutMargins.bottom - safeArea.bottom, 0),
            trailing: max(layoutMargins.trailing - safeArea.trailing, 0)
        )
    }
}

extension View {
    /// Reports the window's ``WindowMargins`` whenever they change (turning, folding, the side bar moving).
    package func onWindowMarginsChange(_ action: @escaping (WindowMargins) -> Void) -> some View {
        background {
            WindowMarginsReader(action: action)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}

private struct WindowMarginsReader: UIViewRepresentable {
    let action: (WindowMargins) -> Void

    func makeUIView(context: Context) -> ReaderView {
        ReaderView()
    }

    func updateUIView(_ view: ReaderView, context: Context) {
        view.action = action
        view.report()
    }

    final class ReaderView: UIView {
        var action: ((WindowMargins) -> Void)?
        private var last: WindowMargins?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        // The root view's margins track the safe area; follow it when it changes.
        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            report()
        }

        func report() {
            guard let root = window?.rootViewController?.view else { return }
            let margins = root.directionalLayoutMargins
            let safe = root.safeAreaInsets
            let isRightToLeft = root.effectiveUserInterfaceLayoutDirection == .rightToLeft
            var value = WindowMargins()
            value.layoutMargins = EdgeInsets(
                top: margins.top, leading: margins.leading, bottom: margins.bottom, trailing: margins.trailing)
            value.safeArea = EdgeInsets(
                top: safe.top,
                leading: isRightToLeft ? safe.right : safe.left,
                bottom: safe.bottom,
                trailing: isRightToLeft ? safe.left : safe.right
            )
            guard value != last else { return }
            last = value
            let action = action
            // Outside the layout pass that found them.
            Task { @MainActor in action?(value) }
        }
    }
}
