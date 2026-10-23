import ComposableArchitecture
import Foundation
import Models
import Routing
import TweetEngagement
import TwitterClient
import TwitterUI

@Reducer
package struct FeedFeature {
    @ObservableState
    package struct State: Equatable, Identifiable {
        var bottomCursor: String?
        @Shared(.engagements) var engagements
        var errorMessage: String?
        var hasLoaded = false
        var isLoading = false
        var items: IdentifiedArrayOf<FeedItem> = []
        let source: FeedSource

        package var id: FeedSource { source }

        package init(source: FeedSource, items: IdentifiedArrayOf<FeedItem> = []) {
            self.source = source
            self.items = items
        }
    }

    package enum Action {
        case authorTapped(User)
        case bookmarkButtonTapped(Tweet)
        case delegate(ContentDelegate)
        case likeButtonTapped(Tweet)
        case linkTapped(URL)
        case pageResponse(Result<FeedPage, any Error>, isRefresh: Bool)
        case quoteButtonTapped(Tweet)
        case refreshPulled
        case replyButtonTapped(Tweet)
        case repostButtonTapped(Tweet)
        case retryButtonTapped
        case rowAppeared(FeedItem.ID)
        case task
        case tweetTapped(Tweet)
    }

    enum CancelID: Hashable {
        case page(FeedSource)
    }

    @Dependency(TwitterClient.self) var client
    @Dependency(TweetEngagementSync.self) var engagementSync
    @Dependency(\.openURL) var openURL

    package init() {}

    package var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .authorTapped(let user):
                return .send(.delegate(.open(.profile(user))))

            case .bookmarkButtonTapped(let tweet):
                return toggle(.bookmark, tweet: tweet, state: &state)

            case .delegate:
                return .none

            case .likeButtonTapped(let tweet):
                return toggle(.like, tweet: tweet, state: &state)

            case .linkTapped(let url):
                if let route = Route(url: url) {
                    return .send(.delegate(.open(route)))
                }
                return .run { _ in await openURL(url) }

            case .pageResponse(.success(let page), let isRefresh):
                state.isLoading = false
                state.hasLoaded = true
                state.errorMessage = nil
                if isRefresh {
                    state.items = IdentifiedArray(page.items, uniquingIDsWith: { first, _ in first })
                } else {
                    for item in page.items where state.items[id: item.id] == nil {
                        state.items.append(item)
                    }
                }
                state.bottomCursor = page.items.isEmpty ? nil : page.bottomCursor
                state.$engagements.withLock { $0.refresh(from: page.items.lazy.flatMap(\.tweets)) }
                return .none

            case .pageResponse(.failure(let error), _):
                state.isLoading = false
                state.hasLoaded = true
                state.errorMessage = error.localizedDescription
                return .none

            case .quoteButtonTapped(let tweet):
                return .send(.delegate(.compose(Draft(quoting: tweet))))

            case .refreshPulled:
                return loadPage(state: &state, isRefresh: true)

            case .replyButtonTapped(let tweet):
                return .send(.delegate(.compose(Draft(replyingTo: tweet))))

            case .repostButtonTapped(let tweet):
                return toggle(.repost, tweet: tweet, state: &state)

            case .retryButtonTapped:
                return loadPage(state: &state, isRefresh: state.items.isEmpty)

            case .rowAppeared(let id):
                guard
                    let index = state.items.index(id: id),
                    index >= state.items.count - 5,
                    state.bottomCursor != nil,
                    !state.isLoading,
                    state.errorMessage == nil
                else { return .none }
                return loadPage(state: &state, isRefresh: false)

            case .task:
                guard !state.hasLoaded, !state.isLoading else { return .none }
                return loadPage(state: &state, isRefresh: true)

            case .tweetTapped(let tweet):
                guard state.source != .thread(tweetID: tweet.id) else { return .none }
                return .send(.delegate(.open(.thread(tweet))))
            }
        }
    }

    private func loadPage(state: inout State, isRefresh: Bool) -> EffectOf<Self> {
        state.isLoading = true
        state.errorMessage = nil
        let source = state.source
        let cursor = isRefresh ? nil : state.bottomCursor
        return .run { send in
            await send(
                .pageResponse(Result { try await client.feed(source, cursor) }, isRefresh: isRefresh)
            )
        }
        .cancellable(id: CancelID.page(source), cancelInFlight: true)
    }

    private func toggle(_ interaction: Interaction, tweet: Tweet, state: inout State) -> EffectOf<Self> {
        state.$engagements.withLock { $0.toggle(interaction, for: tweet) }
        return .run { _ in await engagementSync.sync(tweet.id, interaction) }
    }
}

extension FeedItem {
    package var tweets: [Tweet] {
        switch self {
        case .notification(let notification):
            notification.tweet.map { [$0] } ?? []
        case .tweet(let feedTweet):
            [feedTweet.tweet] + feedTweet.tweet.quoted
        }
    }
}
