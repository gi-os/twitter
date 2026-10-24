import ComposableArchitecture
import FeedFeature
import Models
import ProfileFeature
import Routing
import SearchFeature
import SwiftUI
import TwitterUI
import UserListFeature
import WebFeature

/// A tab's navigation, laid out for whichever iPhone Duo display and pose it's on, and never with an empty pane.
///
/// On a display too narrow for two columns, everything pushes onto one stack, and web pages open in Safari's view.
/// Otherwise it's Twitter for iPad's column stack: the root fills the width until something opens; each thing opened
/// becomes a column to the right of the one it came from (replacing any after it), and the newest slides in at the
/// trailing edge. Web pages are wide panels that leave a sliver of the column they came from. The columns are one strip
/// you slide with your finger anywhere, snapping to column edges in the direction you flick, with the ones slid under
/// the leading edge dimming as they go. Pull past the start and let go to throw every opened column away. Partially
/// folded, the columns sit on either side of the fold. The root column stays the same view throughout, so folding and
/// unfolding never loses its place.
///
/// Sliding never re-lays anything out: the strip is a scroll view, dimming is drawn from each column's position, and
/// the only state the slide writes (crossing the throw distance) lives in `ColumnStrip`, away from the columns.
package struct TabStackView: View {
    @Bindable var store: StoreOf<TabStack>
    let title: LocalizedStringKey

    package init(store: StoreOf<TabStack>, title: LocalizedStringKey) {
        self.store = store
        self.title = title
    }

    /// How columns slide in and out, for anything that should move in step with them.
    package static let columnSlide = ColumnLayout.slide

    @State private var measuredGeometry = ColumnGeometry()
    /// A column being pulled down by its bar, which the columns after it follow.
    @State private var pull: ColumnPull?
    @Environment(\.columnStripWidth) private var stripWidth
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// A Close tapped in a column: the strip slides the closed columns off before they're removed.
    @State private var closing: ColumnClosing?
    /// How many columns were open before the latest change, so a new column knows where it slides in from.
    @State private var shownDepth = 0

    package var body: some View {
        let wideColumns = store.path.map(\.isWide)
        let layout = ColumnLayout(geometry: geometry, wideColumns: wideColumns)
        let previousLayout = ColumnLayout(geometry: geometry, wideColumns: Array(wideColumns.prefix(shownDepth)))
        ColumnStrip(
            layout: layout,
            geometry: geometry,
            newestColumn: store.path.ids.last,
            closing: closing,
            finishClosing: finishClosing,
            throwAway: { popColumns(after: nil) }
        ) {
            HStack(spacing: 0) {
                // Where columns are possible the root never pushes (everything opens as a column), so it binds to the
                // always-empty path; on one stack it is the stack. A navigation stack doesn't survive its path binding
                // changing (it drops its root or ignores the pushes), so folding or unfolding gives it a fresh one, and
                // the feed restores its scroll position from state.
                NavigationStack(path: layout.canShowColumns ? rootColumnPath : path) {
                    TabRootView(store: store, title: title, isFrontmost: store.path.isEmpty || !layout.showsColumns)
                        .environment(\.isFrontmostColumn, store.path.isEmpty || !layout.showsColumns)
                        // A lone stack reaches under the side bar; painting it here keeps the fill beneath the bar's
                        // own buttons.
                        .classicSideBar()
                        // The strip's scroll view reaches under the side bar whatever its frame, and hands that inset
                        // to every column inside it, wherever the column is. Columns are laid out clear of the side
                        // bar already; a lone stack spans the strip and keeps clear of it.
                        .ignoresSafeArea(.container, edges: layout.showsColumns ? .horizontal : [])
                } destination: { pathStore in
                    // Pushed on one stack (the outer display), a screen has no bar of its own: back and its "…" are
                    // in the sidebar, and only a bar with something in it (a profile's switcher) stays.
                    TabStackPathView(store: pathStore)
                        .classicSideBar()
                        .toolbarVisibility(.hidden, for: .navigationBar)
                        .environment(\.classicTitleBarIsBare, true)
                        .environment(\.sidebarCarriesColumnMenu, true)
                }
                .id(layout.canShowColumns)
                .barStartsAtCardTop(cardMargins != nil)
                .containerRelativeFrame(.horizontal) { width, _ in
                    layout.showsColumns ? layout.width(ofColumn: 0) : width
                }
                .dimsUnderLeadingEdge(isEnabled: layout.showsColumns)
                .columnCard(isEnabled: cardMargins != nil)
                // Alone on the backdrop, the root casts onto it; opened columns cover this as they slide over.
                .overlay(alignment: .trailing) {
                    if layout.showsColumns { ClassicColumnShadow(edge: .trailing) }
                }
                // On one stack the root holds everything on screen, so it's what shakes.
                .alreadyHereShake(
                    trigger: store.shake.count, isActive: !layout.showsColumns || store.shake.column == nil
                )
                .staysUnderNextColumn(isEnabled: layout.showsColumns)

                if layout.showsColumns {
                    ForEach(Array(store.path.ids.enumerated()), id: \.element) { index, id in
                        if let columnStore = store.scope(state: \.path[id: id], action: \.path[id: id]) {
                            StackedColumn(
                                store: columnStore,
                                isFrontmost: index == store.path.count - 1,
                                compose: { store.send(.composeButtonTapped) }
                            )
                            .barStartsAtCardTop(cardMargins != nil)
                            .frame(width: layout.width(ofColumn: index + 1))
                            .background { ColumnPaper() }
                            .dimsUnderLeadingEdge(isEnabled: true)
                            .columnCard(isEnabled: cardMargins != nil)
                            // Outside the card, onto the column it lies on.
                            .background(alignment: .leading) { ClassicColumnShadow(edge: .leading) }
                            // Pulled down by its bar, it goes, and every column after it follows: the whole card,
                            // corners, bar and shadow, so nothing of it stays behind.
                            .pulledDownToClose(column: index, pull: $pull) {
                                popColumns(after: index == 0 ? nil : store.path.ids[index - 1])
                            }
                            .alreadyHereShake(trigger: store.shake.count, isActive: store.shake.column == id)
                            .staysUnderNextColumn(isEnabled: true)
                            .transition(
                                .asymmetric(
                                    insertion: .offset(
                                        x: layout.entranceOffset(ofColumn: index + 1, from: previousLayout)
                                    ),
                                    // Gone at once: every way of closing a column has already moved it off screen
                                    // (sliding the strip back, pulling it down), and a column left in place while it
                                    // faded would hold the root aside as it widens.
                                    removal: .identity
                                )
                            )
                        }
                    }
                }
            }
            // A lone root centred on the backdrop moves aside as the first column comes in.
            .padding(.leading, layout.leadingInset)
            // Cards lie within the window's layout margins: down from the top by as much as the bottom keeps clear,
            // and in from the sides by the system's margin.
            .padding(.top, cardMargins?.top ?? 0)
            // Columns slide in and out; on one stack the navigation stack animates its own pushes.
            .animation(layout.canShowColumns ? ColumnLayout.slide : nil, value: store.path.ids)
        }
        .padding(.leading, cardMargins?.leading ?? 0)
        .padding(.trailing, cardMargins?.trailing ?? 0)
        // Easing in and out as the root is left alone or joined.
        .animation(ColumnLayout.slide, value: store.path.isEmpty)
        .background {
            if layout.canShowColumns { ColumnBackdrop() }

            // Where columns leave the side bar's area uncovered.
            Color.clear.classicSideBar()
        }
        .classicTabBar()
        .onChange(of: store.closeAllColumnsRequests) {
            requestClose(after: nil)
        }
        .onChange(of: store.path.count) {
            shownDepth = store.path.count
        }
        .onChange(of: layout.canShowColumns, initial: true) {
            store.send(.columnAvailabilityChanged(layout.canShowColumns))
        }
        .onGeometryChange(for: ColumnGeometry.self) { proxy in
            ColumnGeometry(proxy: proxy)
        } action: { newValue in
            measuredGeometry = newValue
        }
        .fullScreenCover(item: safari) { page in
            SafariView(url: page.url)
                .ignoresSafeArea()
        }
    }

    /// Where columns are cards on the backdrop: a window regular both ways. Across a fold the two pages still meet at
    /// its middle; only the outer edges and the top step in.
    private var cardMargins: EdgeInsets? {
        guard horizontalSizeClass == .regular, verticalSizeClass == .regular else { return nil }
        let margins = measuredGeometry.margins
        let safeArea = measuredGeometry.safeArea
        let corners = measuredGeometry.corners
        // Sideways by the container's margins; down from the top as far as the bottom keeps clear (the home
        // indicator), or the top itself if that's further (a status bar); and always far enough in that the card's
        // corners clear the display's.
        let leading = ColumnCard.clearance(from: corners.topLeading)
        let trailing = ColumnCard.clearance(from: corners.topTrailing)
        // A root alone on a flat display sits further in, a sheet on the desk rather than across it.
        let sideMargin: CGFloat = store.path.isEmpty && measuredGeometry.fold == nil ? 2 : 1
        return EdgeInsets(
            top: max(safeArea.top + margins.top, safeArea.bottom + margins.bottom, leading, trailing),
            leading: max(margins.leading * sideMargin, leading),
            bottom: 0,
            trailing: max(margins.trailing * sideMargin, trailing)
        )
    }

    /// The strip as measured, at the width it's settling to when the window says so (the sidebar beside it changing
    /// width at the same moment).
    private var geometry: ColumnGeometry {
        var geometry = measuredGeometry
        if let stripWidth, stripWidth > 0 { geometry.width = stripWidth }
        if let cardMargins {
            geometry.width -= cardMargins.leading + cardMargins.trailing
            geometry.fold = geometry.fold.map {
                ($0.lowerBound - cardMargins.leading)...($0.upperBound - cardMargins.leading)
            }
        }
        return geometry
    }

    /// Slides the strip so the columns after `id` are off the trailing edge, then closes them.
    private func requestClose(after id: StackElementID?) {
        let remaining = id.flatMap { store.path.ids.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
        let layout = ColumnLayout(geometry: geometry, wideColumns: store.path.prefix(remaining).map(\.isWide))
        closing = ColumnClosing(after: id, offset: layout.offset)
    }

    private func finishClosing() {
        guard let closing else { return }
        self.closing = nil
        popColumns(after: closing.after)
    }

    /// Closes every column after `id`, or every column after the root when `id` is `nil`.
    private func popColumns(after id: StackElementID?) {
        let ids = store.path.ids
        let firstRemoved = id.flatMap { ids.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
        guard firstRemoved < ids.count else { return }
        store.send(.path(.popFrom(id: ids[firstRemoved])))
    }

    private var path:
        Binding<Store<StackState<TabStackPath.State>, StackAction<TabStackPath.State, TabStackPath.Action>>>
    {
        $store.scope(state: \.path, action: \.path)
    }

    private var rootColumnPath:
        Binding<Store<StackState<TabStackPath.State>, StackAction<TabStackPath.State, TabStackPath.Action>>>
    {
        $store.scope(state: \.rootColumnPath, action: \.rootColumnPath)
    }

    private var safari: Binding<TabStack.SafariPage?> {
        Binding {
            store.safari
        } set: { page in
            if page == nil { store.send(.safariDismissed) }
        }
    }
}

/// The scroll view the columns slide in, and everything that changes while they slide. Its state changes (the throw
/// distance crossed, the scroll position) re-render only this, never the columns it was handed.
private struct ColumnStrip<Content: View>: View {
    let layout: ColumnLayout
    let geometry: ColumnGeometry
    let newestColumn: StackElementID?
    let closing: ColumnClosing?
    let finishClosing: () -> Void
    let throwAway: () -> Void
    @ViewBuilder let content: Content

    /// Positioned by offset only: positions by view or edge are kept by the scroll view as content changes, which
    /// would snap a new column into place instead of letting it slide in.
    @State private var position = ScrollPosition()
    /// Whether the strip is pulled far enough past its start that letting go throws the opened columns away.
    @State private var isPastThrowDistance = false

    var body: some View {
        ScrollView(.horizontal) {
            content
        }
        .scrollPosition($position)
        // Columns pulled past either end go on under the sidebar beside the strip rather than being cut off at it.
        .scrollClipDisabled()
        .defaultScrollAnchor(layout.showsColumns ? .trailing : nil, for: .initialOffset)
        // A lone stack spans the whole width and keeps its content clear of the side bar and camera itself; insetting
        // the strip too would apply the side bar's inset twice. Columns are laid out within the safe area, so there
        // the strip keeps to it: reaching under the side bar, it would hand its inset to every column inside it, and
        // could never scroll the newest column fully into view.
        .ignoresSafeArea(.container, edges: layout.showsColumns ? [] : .horizontal)
        .scrollTargetBehavior(ColumnSnapping(stops: layout.snapOffsets))
        .scrollIndicators(.hidden)
        .scrollDisabled(!layout.isScrollable)
        .scrollBounceBehavior(.always, axes: .horizontal)
        // Reports only the crossing, so dragging the strip never re-renders the columns.
        .onScrollGeometryChange(for: Bool.self) { scroll in
            -(scroll.contentOffset.x + scroll.contentInsets.leading) > ColumnLayout.throwDistance
        } action: { _, isPast in
            isPastThrowDistance = isPast
        }
        .onScrollPhaseChange { oldPhase, newPhase in
            if oldPhase == .interacting, newPhase != .interacting, isPastThrowDistance {
                throwAway()
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isPastThrowDistance) { _, isPast in isPast }
        // The scroll view would otherwise keep its trailing edge pinned as a column is added, putting the new column
        // in place at once; leaving the offset alone lets the slide below bring it in.
        .transaction(value: newestColumn) { $0.scrollContentOffsetAdjustmentBehavior = .disabled }
        // A newly opened column slides in at the trailing edge; closing them slides back.
        .onChange(of: newestColumn) {
            // With the last column gone the root is laid out alone at once, at the start of the strip; sliding there
            // would show it still scrolled aside.
            guard newestColumn != nil else {
                // Easing back from wherever the root was left (pulled past the start, say) as it settles into place.
                withAnimation(ColumnLayout.slide) { position.scrollTo(x: 0) }
                return
            }
            withAnimation(ColumnLayout.slide) { position.scrollTo(x: layout.offset) }
        }
        // Folding, unfolding and turning keep the newest column at the trailing edge, without animating; the strip
        // narrowing or widening with the sidebar slides with it. Only what lays the columns out counts: the margins
        // and corners measured alongside don't move them.
        .onChange(of: ColumnStripMetrics(width: geometry.width, fold: geometry.fold)) { old, new in
            if old.fold == new.fold {
                withAnimation(ColumnLayout.slide) { position.scrollTo(x: layout.offset) }
            } else {
                position.scrollTo(x: layout.offset)
            }
        }
        .onChange(of: closing) {
            guard let closing else { return }
            withAnimation(ColumnLayout.slide) {
                position.scrollTo(x: closing.offset)
            } completion: {
                finishClosing()
            }
        }
    }
}

/// Snaps the strip to column edges, in the direction it was flicked: Twitter for iPad's
/// `bestOffsetForPossibleOffsets:inDirection:`.
struct ColumnSnapping: ScrollTargetBehavior {
    /// Below this the strip was let go rather than flicked, and settles on the nearest stop.
    static let flickVelocity: CGFloat = 50

    var stops: [CGFloat]

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard !stops.isEmpty else { return }
        target.rect.origin.x = Self.bestStop(in: stops, for: target.rect.minX, velocity: context.velocity.dx)
    }

    /// The stop to settle on, given where the scroll would come to rest (`proposed`) and how fast it was going. A flick
    /// always settles at or beyond where it would have come to rest, so it never springs back against the finger.
    static func bestStop(in stops: [CGFloat], for proposed: CGFloat, velocity: CGFloat) -> CGFloat {
        guard let first = stops.first, let last = stops.last else { return proposed }
        if velocity > flickVelocity {
            return stops.first { $0 >= proposed - 0.5 } ?? last
        }
        if velocity < -flickVelocity {
            return stops.last { $0 <= proposed + 0.5 } ?? first
        }
        return stops.min { abs($0 - proposed) < abs($1 - proposed) } ?? proposed
    }
}

/// Closing the columns after `after` (`nil` is the root): the strip scrolls to `offset`, then they're removed.
private struct ColumnClosing: Equatable {
    var after: StackElementID?
    var offset: CGFloat
}

private struct AlreadyHereShake: ViewModifier {
    let isActive: Bool
    let trigger: Int

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { content, offset in
                content.offset(x: isActive ? offset : 0)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-5, duration: 0.08)
                    CubicKeyframe(3, duration: 0.08)
                    SpringKeyframe(0, duration: 0.15)
                }
            }
            .sensoryFeedback(.warning, trigger: trigger) { _, _ in isActive }
    }
}

