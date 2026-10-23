import ComposableArchitecture
import Models
import Routing
import SwiftUI
import TweetEngagement
import TwitterClient
import TwitterUI

package struct FeedView<Header: View, PinnedHeader: View>: View {
    let store: StoreOf<FeedFeature>
    @ViewBuilder let header: Header
    @ViewBuilder let pinnedHeader: PinnedHeader

    package init(
        store: StoreOf<FeedFeature>,
        @ViewBuilder header: () -> Header,
        @ViewBuilder pinnedHeader: () -> PinnedHeader
    ) {
        self.store = store
        self.header = header()
        self.pinnedHeader = pinnedHeader()
    }

    package var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                header
                Section {
                    ForEach(store.items) { item in
                        FeedItemRow(
                            item: item,
                            engagement: item.tweets.first.map { store.engagements.engagement(for: $0) },
                            isFocused: store.source == .thread(tweetID: item.tweets.first?.id ?? ""),
                            store: store
                        )
                        .onAppear { store.send(.rowAppeared(item.id)) }
                        Divider()
                    }
                    FeedFooter(store: store)
                } header: {
                    pinnedHeader
                }
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .swipeActionsContainer()
        .refreshable { await store.send(.refreshPulled).finish() }
        .task { store.send(.task) }
        .environment(
            \.openURL,
            OpenURLAction { url in
                store.send(.linkTapped(url))
                return .handled
            })
    }
}

extension FeedView where Header == EmptyView, PinnedHeader == EmptyView {
    package init(store: StoreOf<FeedFeature>) {
        self.store = store
        header = EmptyView()
        pinnedHeader = EmptyView()
    }
}

private struct FeedItemRow: View {
    let item: FeedItem
    let engagement: Engagement?
    let isFocused: Bool
    let store: StoreOf<FeedFeature>

    var body: some View {
        switch item {
        case .notification(let notification):
            NotificationRow(notification: notification, store: store)
        case .tweet(let feedTweet):
            TweetRow(
                item: feedTweet,
                engagement: engagement ?? Engagement(tweet: feedTweet.tweet),
                store: store,
                isFocused: isFocused
            )
        }
    }
}

private struct FeedFooter: View {
    let store: StoreOf<FeedFeature>

    var body: some View {
        Group {
            if let errorMessage = store.errorMessage {
                ContentUnavailableView {
                    Label("Couldn't load posts", systemImage: "exclamationmark.bubble")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try Again") { store.send(.retryButtonTapped) }
                        .buttonStyle(.glass)
                }
            } else if store.isLoading {
                ProgressView()
                    .padding(.vertical, 32)
            } else if store.hasLoaded, store.items.isEmpty {
                ContentUnavailableView("Nothing here yet", systemImage: "bird")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

package struct FeedsView<Header: View>: View {
    @Bindable var store: StoreOf<FeedsFeature>
    @ViewBuilder let header: Header

    package init(store: StoreOf<FeedsFeature>, @ViewBuilder header: () -> Header) {
        self.store = store
        self.header = header()
    }

    package var body: some View {
        if let feedStore = store.scope(state: \.feeds[id: store.selection], action: \.feeds[id: store.selection]) {
            FeedView(store: feedStore) {
                header
            } pinnedHeader: {
                if store.feeds.count > 1 {
                    Picker("Feed", selection: $store.selection) {
                        ForEach(store.feeds) { feed in
                            Text(feed.source.title).tag(feed.source)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.bar)
                }
            }
            .id(store.selection)
        }
    }
}

extension FeedsView where Header == EmptyView {
    package init(store: StoreOf<FeedsFeature>) {
        self.store = store
        header = EmptyView()
    }
}
