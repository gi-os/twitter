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

    @State private var geometry = ColumnGeometry()
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
                    TabRootView(store: store, title: title)
                        .environment(\.isFrontmostColumn, store.path.isEmpty || !layout.showsColumns)
                        // A lone stack reaches under the side bar; painting it here keeps the fill beneath the bar's
                        // own buttons.
                        .classicSideBar()
                        // The strip's scroll view reaches under the side bar whatever its frame, and hands that inset
                        // to every column inside it, wherever the column is. Columns are laid out clear of the side
                        // bar already; a lone stack spans the strip and keeps clear of it.
                        .ignoresSafeArea(.container, edges: layout.showsColumns ? .horizontal : [])
                } destination: { pathStore in
                    TabStackPathView(store: pathStore)
                        .classicSideBar()
                }
                .id(layout.canShowColumns)
                .containerRelativeFrame(.horizontal) { width, _ in
                    layout.showsColumns ? layout.width(ofColumn: 0) : width
                }
                // The root reflows once, at its new width, rather than on every frame of the new column sliding in.
                .transaction(value: layout.showsColumns) { $0.animation = nil }
                .dimsUnderLeadingEdge(isEnabled: layout.showsColumns)
                .columnCard(isEnabled: layout.showsCards)
                // Alone on the backdrop, the root casts onto it; opened columns cover this as they slide over.
                .overlay(alignment: .trailing) {
                    if layout.showsColumns { ClassicColumnShadow(edge: .trailing) }
                }
                // On one stack the root holds everything on screen, so it's what shakes.
                .alreadyHereShake(
                    trigger: store.shake.count, isActive: !layout.showsColumns || store.shake.column == nil
                )

                if layout.showsColumns {
                    ForEach(Array(store.path.ids.enumerated()), id: \.element) { index, id in
                        if let columnStore = store.scope(state: \.path[id: id], action: \.path[id: id]) {
                            StackedColumn(store: columnStore, isFrontmost: index == store.path.count - 1) {
                                requestClose(after: index == 0 ? nil : store.path.ids[index - 1])
                            }
                            .frame(width: layout.width(ofColumn: index + 1))
                            .background { ColumnPaper() }
                            .dimsUnderLeadingEdge(isEnabled: true)
                            .columnCard(isEnabled: layout.showsCards)
                            // Outside the card, onto the column it lies on.
                            .background(alignment: .leading) { ClassicColumnShadow(edge: .leading) }
                            .alreadyHereShake(trigger: store.shake.count, isActive: store.shake.column == id)
                            .transition(
                                .asymmetric(
                                    insertion: .offset(
                                        x: layout.entranceOffset(ofColumn: index + 1, from: previousLayout)
                                    ),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                )
                            )
                        }
                    }
                }
            }
            // A lone root centred on the backdrop moves aside as the first column comes in.
            .padding(.leading, layout.leadingInset)
            // Columns slide in and out; on one stack the navigation stack animates its own pushes.
            .animation(layout.canShowColumns ? ColumnLayout.slide : nil, value: store.path.ids)
        }
        .background {
            if layout.canShowColumns { ColumnBackdrop() }

            // Where columns leave the side bar's area uncovered.
            Color.clear.classicSideBar()
        }
        .classicTabBar()
        .onChange(of: store.path.count) {
            shownDepth = store.path.count
        }
        .onChange(of: layout.canShowColumns, initial: true) {
            store.send(.columnAvailabilityChanged(layout.canShowColumns))
        }
        .onGeometryChange(for: ColumnGeometry.self) { proxy in
            ColumnGeometry(proxy: proxy)
        } action: { newValue in
            geometry = newValue
        }
        .fullScreenCover(item: safari) { page in
            SafariView(url: page.url)
                .ignoresSafeArea()
        }
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
            withAnimation(ColumnLayout.slide) { position.scrollTo(x: layout.offset) }
        }
        // Folding, unfolding and turning keep the newest column at the trailing edge, without animating.
        .onChange(of: geometry) {
            position.scrollTo(x: layout.offset)
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
    let close: () -> Void

    var body: some View {
        NavigationStack {
            TabStackPathView(store: store)
                .environment(\.isFrontmostColumn, isFrontmost)
                // See the root column: laid out clear of the side bar, but handed its inset anyway.
                .ignoresSafeArea(.container, edges: .horizontal)
                .toolbar {
                    if isFrontmost {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", systemImage: "xmark", action: close)
                                .buttonStyle(.classicBar(isOnSideBar: false))
                        }
                        .sharedBackgroundVisibility(.hidden)
                    }
                }
        }
    }
}

