import SwiftUI
import UIKit

/// Twitter's timeline palette (light, and the "lights out" dark theme).
extension Color {
    /// gray1100 / #D9D9D9.
    package static let twitterPrimary = Color(light: 0x0F1419, dark: 0xD9D9D9)
    /// gray700: handles, timestamps, counts.
    package static let twitterSecondary = Color(light: 0x536471, dark: 0x71767B)
    /// gray200: dividers and thread lines.
    package static let twitterDivider = Color(light: 0xCFD9DE, dark: 0x333639)
    /// blue500: links, brand, verified.
    package static let twitterBlue = Color(light: 0x1D9BF0, dark: 0x1D9BF0)
    /// magenta500.
    package static let twitterLike = Color(light: 0xF91880, dark: 0xF91880)
    /// green500.
    package static let twitterRepost = Color(light: 0x00BA7C, dark: 0x00BA7C)
    /// `borderMedia`: 5% black or white.
    package static let twitterMediaBorder = Color(
        uiColor: UIColor {
            $0.userInterfaceStyle == .dark ? .white.withAlphaComponent(0.05) : .black.withAlphaComponent(0.05)
        }
    )

    init(light: UInt32, dark: UInt32) {
        self.init(
            uiColor: UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }
}

extension ShapeStyle where Self == Color {
    package static var twitterPrimary: Color { Color.twitterPrimary }
    package static var twitterSecondary: Color { Color.twitterSecondary }
    package static var twitterDivider: Color { Color.twitterDivider }
    package static var twitterBlue: Color { Color.twitterBlue }
    package static var twitterLike: Color { Color.twitterLike }
    package static var twitterRepost: Color { Color.twitterRepost }
    package static var twitterMediaBorder: Color { Color.twitterMediaBorder }
}

extension UIColor {
    fileprivate convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// A full-bleed hairline in the divider colour, in place of the system `Divider`.
package struct TwitterDivider: View {
    @Environment(\.displayScale) private var displayScale

    package init() {}

    package var body: some View {
        Rectangle()
            .fill(.twitterDivider)
            .frame(height: 1 / displayScale)
            .accessibilityHidden(true)
    }
}
