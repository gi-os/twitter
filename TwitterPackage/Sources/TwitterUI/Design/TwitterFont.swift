import CoreText
import SwiftUI
import UIKit

/// Chirp, bundled with this package and registered at launch; the system font stands in when it isn't available.
package enum TwitterFont {
    package enum Weight: Sendable {
        case regular, medium, bold, heavy

        var postScriptName: String {
            switch self {
            case .regular: "Chirp-Regular"
            case .medium: "Chirp-Medium"
            case .bold: "Chirp-Bold"
            case .heavy: "Chirp-Heavy"
            }
        }

        var system: Font.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .bold: .bold
            case .heavy: .heavy
            }
        }

        var uiSystem: UIFont.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .bold: .bold
            case .heavy: .heavy
            }
        }

        /// One step heavier, for Bold Text.
        var bolder: Weight {
            switch self {
            case .regular, .medium: .bold
            case .bold, .heavy: .heavy
            }
        }
    }

    /// Registers the bundled Chirp faces for this process. Safe to call more than once.
    package static func register() {
        _ = registration
    }

    /// Whether Chirp registered, checked once.
    package static var isAvailable: Bool { registration }

    private static let registration: Bool = {
        let urls =
            (Bundle.module.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? [])
            + (Bundle.module.urls(forResourcesWithExtension: "otf", subdirectory: "Fonts") ?? [])
        for url in Set(urls) where url.lastPathComponent.hasPrefix("Chirp") {
            // Already-registered fonts report an error here; the check below is what counts.
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return UIFont(name: Weight.regular.postScriptName, size: 12) != nil
    }()

    /// A fixed-size face: sizes come from ``TweetMetrics``, which already accounts for Dynamic Type.
    package static func font(size: CGFloat, weight: Weight) -> Font {
        isAvailable
            ? .custom(weight.postScriptName, fixedSize: size)
            : .system(size: size, weight: weight.system)
    }

    static func lineHeight(size: CGFloat) -> CGFloat {
        (UIFont(name: Weight.regular.postScriptName, size: size) ?? .systemFont(ofSize: size)).lineHeight
    }
}
