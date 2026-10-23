import ComposableArchitecture
import FeedFeature
import Models
import ProfileFeature
import Routing
import SearchFeature
import SwiftUI

package struct TabStackView: View {
    @Bindable var store: StoreOf<TabStack>
    let title: LocalizedStringKey

    package init(store: StoreOf<TabStack>, title: LocalizedStringKey) {
        self.store = store
        self.title = title
    }
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    package var body: some View {
        if horizontalSizeClass == .regular {
            HStack(spacing: 0) {
                NavigationStack {
                    TabRootView(store: store, title: title)
                }
                .containerRelativeFrame(.horizontal) { width, _ in
                    min(max(width * 0.42, 320), 460)
                }
                Divider()
                    .ignoresSafeArea()
                NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                    ContentUnavailableView("No Post Selected", systemImage: "text.bubble")
                } destination: { pathStore in
                    TabStackPathView(store: pathStore)
                }
                .id(store.path.ids.first)
            }
        } else {
            NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                TabRootView(store: store, title: title)
            } destination: { pathStore in
                TabStackPathView(store: pathStore)
            }
        }
    }
}

private struct TabRootView: View {
    let store: StoreOf<TabStack>
    let title: LocalizedStringKey

    var body: some View {
        TabRootContentView(store: store.scope(state: \.root, action: \.root))
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarPinnedTrailing) {
                    Button("New Post", systemImage: "square.and.pencil") {
                        store.send(.composeButtonTapped)
                    }
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
        case .search(let store):
            SearchView(store: store)
        }
    }
}

private struct TabStackPathView: View {
    let store: StoreOf<TabStackPath>

    var body: some View {
        switch store.case {
        case .profile(let store):
            ProfileView(store: store)
        case .search(let store):
            SearchView(store: store)
        case .thread(let store):
            FeedView(store: store)
                .navigationTitle("Post")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