/// A column pulled down by its bar, and how far.
private struct ColumnPull: Equatable {
    var column: Int
    var offset: CGFloat
}

/// Pulls a column down by its bar to close it, and every column after it: the pulled column follows the finger and
/// each after it trails a little behind, so it's plain they're going together. Let go far enough (or flicked) they drop
/// off the bottom. Only a drag that starts in the bar and heads down counts, so it never competes with scrolling or
/// pull to refresh, and it runs alongside the bar's buttons rather than in place of them.
private struct PullDownToClose: ViewModifier {
    /// The bar, and the status bar above it on a display that has one there.
    static let barHeight: CGFloat = 110
    static let closingDistance: CGFloat = 160
    /// How far behind the column before it each following column trails.
    static let followingLag: CGFloat = 40

    let column: Int
    @Binding var pull: ColumnPull?
    let close: () -> Void
    @State private var isTracking = false

    func body(content: Content) -> some View {
        let lag = pull.map { column - $0.column } ?? -1
        content
            // Each column after the pulled one follows it, a little further behind the further along it is.
            .offset(y: lag >= 0 ? max((pull?.offset ?? 0) - CGFloat(lag) * Self.followingLag, 0) : 0)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        if !isTracking {
                            guard pull == nil, value.startLocation.y < Self.barHeight,
                                value.translation.height > abs(value.translation.width)
                            else { return }
                            isTracking = true
                        }
                        pull = ColumnPull(column: column, offset: max(value.translation.height, 0))
                    }
                    .onEnded { value in
                        guard isTracking else { return }
                        isTracking = false
                        if value.translation.height > Self.closingDistance
                            || value.predictedEndTranslation.height > 2 * Self.closingDistance
                        {
                            withAnimation(.snappy(duration: 0.25)) {
                                pull?.offset = 1_500
                            } completion: {
                                close()
                                pull = nil
                            }
                        } else {
                            withAnimation(.snappy) {
                                pull?.offset = 0
                            } completion: {
                                pull = nil
                            }
                        }
                    }
            )
    }
}

