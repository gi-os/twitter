import SwiftUI

/// Twitter for iPad's segmented control (`iPad-filter-header`): silver segments pressed into the bar, with a white
/// highlight beneath, and the chosen one pushed in.
package struct ClassicSegmentedControl<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> Text

    package init(_ options: [Value], selection: Binding<Value>, title: @escaping (Value) -> Text) {
        self.options = options
        _selection = selection
        self.title = title
    }

    package var body: some View {
        let palette = Palette()
        let shape = RoundedRectangle(cornerRadius: 6)
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                if index > 0 {
                    palette.divider.frame(width: 1)
                }
                ClassicSegment(title: title(option), isSelected: option == selection, palette: palette) {
                    selection = option
                }
            }
        }
        .frame(minHeight: 30)
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                LinearGradient(colors: [palette.borderTop, palette.borderBottom], startPoint: .top, endPoint: .bottom))
        }
        // The bar's light catching the lip below the control, so it reads as pressed into the bar.
        .background {
            shape.fill(palette.highlight).offset(y: 1)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

private struct ClassicSegment: View {
    let title: Text
    let isSelected: Bool
    let palette: Palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            title
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? palette.selectedText : palette.text)
                .shadow(color: palette.emboss, radius: 0, y: 1)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    LinearGradient(
                        colors: isSelected ? palette.selectedFill : palette.fill,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    // Pushed in: a shadow along the top inside edge.
                    .overlay(alignment: .top) {
                        if isSelected {
                            LinearGradient(
                                colors: [.black.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 4)
                        }
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Light and dark come from the asset catalog.
private struct Palette {
    let borderBottom = Color(.segmentBorderBottom)
    let borderTop = Color(.segmentBorderTop)
    let divider = Color(.segmentDivider)
    let emboss = Color(.segmentEmboss)
    let fill = [Color(.segmentFillTop), Color(.segmentFillBottom)]
    let highlight = Color(.segmentHighlight)
    let selectedFill = [Color(.segmentSelectedFillTop), Color(.segmentSelectedFillBottom)]
    let selectedText = Color(.segmentSelectedText)
    let text = Color(.segmentText)
}
