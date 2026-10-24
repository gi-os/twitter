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

    package init(store: StoreOf<MainFeature>) {
        self.store = store
    }

    package var body: some View {
        TabView(selection: $store.selectedTab) {
            Tab(value: .home) {
                TabStackView(store: store.scope(state: \.home, action: \.home), title: "Home")
            } label: {
                TabLabel("Home", icon: .homeStroke, selectedIcon: .home, isSelected: store.selectedTab == .home)
            }
            Tab(value: .notifications) {
                TabStackView(
                    store: store.scope(state: \.notifications, action: \.notifications), title: "Notifications")
            } label: {
                TabLabel(
                    "Notifications",
                    icon: .notificationsStroke,
                    selectedIcon: .notifications,
                    isSelected: store.selectedTab == .notifications
                )
            }
            Tab(value: .bookmarks) {
                TabStackView(store: store.scope(state: \.bookmarks, action: \.bookmarks), title: "Bookmarks")
            } label: {
                TabLabel(
                    "Bookmarks", icon: .bookmarkStroke, selectedIcon: .bookmark,
                    isSelected: store.selectedTab == .bookmarks)
            }
            Tab(value: .profile) {
                TabStackView(store: store.scope(state: \.profile, action: \.profile), title: "Profile")
            } label: {
                TabLabel(
                    "Profile", icon: .personStroke, selectedIcon: .person, isSelected: store.selectedTab == .profile)
            }
            Tab(value: .explore, role: .search) {
                TabStackView(store: store.scope(state: \.explore, action: \.explore), title: "Explore")
            } label: {
                TabLabel(
                    "Explore", icon: .searchStroke, selectedIcon: .search, isSelected: store.selectedTab == .explore)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
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
}

/// A tab in Twitter's own glyphs: outlined, and filled when selected (SF Symbols do this on their own; these can't).
private struct TabLabel: View {
    let icon: TwitterIcon
    let isSelected: Bool
    let selectedIcon: TwitterIcon
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey, icon: TwitterIcon, selectedIcon: TwitterIcon, isSelected: Bool) {
        self.icon = icon
        self.isSelected = isSelected
        self.selectedIcon = selectedIcon
        self.title = title
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            (isSelected ? selectedIcon : icon).image
        }
    }
}

#if DEBUG
    extension MainView {
        /// `--tab <home|notifications|bookmarks|profile|explore>` and `--open-thread` put the app on a given screen at
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
        }
    }
#endif
