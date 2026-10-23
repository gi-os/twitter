import ComposableArchitecture
import ComposeFeature
import Models
import Routing
import SwiftUI
import TabStackFeature
import TwitterClient

package struct MainView: View {
    @Bindable var store: StoreOf<MainFeature>

    package init(store: StoreOf<MainFeature>) {
        self.store = store
    }

    package var body: some View {
        TabView(selection: $store.selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                TabStackView(store: store.scope(state: \.home, action: \.home), title: "Home")
            }
            Tab("Notifications", systemImage: "bell", value: .notifications) {
                TabStackView(
                    store: store.scope(state: \.notifications, action: \.notifications), title: "Notifications")
            }
            Tab("Bookmarks", systemImage: "bookmark", value: .bookmarks) {
                TabStackView(store: store.scope(state: \.bookmarks, action: \.bookmarks), title: "Bookmarks")
            }
            Tab("Profile", systemImage: "person", value: .profile) {
                TabStackView(store: store.scope(state: \.profile, action: \.profile), title: "Profile")
            }
            Tab("Explore", systemImage: "magnifyingglass", value: .explore, role: .search) {
                TabStackView(store: store.scope(state: \.explore, action: \.explore), title: "Explore")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(item: $store.scope(state: \.compose, action: \.compose)) { composeStore in
            ComposeView(store: composeStore)
        }
    }
}
