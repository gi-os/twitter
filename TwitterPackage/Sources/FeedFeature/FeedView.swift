import ComposableArchitecture
import Models
import Routing
import SwiftUI
import TweetEngagement
import TwitterClient
import TwitterUI

package struct FeedView<Header: View>: View {
    let store: StoreOf<FeedFeature>
    @ViewBuilder let header: Header

    package init(store: StoreOf<FeedFeature>, @ViewBuilder header: () -> Header) {
        self.store = store
        self.header = header()
    }

    /// Bound by item, so posts arriving above never move what's on screen.
    @State private var position = ScrollPosition(idType: FeedItem.ID.self)

    package var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                header
                if case .userMedia = store.source {
                    FeedMediaGrid(store: store)
                } else {
                    FeedRows(store: store)
                }
                FeedFooter(store: store)
            }
            .scrollTargetLayout()
            .readableContentWidth()
        }
        .scrollPosition($position, anchor: .top)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y <= -geometry.contentInsets.top + 8
        } action: { _, isAtTop in
            store.send(.isAtTopChanged(isAtTop))
        }
        .onScrollPhaseChange { _, phase in
            guard phase == .idle, let id = position.viewID(type: FeedItem.ID.self) else { return }
            store.send(.scrollStopped(topItemID: id))
        }
        .onChange(of: store.restoringTopItemID, initial: true) {
            guard let topItemID = store.restoringTopItemID else { return }
            position.scrollTo(id: topItemID, anchor: .top)
            store.send(.topItemRestored)
        }
        .overlay(alignment: .bottom) {
            if store.newPostCount > 0 {
                NewPostsButton(count: store.newPostCount) {
                    withAnimation(.snappy) { position.scrollTo(edge: .top) }
                    store.send(.newPostsButtonTapped)
                }
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: store.newPostCount > 0)
        .feedInteractions(store: store)
    }
}

/// Newer posts waiting above where the reader is: said quietly, never by moving them.
private struct NewPostsButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(count == 1 ? "1 new post" : "\(count) new posts", systemImage: "arrow.up")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 6)
        }
        .buttonStyle(.glassProminent)
        .sensoryFeedback(.increase, trigger: count)
    }
}

extension FeedView where Header == EmptyView {
    package init(store: StoreOf<FeedFeature>) {
        self.store = store
        header = EmptyView()
    }
}

/// One view per element (the divider lives inside the row) so the lazy stack's identity stays one-to-one with items.
struct FeedRows: View {
    let store: StoreOf<FeedFeature>

    var body: some View {
        ForEach(store.items) { item in
            FeedItemRow(
                item: item,
                engagement: item.tweets.first.map { store.engagements.engagement(for: $0) },
                isFocused: item.id == store.focusedItemID,
                store: store
            )
            .onAppear { store.send(.rowAppeared(item.id)) }
        }
    }
}

private struct FeedItemRow: View {
    let item: FeedItem
    let engagement: Engagement?
    let isFocused: Bool
    let store: StoreOf<FeedFeature>
    @Environment(\.threadMeasurements) private var threadMeasurements

    var body: some View {
        VStack(spacing: 0) {
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
            case .tombstone(let tombstone):
                TombstoneView(tombstone: tombstone)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            case .showMore(let cursor):
                ShowMoreRow(
                    cursor: cursor,
                    isLoading: store.loadingShowMoreIDs.contains(item.id)
                ) {
                    store.send(.showMoreButtonTapped(cursor))
                }
            }
            TwitterDivider()
        }
        .onGeometryChange(for: CGFloat?.self) { proxy in
            isFocused ? proxy.frame(in: .named(ThreadView.coordinateSpace)).minY : nil
        } action: { minY in
            // Keeps the last value once the lazy stack releases the row.
            if let minY { threadMeasurements?.focusedMinY = minY }
        }
    }
}

/// A tappable "Show more replies" row that loads the rest of a conversation in its place.
private struct ShowMoreRow: View {
    let cursor: ShowMoreCursor
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                }
                Text(cursor.label)
                    .letterpress()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background { GapGroove() }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

extension View {
    /// Caps line length for reading while letting the scroll view (and its indicators) span the column, and sizes the
    /// rows' text and metrics for the width they get.
    func readableContentWidth() -> some View {
        // Greedy inside the cap, so the width the metrics measure is the width offered, never one the metrics sized.
        frame(maxWidth: .infinity).frame(maxWidth: 680).tweetMetrics().frame(maxWidth: .infinity)
    }

    func feedInteractions(store: StoreOf<FeedFeature>) -> some View {
        modifier(FeedInteractions(store: store))
    }
}

private struct FeedInteractions: ViewModifier {
    /// About how far the system's refresh control is pulled before it triggers.
    private static let refreshTriggerDistance: CGFloat = 80

    let store: StoreOf<FeedFeature>
    /// The pull catching, releasing, then the timeline landing: Twitter for iPad's "psst", "psst" and "pop", each
    /// with a haptic.
    @State private var isPastRefreshTrigger = false
    @State private var refreshesFinished = 0
    @State private var refreshesStarted = 0

    func body(content: Content) -> some View {
        content
            .refreshable {
                refreshesStarted += 1
                ClassicSound.psst2.play()
                await store.send(.refreshPulled).finish()
                refreshesFinished += 1
                ClassicSound.pop.play()
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y < -(geometry.contentInsets.top + Self.refreshTriggerDistance)
            } action: { _, isPast in
                if isPast, !isPastRefreshTrigger { ClassicSound.psst1.play() }
                isPastRefreshTrigger = isPast
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isPastRefreshTrigger) { _, isPast in isPast }
            .sensoryFeedback(.selection, trigger: refreshesStarted)
            .sensoryFeedback(.success, trigger: refreshesFinished)
            .task { store.send(.task) }
            .environment(
                \.openURL,
                OpenURLAction { url in
                    store.send(.linkTapped(url))
                    return .handled
                })
    }
}

struct FeedFooter: View {
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
            } else if store.hasLoaded, store.bottomCursor == nil {
                EndOfTimeline()
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
            }
            .id(store.selection)
            // Part of the chrome rather than the content: a bar under the navigation bar that posts scroll beneath,
            // with no backing of its own. A bar rather than a toolbar item, because toolbar items can't sit in
            // iPhone Duo's vertical side bar and would disappear on the folded display.
            .safeAreaBar(edge: .top) {
                if store.feeds.count > 1 {
                    FeedSwitcher(feeds: store.feeds.map(\.source), selection: $store.selection)
                }
            }
        }
    }
}

/// Which of a screen's feeds is showing: For You and Following, or a profile's Posts, Replies and Media.
private struct FeedSwitcher: View {
    let feeds: [FeedSource]
    @Binding var selection: FeedSource

    var body: some View {
        Picker("Feed", selection: $selection.animation(.snappy)) {
            ForEach(feeds, id: \.self) { feed in
                Text(feed.title).tag(feed)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        // Over the readable column on a wide display instead of stretching across it.
        .frame(maxWidth: 680)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

extension FeedsView where Header == EmptyView {
    package init(store: StoreOf<FeedsFeature>) {
        self.store = store
        header = EmptyView()
    }
}
