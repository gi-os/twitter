import ComposableArchitecture
import ComposeFeature
import Models
import Routing
import SwiftUI
import TabStackFeature
import TwitterClient
import TwitterUI

package struct MainView: View {
    @Bindable var store: StoreOf<MainFeature>
    /// Per-window, so each main window reopens on the tab it was showing.
    @SceneStorage("selectedTab") private var savedTab = MainFeature.Tab.home
    @State private var sidebarGeometry = SidebarGeometry()
    #if DEBUG
        @Environment(\.openWindow) private var openWindow
    #endif

    package init(store: StoreOf<MainFeature>) {
        self.store = store
    }

    package var body: some View {
        let placement = SidebarPlacement(
            geometry: sidebarGeometry,
            isShowingColumns: !tabStack(store.selectedTab).path.isEmpty
        )
        HStack(spacing: 0) {
            // The tabs underneath, their bar hidden for Twitter for iPad's sidebar.
            TabView(selection: $store.selectedTab) {
                Tab(value: .home) {
                    TabStackView(store: tabStack(.home), title: "Home")
                        .toolbarVisibility(.hidden, for: .tabBar)
                } label: {
                    TabLabel("Home", icon: .home, isSelected: store.selectedTab == .home)
                }

                Tab(value: .notifications) {
                    TabStackView(store: tabStack(.notifications), title: "Notifications")
                        .toolbarVisibility(.hidden, for: .tabBar)
                } label: {
                    TabLabel("Notifications", icon: .at, isSelected: store.selectedTab == .notifications)
                }

                Tab(value: .bookmarks) {
                    TabStackView(store: tabStack(.bookmarks), title: "Bookmarks")
                        .toolbarVisibility(.hidden, for: .tabBar)
                } label: {
                    TabLabel("Bookmarks", icon: .bookmark, isSelected: store.selectedTab == .bookmarks)
                }

                Tab(value: .profile) {
                    TabStackView(store: tabStack(.profile), title: "Profile")
                        .toolbarVisibility(.hidden, for: .tabBar)
                } label: {
                    TabLabel("Profile", icon: .profile, isSelected: store.selectedTab == .profile)
                }

                Tab(value: .explore) {
                    TabStackView(store: tabStack(.explore), title: "Explore")
                        .toolbarVisibility(.hidden, for: .tabBar)
                } label: {
                    TabLabel("Explore", icon: .hash, isSelected: store.selectedTab == .explore)
                }
            }
            .tabViewStyle(.tabBarOnly)
            .environment(\.hasClassicSidebar, true)

            // Room of its own, where the system keeps no side bar (the inner display upright, the outer display).
            if !placement.isInSystemSideBar {
                sidebar(placement)
                    .frame(width: placement.width)
            }
        }
        // Over the side bar iPhone Duo keeps beside the content, where it has one.
        .overlay(alignment: .trailing) {
            if placement.isInSystemSideBar {
                sidebar(placement)
                    .frame(width: placement.width)
                    .ignoresSafeArea()
            }
        }
        .animation(.snappy(duration: 0.28), value: placement)
        .onGeometryChange(for: SidebarGeometry.self) { proxy in
            SidebarGeometry(proxy: proxy)
        } action: { geometry in
            sidebarGeometry = geometry
        }
        .sheet(item: $store.scope(state: \.compose, action: \.compose)) { composeStore in
            ComposeView(store: composeStore)
        }
        .onAppear {
            store.selectedTab = savedTab
            #if DEBUG
                applyLaunchArguments()
            #endif
        }
        .onChange(of: store.selectedTab) { savedTab = store.selectedTab }
    }

    private func sidebar(_ placement: SidebarPlacement) -> some View {
        ClassicSidebar(
            tabs: [
                ClassicSidebarTab("Home", icon: .home, id: MainFeature.Tab.home),
                ClassicSidebarTab("Notifications", icon: .at, id: .notifications),
                ClassicSidebarTab("Bookmarks", icon: .bookmark, id: .bookmarks),
                ClassicSidebarTab("Profile", icon: .profile, id: .profile),
                ClassicSidebarTab("Explore", icon: .hash, id: .explore)
            ],
            selection: $store.selectedTab,
            isExpanded: placement.isExpanded,
            topInset: placement.statusBarHeight,
            compose: { tabStack(store.selectedTab).send(.composeButtonTapped) },
            reselect: { tabStack($0).send(.tabReselected) }
        ) {
            FrontmostColumnMenu(store: tabStack(store.selectedTab))
        }
    }

    private func tabStack(_ tab: MainFeature.Tab) -> StoreOf<TabStack> {
        switch tab {
        case .bookmarks: store.scope(state: \.bookmarks, action: \.bookmarks)
        case .explore: store.scope(state: \.explore, action: \.explore)
        case .home: store.scope(state: \.home, action: \.home)
        case .notifications: store.scope(state: \.notifications, action: \.notifications)
        case .profile: store.scope(state: \.profile, action: \.profile)
        }
    }
}

