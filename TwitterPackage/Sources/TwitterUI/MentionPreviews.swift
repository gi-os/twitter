import Models
import PostText
import Routing
import SwiftUI
import UIKit

extension Text {
    /// The typeset text, with each mention's run tagged by a ``MentionRun`` attribute so its glyphs can be found in
    /// the text's layout. Text without mentions is a single attributed `Text`.
    init(mentionsTaggedIn typeset: TypesetPostText) {
        guard typeset.hasMentions else {
            self.init(typeset.attributedString)
            return
        }
        // A custom attribute belongs to a whole `Text`, so the string is joined from one `Text` per segment. The
        // format is nothing but placeholders ("%@%@…"), so the lookup finds no translation and adds no characters.
        var interpolation = LocalizedStringKey.StringInterpolation(
            literalCapacity: 0, interpolationCount: typeset.segments.count)
        for (index, segment) in typeset.segments.enumerated() {
            let text = Text(segment.text)
            interpolation.appendInterpolation(
                segment.mention == nil ? text : text.customAttribute(MentionRun(index: index)))
        }
        self.init(LocalizedStringKey(stringInterpolation: interpolation))
    }
}

/// Marks the glyph runs of one mention in a laid-out `Text`; `index` is its segment in ``TypesetPostText/segments``.
struct MentionRun: TextAttribute {
    let index: Int
}

extension EnvironmentValues {
    /// Off where text isn't interactive, such as inside a preview or a card that is one big button.
    @Entry package var mentionPreviewsEnabled = true
}

/// Long-pressing a mention lifts it and previews that profile, as a link in a text view would.
///
/// SwiftUI can't attach a context menu to part of a `Text`, so the mentions' glyph rects are read from the text's
/// layout (`Text.LayoutKey`, matched through ``MentionRun``) and a transparent UIKit layer over the text claims
/// touches only inside them. Elsewhere touches fall through to the text's links and the row underneath, including
/// the row's own context menu. Text without mentions adds nothing.
struct MentionPreviews: ViewModifier {
    let typeset: TypesetPostText
    @Environment(\.mentionPreviewsEnabled) private var isEnabled

    func body(content: Content) -> some View {
        if typeset.hasMentions, isEnabled {
            content.overlayPreferenceValue(Text.LayoutKey.self) { layouts in
                GeometryReader { proxy in
                    MentionInteractionLayer(targets: Self.targets(in: typeset, layouts: layouts, proxy: proxy))
                }
            }
        } else {
            content
        }
    }

    /// Each mention's rects, one per line it lands on, in the overlay's coordinates.
    @MainActor static func targets(
        in typeset: TypesetPostText, layouts: Text.LayoutKey.Value, proxy: GeometryProxy
    ) -> [MentionTarget] {
        var rects: [Int: [CGRect]] = [:]
        for anchored in layouts {
            let origin = proxy[anchored.origin]
            for line in anchored.layout {
                var lineRects: [Int: CGRect] = [:]
                for run in line {
                    guard let index = run[MentionRun.self]?.index else { continue }
                    let rect = run.typographicBounds.rect.offsetBy(dx: origin.x, dy: origin.y)
                    lineRects[index] = lineRects[index]?.union(rect) ?? rect
                }
                for (index, rect) in lineRects {
                    rects[index, default: []].append(rect)
                }
            }
        }
        return rects.sorted { $0.key < $1.key }.compactMap { index, rects in
            typeset.segments[index].mention.map { MentionTarget(screenName: $0, rects: rects) }
        }
    }
}

struct MentionTarget: Equatable {
    let screenName: String
    let rects: [CGRect]

    var url: URL? { PostEntity.mention(screenName).destination }
    var profileURL: URL? { URL(string: "https://x.com/\(screenName)") }
}

private struct MentionInteractionLayer: UIViewRepresentable {
    let targets: [MentionTarget]
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

    func makeUIView(context: Context) -> MentionInteractionView {
        MentionInteractionView()
    }

    func updateUIView(_ view: MentionInteractionView, context: Context) {
        view.targets = targets
        let openURL = openURL
        view.open = { openURL($0) }
        let openWindow = openWindow
        view.openWindow = supportsMultipleWindows ? { openWindow(value: Route.profileHandle($0).window) } : nil
    }
}

