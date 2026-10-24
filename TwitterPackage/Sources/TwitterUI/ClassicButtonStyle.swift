import SwiftUI

/// Twitter 4.x's pill buttons: `btn_default`, white with embossed grey text (pressing it darkens it, `btn_pressed`),
/// and `btn_following`, blue with white text, for the button that matters most.
package struct ClassicButtonStyle: ButtonStyle {
    let isProminent: Bool

    package func makeBody(configuration: Configuration) -> some View {
        ClassicButton(configuration: configuration, isProminent: isProminent)
    }
}

extension ButtonStyle where Self == ClassicButtonStyle {
    /// Twitter 4.x's white pill button.
    package static var classic: ClassicButtonStyle { ClassicButtonStyle(isProminent: false) }
    /// Twitter 4.x's blue pill button.
    package static var classicProminent: ClassicButtonStyle { ClassicButtonStyle(isProminent: true) }
}

private struct ClassicButton: View {
    let configuration: ButtonStyle.Configuration
    let isProminent: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .lineLimit(1)
            .foregroundStyle(isProminent ? Color.white : Color(.buttonText))
            .shadow(color: isProminent ? .black.opacity(0.3) : .white, radius: 0, y: isProminent ? -1 : 1)
            .padding(.horizontal, 16)
            .frame(minHeight: 31)
            .background {
                // The bitmaps are 11 × 31 pt: rounded ends, with the point-wide middle stretching.
                Image(backgroundName, bundle: .module)
                    .resizable(capInsets: EdgeInsets(top: 15, leading: 5, bottom: 15, trailing: 5))
            }
            .brightness(isProminent && configuration.isPressed ? -0.12 : 0)
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(.capsule)
    }

    private var backgroundName: String {
        if isProminent {
            "ButtonFollowing"
        } else if configuration.isPressed {
            "ButtonPressed"
        } else {
            "ButtonDefault"
        }
    }
}

/// 4.x's follow glyph: a blue bird and a plus to follow, a white bird and a check once following, for the white and
/// blue ``ClassicButtonStyle`` buttons.
package struct ClassicFollowGlyph: View {
    let isFollowing: Bool

    package init(isFollowing: Bool) {
        self.isFollowing = isFollowing
    }

    package var body: some View {
        Image(isFollowing ? "FollowBirdChecked" : "FollowBird", bundle: .module)
            .accessibilityHidden(true)
    }
}