/// Shows a column as a card on the backdrop: sharp rounded top corners where the strip's margins have set it down,
/// and open at the bottom, where the column runs on under the home indicator.
private struct ColumnCard: ViewModifier {
    static let cornerRadius: CGFloat = 4

    let isEnabled: Bool

    func body(content: Content) -> some View {
        let radius = isEnabled ? Self.cornerRadius : 0
        content.mask {
            UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    /// How far in from both edges a card's corner sits so a container corner reaching `corner` in doesn't clip it:
    /// the card's small arc lies inside the container's larger one along the diagonal.
    static func clearance(from corner: CGSize) -> CGFloat {
        let containerRadius = min(corner.width, corner.height)
        return (max(containerRadius - cornerRadius, 0) * (1 - 1 / 2.squareRoot())).rounded(.up)
    }
}

/// A column's sheet of paper: opaque.
private struct ColumnPaper: View {
    var body: some View {
        Rectangle()
            .fill(.background)
            // Up under the bars, but never sideways into the side bar.
            .ignoresSafeArea(edges: .vertical)
    }
}

/// One opened thing as its own column, with its own bar. Columns don't push within themselves: opening something
/// adds a column after this one instead.
private struct StackedColumn: View {
    let store: StoreOf<TabStackPath>
    let isFrontmost: Bool
    let compose: () -> Void
    @Environment(\.hasClassicSidebar) private var hasClassicSidebar

    var body: some View {
        NavigationStack {
            TabStackPathView(store: store)
                .environment(\.isFrontmostColumn, isFrontmost)
                // See the root column: laid out clear of the side bar, but handed its inset anyway.
                .ignoresSafeArea(.container, edges: .horizontal)
                .toolbar {
                    if !hasClassicSidebar, isFrontmost {
                        ComposeToolbarItem(compose: compose)
                    }
                }
        }
    }
}

/// Compose, on the frontmost column of a window without a sidebar (a post or profile in a window of its own): in
/// iPhone Duo's side bar where there is one, never in the column's own bar.
private struct ComposeToolbarItem: ToolbarContent {
    let compose: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            Button(action: compose) {
                ClassicGlyphLabel("New Post", glyph: .compose)
            }
            .buttonStyle(.classicCompose(isExpanded: false))
        }
        .visibilityPriority(.high)
        .axisBehavior(.verticalPreferred)
        .sharedBackgroundVisibility(.hidden)
    }
}