/// Claims touches only over mentions: a tap opens the profile, a long press shows its preview and menu.
private final class MentionInteractionView: UIView, UIContextMenuInteractionDelegate {
    var targets: [MentionTarget] = []
    var open: ((URL) -> Void)?
    var openWindow: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        // VoiceOver reaches mentions through the text's own links.
        accessibilityElementsHidden = true
        addInteraction(UIContextMenuInteraction(delegate: self))
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        target(at: point) != nil
    }

    private func target(at point: CGPoint) -> MentionTarget? {
        targets.first { target in
            target.rects.contains { $0.insetBy(dx: -2, dy: -2).contains(point) }
        }
    }

    private func target(for configuration: UIContextMenuConfiguration) -> MentionTarget? {
        guard let screenName = configuration.identifier as? String else { return nil }
        return targets.first { $0.screenName == screenName }
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        guard let url = target(at: recognizer.location(in: self))?.url else { return }
        open?(url)
    }

    // MARK: UIContextMenuInteractionDelegate

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let target = target(at: location) else { return nil }
        let screenName = target.screenName
        return UIContextMenuConfiguration(
            identifier: screenName as NSString,
            previewProvider: { ProfilePreviewController(screenName: screenName) },
            actionProvider: { [weak self] _ in self?.menu(for: target) }
        )
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configuration: UIContextMenuConfiguration,
        highlightPreviewForItemWithIdentifier identifier: any NSCopying
    ) -> UITargetedPreview? {
        target(for: configuration).flatMap(liftedPreview(of:))
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configuration: UIContextMenuConfiguration,
        dismissalPreviewForItemWithIdentifier identifier: any NSCopying
    ) -> UITargetedPreview? {
        target(for: configuration).flatMap(liftedPreview(of:))
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
        animator: any UIContextMenuInteractionCommitAnimating
    ) {
        guard let url = target(for: configuration)?.url else { return }
        animator.addCompletion { [weak self] in self?.open?(url) }
    }

    // MARK: Menu and preview

    private func menu(for target: MentionTarget) -> UIMenu {
        var primary: [UIMenuElement] = [
            UIAction(title: String(localized: "View Profile"), image: UIImage(systemName: "person.crop.circle")) {
                [weak self] _ in
                if let url = target.url { self?.open?(url) }
            }
        ]
        if let openWindow {
            primary.append(
                UIAction(
                    title: String(localized: "Open in New Window"), image: UIImage(systemName: "macwindow.badge.plus")
                ) { _ in openWindow(target.screenName) })
        }
        var secondary: [UIMenuElement] = [
            UIAction(title: String(localized: "Copy Username"), image: UIImage(systemName: "at")) { _ in
                UIPasteboard.general.string = "@\(target.screenName)"
            }
        ]
        if let profileURL = target.profileURL {
            secondary.append(
                UIAction(title: String(localized: "Copy Link"), image: UIImage(systemName: "link")) { _ in
                    UIPasteboard.general.url = profileURL
                })
        }
        return UIMenu(children: [
            UIMenu(options: .displayInline, children: primary),
            UIMenu(options: .displayInline, children: secondary)
        ])
    }

    /// The mention's glyphs as they're drawn: a snapshot of the screen under its rects, shaped to its lines.
    private func liftedPreview(of target: MentionTarget) -> UITargetedPreview? {
        guard let window, let first = target.rects.first else { return nil }
        let bounds = target.rects.dropFirst().reduce(first) { $0.union($1) }.insetBy(dx: -3, dy: -2)
        guard
            let snapshot = window.resizableSnapshotView(
                from: convert(bounds, to: window), afterScreenUpdates: false, withCapInsets: .zero)
        else { return nil }
        snapshot.frame = CGRect(origin: .zero, size: bounds.size)
        let lines = target.rects.map {
            NSValue(cgRect: $0.offsetBy(dx: -bounds.minX, dy: -bounds.minY).insetBy(dx: -3, dy: -2))
        }
        let parameters = UIPreviewParameters(textLineRects: lines)
        return UITargetedPreview(
            view: snapshot, parameters: parameters,
            target: UIPreviewTarget(container: self, center: CGPoint(x: bounds.midX, y: bounds.midY)))
    }
}