extension View {
    /// Twitter's gentle "no": a short shake when asked to open what's already showing.
    fileprivate func alreadyHereShake(trigger: Int, isActive: Bool) -> some View {
        modifier(AlreadyHereShake(isActive: isActive, trigger: trigger))
    }

    /// Darkens a column by how far it has slid under the leading edge, from where it's drawn: no state, no layout, and
    /// a plain black layer fading rather than a filter over the column's content.
    /// Twitter for iPad's columns as cards on the backdrop: dropped a little from the top, with rounded top corners.
    fileprivate func columnCard(isEnabled: Bool) -> some View {
        let radius: CGFloat = isEnabled ? 8 : 0
        return clipShape(UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius))
            .padding(.top, isEnabled ? 10 : 0)
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
    var width: CGFloat = 0

    init() {}

    init(proxy: GeometryProxy) {
        width = proxy.size.width
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
        if width >= 2 * Self.minimumColumnWidth {
            columnWidth = (width / 2).rounded(.down)
        } else {
            columnWidth = min(Self.preferredColumnWidth, width)
        }
        let wideWidth = max(columnWidth, width - Self.webPanelPeek)
        widths = [columnWidth] + wideColumns.map { $0 ? wideWidth : columnWidth }
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
    @Environment(\.hasClassicSidebar) private var hasClassicSidebar

    var body: some View {
        TabRootContentView(store: store.scope(state: \.root, action: \.root))
            .navigationTitle(title)
            .toolbar {
                // A window's sidebar has its own.
                if !hasClassicSidebar {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            store.send(.composeButtonTapped)
                        } label: {
                            ClassicGlyphLabel("New Post", glyph: .compose)
                        }
                        .buttonStyle(.classicBar(isOnSideBar: true))
                    }
                    .visibilityPriority(.high)
                    // In iPhone Duo's side bar where there is one, with the tabs.
                    .axisBehavior(.verticalPreferred)
                    // A bare glyph, as 4.x's were, rather than a glass disc.
                    .sharedBackgroundVisibility(.hidden)
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

/// The frontmost column's "…" menu, for a sidebar to carry: the newest column's, or the root's when nothing is open.
package struct FrontmostColumnMenu: View {
    let store: StoreOf<TabStack>

    package init(store: StoreOf<TabStack>) {
        self.store = store
    }

    package var body: some View {
        if let id = store.path.ids.last, let columnStore = store.scope(state: \.path[id: id], action: \.path[id: id]) {
            switch columnStore.case {
            case .profile(let store):
                ProfileColumnMenu(store: store)
            case .thread(let store):
                ThreadColumnMenu(store: store)
            case .web(let store):
                ClassicColumnMenu("Share", glyph: .action, isOnSideBar: true) {
                    WebPanelMenuItems(store: store)
                }
            case .quotes, .search, .userList:
                EmptyView()
            }
        } else {
            switch store.scope(state: \.root, action: \.root).case {
            case .profile(let store):
                ProfileColumnMenu(store: store)
            case .thread(let store):
                ThreadColumnMenu(store: store)
            case .web(let store):
                ClassicColumnMenu("Share", glyph: .action, isOnSideBar: true) {
                    WebPanelMenuItems(store: store)
                }
            case .feeds, .quotes, .search, .userList:
                EmptyView()
            }
        }
    }
}

private struct ProfileColumnMenu: View {
    let store: StoreOf<ProfileFeature>

    var body: some View {
        if store.hasMenu {
            ClassicColumnMenu("Account", isOnSideBar: true) {
                ProfileMenuItems(store: store)
            }
        }
    }
}

private struct ThreadColumnMenu: View {
    let store: StoreOf<FeedFeature>

    var body: some View {
        if store.focusedTweet != nil {
            ClassicColumnMenu("More", isOnSideBar: true) {
                ThreadMenuItems(store: store)
            }
        }
    }
}