extension View {
    /// The space UIKit leaves above a navigation bar in a view with no top safe area (iOS 27).
    fileprivate static var navigationBarTopSpacing: CGFloat { 24 }
    /// A card's bar: the system's items, 30pt tall and 9pt below the bar's top, with as much again below them.
    fileprivate static var cardBarHeight: CGFloat { 48 }

    /// Twitter's gentle "no": a short shake when asked to open what's already showing.
    fileprivate func alreadyHereShake(trigger: Int, isActive: Bool) -> some View {
        modifier(AlreadyHereShake(isActive: isActive, trigger: trigger))
    }

    /// Darkens a column by how far it has slid under the leading edge, from where it's drawn: no state, no layout, and
    /// a plain black layer fading rather than a filter over the column's content.
    fileprivate func pulledDownToClose(
        column: Int, pull: Binding<ColumnPull?>, close: @escaping () -> Void
    ) -> some View {
        modifier(PullDownToClose(column: column, pull: pull, close: close))
    }

    /// Lifts a card's navigation stack by the spacing UIKit leaves above a navigation bar whose view has no top safe
    /// area, so the bar starts at the card's top edge (the card's mask hides the band above it), and ends its bar just
    /// below the system's items. UIKit
    /// decides both the bar's height and that spacing itself, and nothing public moves either.
    fileprivate func barStartsAtCardTop(_ isEnabled: Bool) -> some View {
        padding(.top, isEnabled ? -Self.navigationBarTopSpacing : 0)
            // Content starts below the card's own, shorter bar rather than the system's.
            .environment(\.classicBarContentTop, isEnabled ? Self.navigationBarTopSpacing + Self.cardBarHeight : nil)
    }

