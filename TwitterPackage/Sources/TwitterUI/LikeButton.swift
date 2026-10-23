import Pow
import SwiftUI

package struct LikeButton: View {
    let action: () -> Void
    let count: Int
    let isLiked: Bool

    package init(isLiked: Bool, count: Int, action: @escaping () -> Void) {
        self.action = action
        self.count = count
        self.isLiked = isLiked
    }

    package var body: some View {
        Button {
            withAnimation {
                action()
            }
        } label: {
            HStack(spacing: 4) {
                if isLiked {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink.gradient)
                        .transition(.movingParts.pop(.pink))
                } else {
                    Image(systemName: "heart")
                        .foregroundStyle(.secondary)
                        .transition(.identity)
                }

                if count > 0 {
                    Text(count.compact)
                        .animation(isLiked ? .default.delay(0.4) : nil, value: isLiked)
                }
            }
            .foregroundStyle(.secondary)
            .frame(minHeight: 32)
            .font(.footnote)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLiked ? "Unlike" : "Like")
        .accessibilityValue(count.formatted())
        .sensoryFeedback(.selection, trigger: isLiked)
    }
}

#Preview {
    @Previewable @State var isLiked = false
    LikeButton(isLiked: isLiked, count: isLiked ? 561 : 560) {
        isLiked.toggle()
    }
    .padding()
}
