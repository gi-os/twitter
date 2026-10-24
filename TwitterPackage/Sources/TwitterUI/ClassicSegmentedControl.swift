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
        EqualWidths {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                ClassicSegment(title: title(option), isSelected: option == selection, palette: palette) {
                    selection = option
                }
                .overlay(alignment: .leading) {
                    if index > 0 {
                        palette.divider.frame(width: 1)
                    }
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

/// Segments side by side, all as wide as the widest needs, so none is cut short where the control is given only the
/// room it asks for (in a navigation bar, say); offered more, they share it equally.
private struct EqualWidths: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let needed = (sizes.map(\.width).max() ?? 0) * CGFloat(subviews.count)
        let height = sizes.map(\.height).max() ?? 0
        let width = proposal.width.flatMap { $0.isFinite ? max($0, needed) : nil } ?? needed
        return CGSize(width: width, height: proposal.height.flatMap { $0.isFinite ? $0 : nil } ?? height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let width = bounds.width / CGFloat(subviews.count)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + CGFloat(index) * width, y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
        }
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