    /// Twitter for iPad's columns as cards on the backdrop: dropped a little from the top, with rounded top corners.
    fileprivate func columnCard(isEnabled: Bool) -> some View {
        modifier(ColumnCard(isEnabled: isEnabled))
    }

    /// Keeps a column where it lies once the strip has slid it to the leading edge, so the column after it slides over
    /// it like a card dealt onto another, rather than pushing it away. Drawn from the column's own position, like the
    /// dimming: no state and no layout.
    fileprivate func staysUnderNextColumn(isEnabled: Bool) -> some View {
        visualEffect { content, proxy in
            let minX = proxy.frame(in: .scrollView(axis: .horizontal)).minX
            return content.offset(x: isEnabled ? max(-minX, 0) : 0)
        }
    }

    fileprivate func dimsUnderLeadingEdge(isEnabled: Bool) -> some View {
        overlay {
            if isEnabled {
                Rectangle()
                    .fill(.black)
                    .visualEffect { content, proxy in
                        let frame = proxy.frame(in: .scrollView(axis: .horizontal))
                        let covered = frame.width > 0 ? min(max(-frame.minX / frame.width, 0), 1) : 0
                        return content.opacity(0.32 * covered)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .ignoresSafeArea(edges: .vertical)
            }
        }
    }
}

struct ColumnGeometry: Equatable {
    /// The fold's horizontal extent in this view's coordinates, when an active fold runs vertically through it.
    var fold: ClosedRange<CGFloat>?
    /// The system's margins for content in this container (`ContentMarginGuide.container`), which lie inside its safe
    /// area, and the safe area itself.
    var margins = EdgeInsets()
    var safeArea = EdgeInsets()
    /// How far the container's own rounded corners reach in (the display's, where this meets them).
    var corners = RectangleCornerInsets()
    var width: CGFloat = 0

