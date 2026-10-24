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
    #if DEBUG
        @Environment(\.openWindow) private var openWindow
    #endif

    package init(store: StoreOf<MainFeature>) {
        self.store = store
    }

    package var body: some View {
        TabView(selection: $store.selectedTab) {
            Tab(value: .home) {
                TabStackView(store: store.scope(state: \.home, action: \.home), title: "Home")
            } label: {
                TabLabel("Home", icon: .home, isSelected: store.selectedTab == .home)
            }
            Tab(value: .notifications) {
                TabStackView(
                    store: store.scope(state: \.notifications, action: \.notifications), title: "Notifications")
            } label: {
                TabLabel("Notifications", icon: .at, isSelected: store.selectedTab == .notifications)
            }
            Tab(value: .bookmarks) {
                TabStackView(store: store.scope(state: \.bookmarks, action: \.bookmarks), title: "Bookmarks")
            } label: {
                TabLabel("Bookmarks", icon: .bookmark, isSelected: store.selectedTab == .bookmarks)
            }
            Tab(value: .profile) {
                TabStackView(store: store.scope(state: \.profile, action: \.profile), title: "Profile")
            } label: {
                TabLabel("Profile", icon: .profile, isSelected: store.selectedTab == .profile)
            }
            Tab(value: .explore, role: .search) {
                TabStackView(store: store.scope(state: \.explore, action: \.explore), title: "Explore")
            } label: {
                TabLabel("Explore", icon: .hash, isSelected: store.selectedTab == .explore)
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
