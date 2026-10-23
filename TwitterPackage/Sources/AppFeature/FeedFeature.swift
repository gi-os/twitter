import ComposableArchitecture
import Foundation
import XAPI

@Reducer
struct FeedFeature {
  @ObservableState
  struct State: Equatable, Identifiable {
    var bottomCursor: String?
    var errorMessage: String?
    var hasLoaded = false
    var isLoading = false
    var items: IdentifiedArrayOf<FeedItem> = []
    let source: FeedSource

    var id: FeedSource { source }

    init(source: FeedSource, items: IdentifiedArrayOf<FeedItem> = []) {
      self.source = source
      self.items = items
    }
  }

  enum Action {
    case authorTapped(XUser)
    case bookmarkButtonTapped(XTweet)
    case delegate(ContentDelegate)
    case interactionFailed(Interaction, tweetID: String)
    case likeButtonTapped(XTweet)
    case linkTapped(URL)
    case pageResponse(Result<FeedPage, any Error>, isRefresh: Bool)
    case quoteButtonTapped(XTweet)
    case refreshPulled
    case replyButtonTapped(XTweet)
    case repostButtonTapped(XTweet)
    case retryButtonTapped
    case rowAppeared(FeedItem.ID)
    case task
    case tweetTapped(XTweet)
  }

  enum Interaction: Equatable {
    case bookmark
    case like
    case repost
  }

  enum CancelID: Hashable {
    case page(FeedSource)
  }

  @Dependency(XClient.self) var client
  @Dependency(\.openURL) var openURL

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .authorTapped(let user):
        return .send(.delegate(.open(.profile(user))))

      case .bookmarkButtonTapped(let tweet):
        return toggle(.bookmark, tweet: tweet, state: &state)

      case .delegate:
        return .none

      case .interactionFailed(let interaction, let tweetID):
        state.items.modifyTweets(id: tweetID) { $0.toggle(interaction) }
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

  private func toggle(_ interaction: Interaction, tweet: XTweet, state: inout State) -> EffectOf<Self> {
    let current = state.items.lazy.flatMap(\.tweets).first { $0.id == tweet.id } ?? tweet
    state.items.modifyTweets(id: tweet.id) { $0.toggle(interaction) }
    return .run { _ in
      switch interaction {
      case .bookmark:
        try await client.setBookmarked(!current.isBookmarked, tweet.id)
      case .like:
        try await client.setLiked(!current.isLiked, tweet.id)
      case .repost:
        try await client.setReposted(!current.isRetweeted, tweet.id)
      }
    } catch: { _, send in
      await send(.interactionFailed(interaction, tweetID: tweet.id))
    }
  }
}

extension FeedItem {
  var tweets: [XTweet] {
    switch self {
    case .notification(let notification):
      notification.tweet.map { [$0] } ?? []
    case .tweet(let feedTweet):
      [feedTweet.tweet] + feedTweet.tweet.quoted
    }
  }
}

extension IdentifiedArrayOf<FeedItem> {
  mutating func modifyTweets(id: String, _ transform: (inout XTweet) -> Void) {
    for itemID in ids {
      self[id: itemID]?.modifyTweets(id: id, transform)
    }
  }
}

extension FeedItem {
  mutating func modifyTweets(id: String, _ transform: (inout XTweet) -> Void) {
    switch self {
    case .notification(var notification):
      guard notification.tweet?.id == id else { return }
      transform(&notification.tweet!)
      self = .notification(notification)
    case .tweet(var feedTweet):
      var didChange = false
      if feedTweet.tweet.id == id {
        transform(&feedTweet.tweet)
        didChange = true
      }
      for index in feedTweet.tweet.quoted.indices where feedTweet.tweet.quoted[index].id == id {
        transform(&feedTweet.tweet.quoted[index])
        didChange = true
      }
      if didChange { self = .tweet(feedTweet) }
    }
  }
}

extension XTweet {
  mutating func toggle(_ interaction: FeedFeature.Interaction) {
    switch interaction {
    case .bookmark:
      isBookmarked.toggle()
      bookmarkCount += isBookmarked ? 1 : -1
    case .like:
      isLiked.toggle()
      likeCount += isLiked ? 1 : -1
    case .repost:
      isRetweeted.toggle()
      retweetCount += isRetweeted ? 1 : -1
    }
  }
}