    init() {}

    init(proxy: GeometryProxy) {
        width = proxy.size.width
        margins = proxy.contentMargins(for: .container)
        safeArea = proxy.safeAreaInsets
        corners = proxy.containerCornerInsets
        let division = proxy.reservedRegions(kind: .division)
            .first { $0.frame.height > $0.frame.width }
        if let division, division.frame.minX > 0, division.frame.maxX < width {
            fold = division.frame.minX...division.frame.maxX
        }
    }
}

/// Where each column of the stack goes. Column 0 is the root; column `n` is the `n`th thing opened.
struct ColumnLayout: Equatable {
    /// How far past its start the strip is pulled before letting go throws the opened columns away (Twitter for iPad).
    static let throwDistance: CGFloat = 120
    /// Columns sliding in, out, and back to where they rest: quick, and settling without a bounce.
    static let slide: Animation = .snappy(duration: 0.28)
    /// Twitter for iPad's column: two fill iPhone Duo's inner display in landscape, and one leaves a readable sliver
    /// of the previous column in portrait.
    static let preferredColumnWidth: CGFloat = 476
    /// Below this a column is too cramped to read a thread in.
    static let minimumColumnWidth: CGFloat = 400
    /// How much of the column under a web panel Twitter for iPad left showing.
    static let webPanelPeek: CGFloat = 194