/// What the sidebar's placement depends on: the window's width, and the side bar iPhone Duo keeps beside the content
/// in some poses (the trailing safe area).
private struct SidebarGeometry: Equatable {
    var systemSideBarWidth: CGFloat = 0
    var width: CGFloat = 0

    init() {}

    init(proxy: GeometryProxy) {
        systemSideBarWidth = proxy.safeAreaInsets.trailing
        width = proxy.size.width
    }
}

/// Where the sidebar goes and how wide it is.
private struct SidebarPlacement: Equatable {
    /// The narrowest column worth reading beside the expanded sidebar.
    static let expandingWidth: CGFloat = 400
    static let collapsedWidth: CGFloat = 72
    static let expandedWidth: CGFloat = 220
    /// The status bar at the top of iPhone Duo's side bar.
    static let systemStatusBarHeight: CGFloat = 150

    var isExpanded = false
    var isInSystemSideBar = false
    var statusBarHeight: CGFloat = 0
    var width: CGFloat = 0

    init(geometry: SidebarGeometry, isShowingColumns: Bool) {
        if geometry.systemSideBarWidth > 0 {
            // Inside the system's side bar, at its width, under its status bar.
            isInSystemSideBar = true
            statusBarHeight = Self.systemStatusBarHeight
            width = geometry.systemSideBarWidth
        } else {
            // Expanded only beside a lone column on a display with room for it (the inner display upright).
            isExpanded = !isShowingColumns && geometry.width >= Self.expandingWidth + Self.expandedWidth
            width = isExpanded ? Self.expandedWidth : Self.collapsedWidth
        }
    }
}

/// A tab in Twitter 4.x's own icons, which draw their selected state themselves (blue, with a glow).
private struct TabLabel: View {
    let icon: ClassicTabIcon
    let isSelected: Bool
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey, icon: ClassicTabIcon, isSelected: Bool) {
        self.icon = icon
        self.isSelected = isSelected
        self.title = title
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            icon.image(isSelected: isSelected)
        }
    }
}

#if DEBUG
    extension MainView {
        /// `--tab <home|notifications|bookmarks|profile|explore>`, `--open-thread`, `--open-web`, `--open-profile` and `--open-window-thread` put the app on a given screen at
        /// launch, for capturing it without tapping there.
        fileprivate func applyLaunchArguments() {
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "--tab"), index + 1 < arguments.count,
                let tab = MainFeature.Tab(rawValue: arguments[index + 1])
            {
                store.selectedTab = tab
            }
            if arguments.contains("--open-thread"), let tweet = Tweet.mocks.first {
                store.send(.home(.root(.feeds(.delegate(.open(.thread(tweet)))))))
            }
            if arguments.contains("--open-web"), let url = URL(string: "https://www.pointfree.co") {
                // Once the stack knows whether it has room for a web panel, rather than Safari's view.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    store.send(.home(.root(.feeds(.delegate(.open(.web(url)))))))
                }
            }
            if arguments.contains("--open-window-thread"), let tweet = Tweet.mocks.first {
                openWindow(value: Route.thread(tweet).window)
            }
            // `--open-profile` (after `--open-thread`) opens a third column from the thread.
            if arguments.contains("--open-profile"), let id = store.home.path.ids.last {
                store.send(.home(.path(.element(id: id, action: .thread(.delegate(.open(.profile(.mock))))))))
            }
            // `--open-followers`, `--open-following`, `--open-reposts`, `--open-likes` and `--open-quotes` open the mock
            // profile's or first mock post's list as a column from the home timeline, or after `--open-thread`'s
            // thread.
            let lists: [(argument: String, route: Route)] = [
                ("--open-followers", .userList(.followers(userID: User.mock.id))),
                ("--open-following", .userList(.following(userID: User.mock.id))),
                ("--open-likes", .userList(.likers(tweetID: Tweet.mocks[0].id))),
                ("--open-quotes", .quotes(tweetID: Tweet.mocks[0].id)),
                ("--open-reposts", .userList(.reposters(tweetID: Tweet.mocks[0].id)))
            ]
            for list in lists where arguments.contains(list.argument) {
                if let id = store.home.path.ids.last, case .thread? = store.home.path[id: id] {
                    store.send(.home(.path(.element(id: id, action: .thread(.delegate(.open(list.route)))))))
                } else {
                    store.send(.home(.root(.feeds(.delegate(.open(list.route))))))
                }
            }
        }
    }
#endif
