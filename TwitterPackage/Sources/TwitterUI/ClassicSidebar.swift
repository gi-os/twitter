import SwiftUI

/// A tab in ``ClassicSidebar``.
package struct ClassicSidebarTab<ID: Hashable>: Identifiable {
    package let icon: ClassicTabIcon
    package let id: ID
    package let title: LocalizedStringKey

    package init(_ title: LocalizedStringKey, icon: ClassicTabIcon, id: ID) {
        self.icon = icon
        self.id = id
        self.title = title
    }
}

/// Twitter for iPad's sidebar, standing in for the system tab bar: charcoal (`iPad-sidebarbg`) down the trailing edge,
/// with compose and the frontmost column's actions at the top and the tabs at the bottom, each in 4.x's own icons on a
/// dark tile when selected. Collapsed it's a strip of icons; expanded, where there's room beside a lone column, each tab
/// has its name beside it.
package struct ClassicSidebar<ID: Hashable, Actions: View>: View {
    /// The window edge it runs down; the content is on the other side.
    let edge: HorizontalEdge
    let isExpanded: Bool
    let tabs: [ClassicSidebarTab<ID>]
    /// Room left at the top for the status bar, where the system keeps it in the side bar.
    let topInset: CGFloat
    /// How far the content's centre line sits from the sidebar's own: in iPhone Duo's side bar, the status bar is
    /// centred a little in from the display's rounded corner, and the sidebar lines up under it.
    let centerOffset: CGFloat
    @Binding var selection: ID
    let compose: () -> Void
    let reselect: (ID) -> Void
    @ViewBuilder let actions: Actions

    package init(
        tabs: [ClassicSidebarTab<ID>],
        selection: Binding<ID>,
        edge: HorizontalEdge = .trailing,
        isExpanded: Bool,
        topInset: CGFloat = 0,
        centerOffset: CGFloat = 0,
        compose: @escaping () -> Void,
        reselect: @escaping (ID) -> Void,
        @ViewBuilder actions: () -> Actions
    ) {
        self.actions = actions()
        self.compose = compose
        self.edge = edge
        self.isExpanded = isExpanded
        self.reselect = reselect
        _selection = selection
        self.tabs = tabs
        self.topInset = topInset
        self.centerOffset = centerOffset
    }

    package var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset)

            // Side by side when expanded, stacked in the strip, a little below the top.
            let layout = isExpanded ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 12))
            layout {
                Button(action: compose) {
                    ClassicGlyphLabel("New Post", glyph: .compose)
                }
                .buttonStyle(ClassicComposeButtonStyle(isExpanded: isExpanded))

                actions
            }
            .padding(.top, 12)

            Spacer(minLength: 16)

            VStack(spacing: 6) {
                ForEach(tabs) { tab in
                    ClassicSidebarTabButton(
                        tab: tab,
                        isExpanded: isExpanded,
                        isSelected: tab.id == selection
                    ) {
                        if tab.id == selection {
                            reselect(tab.id)
                        } else {
                            selection = tab.id
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        // A negative offset moves the content toward the leading edge.
        .padding(.leading, (isExpanded ? 12 : 6) + max(centerOffset, 0) * 2)
        .padding(.trailing, (isExpanded ? 12 : 6) + max(-centerOffset, 0) * 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ClassicSidebarBackground(contentEdge: edge == .trailing ? .leading : .trailing, castsShadow: isExpanded)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Compose, the one action that matters most: the app's blue button (`btn_following`, as Follow is) with the glyph in
/// white, the size of a tab; expanded, it says "New Post" beside the glyph and fills the row.
private struct ClassicComposeButtonStyle: ButtonStyle {
    let isExpanded: Bool

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if isExpanded {
                configuration.label.labelStyle(.titleAndIcon)
            } else {
                configuration.label.labelStyle(.iconOnly)
            }
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.45), radius: 0, y: -1)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .frame(maxWidth: isExpanded ? .infinity : 56, minHeight: 44)
        .background {
            // 11 × 31 pt with rounded ends; the point-wide middle stretches.
            Image("ButtonFollowing", bundle: .module)
                .resizable(capInsets: EdgeInsets(top: 15, leading: 5, bottom: 15, trailing: 5))
        }
        .brightness(configuration.isPressed ? -0.12 : 0)
        .contentShape(.rect)
    }
}

private struct ClassicSidebarTabButton<ID: Hashable>: View {
    let tab: ClassicSidebarTab<ID>
    let isExpanded: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                tab.icon.image(isSelected: isSelected)
                    // 4.x's blue glow pooling under the selected icon.
                    .background(alignment: .bottom) {
                        if isSelected {
                            Image("TabGlow", bundle: .module)
                                .offset(y: 8)
                                .accessibilityHidden(true)
                        }
                    }

                if isExpanded {
                    Text(tab.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isSelected ? Color.white : Color(.glyphEmbossedTop))
                        .shadow(color: .black.opacity(0.8), radius: 0, y: -1)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, isExpanded ? 12 : 0)
            .frame(maxWidth: isExpanded ? .infinity : 56, minHeight: 50)
            .background {
                if isSelected {
                    // `bg_tab_bar_selected`: a dark tile pressed into the bar.
                    Image("TabSelected", bundle: .module)
                        .resizable()
                        .clipShape(.rect(cornerRadius: 6))
                        .shadow(color: .white.opacity(0.08), radius: 0, y: 1)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// `iPad-sidebarbg` with a black edge against the content, casting Twitter for iPad's column shadow onto it when expanded.
private struct ClassicSidebarBackground: View {
    let contentEdge: HorizontalEdge
    /// Expanded, it's a panel lying over the backdrop; collapsed it's the side bar's own strip, casting nothing.
    let castsShadow: Bool

    var body: some View {
        let alignment: Alignment = contentEdge == .leading ? .leading : .trailing
        Image("SidebarBackground", bundle: .module)
            .resizable()
            .overlay(alignment: alignment) {
                Color.black.frame(width: 1)
            }
            .overlay(alignment: alignment) {
                if castsShadow {
                    ClassicColumnShadow(edge: contentEdge)
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

extension EnvironmentValues {
    /// Whether the window has a ``ClassicSidebar``, which carries compose; columns keep their own menus in their bars.
    @Entry package var hasClassicSidebar = false
}

/// A column's "…" menu, in 4.x's bar button: on the side bar for the frontmost column, on its own bar otherwise.
package struct ClassicColumnMenu<Items: View>: View {
    let glyph: ClassicGlyph
    let isOnSideBar: Bool
    let title: LocalizedStringKey
    @ViewBuilder let items: Items

    package init(
        _ title: LocalizedStringKey,
        glyph: ClassicGlyph = .more,
        isOnSideBar: Bool,
        @ViewBuilder items: () -> Items
    ) {
        self.glyph = glyph
        self.isOnSideBar = isOnSideBar
        self.items = items()
        self.title = title
    }

    package var body: some View {
        Menu {
            items
        } label: {
            ClassicGlyphLabel(title, glyph: glyph)
        }
        .menuStyle(.button)
        .buttonStyle(.classicBar(isOnSideBar: isOnSideBar))
    }
}

/// A column's "…" menu: in its own bar in a window with a ``ClassicSidebar``. In a window without one, the frontmost
/// column's menu goes to iPhone Duo's side bar where there is one.
package struct ClassicColumnMenuToolbarItem<Items: View>: ToolbarContent {
    let glyph: ClassicGlyph
    let hasClassicSidebar: Bool
    let isFrontmostColumn: Bool
    let title: LocalizedStringKey
    let items: Items

    package init(
        _ title: LocalizedStringKey,
        glyph: ClassicGlyph = .more,
        isFrontmostColumn: Bool,
        hasClassicSidebar: Bool,
        @ViewBuilder items: () -> Items
    ) {
        self.glyph = glyph
        self.hasClassicSidebar = hasClassicSidebar
        self.isFrontmostColumn = isFrontmostColumn
        self.items = items()
        self.title = title
    }

    package var body: some ToolbarContent {
        if hasClassicSidebar {
            // Always in its own bar: every column carries its own, wherever it is in the stack.
            ToolbarItem(placement: .topBarTrailing) {
                ClassicColumnMenu(title, glyph: glyph, isOnSideBar: false) {
                    items
                }
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .classicSideBar(isFrontmostColumn: isFrontmostColumn)) {
                ClassicColumnMenu(title, glyph: glyph, isOnSideBar: isFrontmostColumn) {
                    items
                }
            }
            .axisBehavior(.verticalPreferred)
            .sharedBackgroundVisibility(.hidden)
        }
    }
}