    /// Whether the display is wide enough for columns, whether or not anything is open.
    var canShowColumns = false
    /// Width of every column while columns are shown, but a wide web panel.
    var columnWidth: CGFloat = 0
    /// Whether the stack is laid out as columns, as opposed to everything on the root's own navigation stack, or one
    /// root spanning a display too small to leave room beside it. Where there's room the root is a column even alone,
    /// Twitter for iPad's sheet of paper on the backdrop: centred on a flat display, the left page across a fold.
    var showsColumns = false
    /// How far the root sits from the leading edge while it's alone: centred on a flat display.
    var leadingInset: CGFloat = 0
    /// Whether the strip slides between columns.
    var isScrollable = false
    /// Across a fold the strip only comes to rest with a column on each side of it, the way a book lies open.
    private var isFolded = false

    /// On a flat display, with backdrop around them, columns are cards: across a fold they're pages, edge to edge.
    var showsCards: Bool { showsColumns && !isFolded }
    /// How far the strip of columns is shifted left so the newest one ends at the trailing edge.
    var offset: CGFloat = 0
    /// The width of the root and of each opened column, while columns are shown.
    private var widths: [CGFloat] = []
    private var containerWidth: CGFloat = 0

    init(geometry: ColumnGeometry, depth: Int) {
        self.init(geometry: geometry, wideColumns: Array(repeating: false, count: depth))
    }

    /// - Parameter wideColumns: For each opened column, whether it's a wide web panel.
    init(geometry: ColumnGeometry, wideColumns: [Bool]) {
        let width = geometry.width
        containerWidth = width
        canShowColumns = width > 0 && (geometry.fold != nil || width >= Self.minimumColumnWidth + 160)
        // Alone on a display with no room for a second column beside it (the outer display), the root spans it.
        guard canShowColumns, geometry.fold != nil || !wideColumns.isEmpty || width >= 2 * Self.minimumColumnWidth
        else { return }
        showsColumns = true
        isScrollable = true
        if let fold = geometry.fold {
            isFolded = true
            // Like a book lying open: the newest column is the page right of the fold and the one before it the page
            // left of it, meeting at the fold's middle with nothing between them. Any before those are off the leading
            // edge until they're closed.
            columnWidth = ((fold.lowerBound + fold.upperBound) / 2).rounded()
            widths =
                wideColumns.isEmpty
                ? [columnWidth]
                : Array(repeating: columnWidth, count: wideColumns.count) + [width - columnWidth]
            offset = max(minX(ofColumn: widths.count - 1) + widths[widths.count - 1] - width, 0)
            return
        }
        let rootWidth: CGFloat
        if width >= 2 * Self.minimumColumnWidth {
            columnWidth = (width / 2).rounded(.down)
            rootWidth = columnWidth
        } else {
            // Room for one column at a time: the root keeps the whole width, and what opens slides over it.
            columnWidth = min(Self.preferredColumnWidth, width)
            rootWidth = width
        }
        let wideWidth = max(columnWidth, width - Self.webPanelPeek)
        widths = [rootWidth] + wideColumns.map { $0 ? wideWidth : columnWidth }
        let stripWidth = widths.reduce(0, +)
        offset = max(stripWidth - width, 0)
        if wideColumns.isEmpty {
            leadingInset = ((width - columnWidth) / 2).rounded(.down)
        }
    }

    func width(ofColumn column: Int) -> CGFloat {
        widths.indices.contains(column) ? widths[column] : columnWidth
    }

    /// Where a column starts in the strip.
    func minX(ofColumn column: Int) -> CGFloat {
        widths.prefix(column).reduce(0, +)
    }

    /// Where the strip can come to rest: with any column's leading edge at the leading edge of the display, or its
    /// trailing edge at the trailing edge.
    var snapOffsets: [CGFloat] {
        guard showsColumns else { return [] }
        if isFolded {
            // Each pair of neighbours open across the fold.
            return Set(widths.indices.map { min(minX(ofColumn: $0), offset).rounded() }).sorted()
        }
        let edges = widths.indices.flatMap { column in
            let minX = minX(ofColumn: column)
            return [minX, minX + width(ofColumn: column) - containerWidth]
        }
        let stops = Set(edges.map { min(max($0, 0), offset).rounded() })
        return stops.sorted()
    }

    /// Whether a column starts left of the visible area: it's showing only as a dimmed sliver.
    func isCovered(column: Int) -> Bool {
        showsColumns && minX(ofColumn: column) < offset - 0.5
    }

    /// How far right of its place a newly added column starts, so it comes in from the trailing edge while the strip
    /// slides from where it was (`previous`) to where it ends up.
    func entranceOffset(ofColumn column: Int, from previous: ColumnLayout) -> CGFloat {
        let startX = minX(ofColumn: column) - previous.offset
        return max(containerWidth - startX, 0)
    }
}

private struct TabRootView: View {
    let store: StoreOf<TabStack>
    let title: LocalizedStringKey
    let isFrontmost: Bool
    @Environment(\.hasClassicSidebar) private var hasClassicSidebar

    var body: some View {
        TabRootContentView(store: store.scope(state: \.root, action: \.root))
            .navigationTitle(title)
            .toolbar {
                // A window's sidebar has its own; otherwise the frontmost column carries it.
                if !hasClassicSidebar, isFrontmost {
                    ComposeToolbarItem { store.send(.composeButtonTapped) }
                }
            }
    }
}

private struct TabRootContentView: View {
    let store: StoreOf<TabRoot>

    var body: some View {
        switch store.case {
        case .feeds(let store):
            FeedsView(store: store)
                .navigationBarTitleDisplayMode(.inline)
        case .profile(let store):
            ProfileView(store: store)
        case .quotes(let store):
            FeedView(store: store)
                .navigationTitle("Quotes")
                .navigationBarTitleDisplayMode(.inline)
                .classicTitleBar()
        case .search(let store):
            SearchView(store: store)
                .classicTitleBar()
        case .thread(let store):
            ThreadView(store: store)
                .navigationBarTitleDisplayMode(.inline)
                .classicTitleBar()
        case .userList(let store):
            UserListView(store: store)
                .classicTitleBar()
        case .web(let store):
            WebPanelView(store: store)
                .classicTitleBar()
        }
    }
}

private struct TabStackPathView: View {
    let store: StoreOf<TabStackPath>

    var body: some View {
        switch store.case {
        case .profile(let store):
            ProfileView(store: store)
        case .quotes(let store):
            FeedView(store: store)
                .navigationTitle("Quotes")
                .navigationBarTitleDisplayMode(.inline)
                .classicTitleBar()
        case .search(let store):
            SearchView(store: store)
                .classicTitleBar()
        case .thread(let store):
            ThreadView(store: store)
                .navigationTitle("Post")
                .navigationBarTitleDisplayMode(.inline)
                .classicTitleBar()
        case .userList(let store):
            UserListView(store: store)
                .classicTitleBar()
        case .web(let store):
            WebPanelView(store: store)
                .classicTitleBar()
        }
    }
}

/// Back, for a sidebar to carry where everything is pushed onto one stack (the outer display): iPhone Duo puts the
/// stack's own back button in its side bar, which the sidebar stands in for. Swiping back works as ever.
package struct SidebarBackButton: View {
    let store: StoreOf<TabStack>

    package init(store: StoreOf<TabStack>) {
        self.store = store
    }

    package var body: some View {
        if !store.canShowColumns, let id = store.path.ids.last {
            Button("Back", systemImage: "chevron.backward") {
                store.send(.path(.popFrom(id: id)))
            }
            .buttonStyle(.classicBar(isOnSideBar: true))

            if let columnStore = store.scope(state: \.path[id: id], action: \.path[id: id]) {
                SidebarColumnMenu(store: columnStore)
            }
        }
    }
}

/// The "…" of a screen pushed on one stack, carried by the sidebar since the screen has no bar.
private struct SidebarColumnMenu: View {
    let store: StoreOf<TabStackPath>

    var body: some View {
        switch store.case {
        case .profile(let store):
            if store.hasMenu {
                ClassicColumnMenu("Account", isOnSideBar: true) {
                    ProfileMenuItems(store: store)
                }
            }
        case .thread(let store):
            if store.focusedTweet != nil {
                ClassicColumnMenu("More", isOnSideBar: true) {
                    ThreadMenuItems(store: store)
                }
            }
        case .web(let store):
            ClassicColumnMenu("Share", glyph: .action, isOnSideBar: true) {
                WebPanelMenuItems(store: store)
            }
        case .quotes, .search, .userList:
            EmptyView()
        }
    }
}

extension EnvironmentValues {
    /// The width the column strip is settling to, when its window knows it before the strip can measure it.
    @Entry package var columnStripWidth: CGFloat? = nil
}

/// What the strip's column layout depends on.
private struct ColumnStripMetrics: Equatable {
    var width: CGFloat
    var fold: ClosedRange<CGFloat>?
}
