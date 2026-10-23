import ComposableArchitecture
import Models
import Routing
import SwiftUI
import TweetEngagement
import TwitterClient
import TwitterUI

package struct TweetRow: View {
    let item: FeedTweet
    let engagement: Engagement
    let store: StoreOf<FeedFeature>
    var isFocused = false

    private var tweet: Tweet { item.tweet }

    package var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let reposter = item.repostedBy {
                ContextLabel(symbol: "arrow.2.squarepath", text: "\(reposter.name) reposted")
            } else if let context = item.socialContext {
                ContextLabel(symbol: item.socialSymbol ?? "sparkles", text: context)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 4) {
                    Button {
                        store.send(.authorTapped(tweet.author))
                    } label: {
                        Avatar(user: tweet.author, size: 44)
                    }
                    .buttonStyle(.plain)
                    if item.connectsBelow {
                        Capsule()
                            .fill(.quaternary)
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    AuthorLine(user: tweet.author, date: tweet.createdAt)
                    if !tweet.replyingTo.isEmpty, !item.connectsAbove {
                        Text("Replying to \(tweet.replyingTo.map { "@\($0)" }.formatted(.list(type: .and)))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !tweet.text.isEmpty {
                        TweetText(links: tweet.links, text: tweet.text, font: isFocused ? .title3 : .body)
                    }
                    if !tweet.media.isEmpty {
                        MediaGrid(media: tweet.media)
                    }
                    if let card = tweet.card, tweet.media.isEmpty {
                        LinkCardView(card: card)
                    }
                    if let quoted = tweet.quoted.first {
                        QuoteCard(tweet: quoted) { store.send(.tweetTapped(quoted)) }
                    }
                    EngagementBar(tweet: tweet, engagement: engagement, store: store)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, item.connectsAbove ? 4 : 12)
        .padding(.bottom, item.connectsBelow ? 0 : 4)
        .contentShape(.rect)
        .onTapGesture { store.send(.tweetTapped(tweet)) }
        .swipeActions(edge: .leading) {
            Button {
                store.send(.likeButtonTapped(tweet))
            } label: {
                Label(
                    engagement.like.isOn ? "Unlike" : "Like",
                    systemImage: engagement.like.isOn ? "heart.fill" : "heart")
            }
            .tint(.pink)
        }
        .swipeActions(edge: .trailing) {
            Button {
                store.send(.replyButtonTapped(tweet))
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
            .tint(.accentColor)
            Button {
                store.send(.bookmarkButtonTapped(tweet))
            } label: {
                Label(engagement.bookmark.isOn ? "Remove Bookmark" : "Bookmark", systemImage: "bookmark")
            }
            .tint(.orange)
        }
        .contextMenu {
            TweetMenu(tweet: tweet, engagement: engagement, store: store)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Open Post") { store.send(.tweetTapped(tweet)) }
    }
}

private struct ContextLabel: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 44, alignment: .trailing)
            Text(text).lineLimit(1)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}

package struct EngagementBar: View {
    let tweet: Tweet
    let engagement: Engagement
    let store: StoreOf<FeedFeature>

    package var body: some View {
        HStack {
            EngagementButton(
                action: { store.send(.replyButtonTapped(tweet)) },
                count: tweet.replyCount,
                label: "Reply",
                symbol: "bubble.left"
            )
            Spacer(minLength: 0)
            Menu {
                Button {
                    store.send(.repostButtonTapped(tweet))
                } label: {
                    Label(engagement.repost.isOn ? "Undo Repost" : "Repost", systemImage: "arrow.2.squarepath")
                }
                Button {
                    store.send(.quoteButtonTapped(tweet))
                } label: {
                    Label("Quote", systemImage: "quote.bubble")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.2.squarepath")
                        .frame(minWidth: 24, minHeight: 32)
                    if engagement.repost.count > 0 {
                        Text(engagement.repost.count.compact).monospacedDigit()
                    }
                }
                .font(.footnote)
                .foregroundStyle(engagement.repost.isOn ? Color.green : .secondary)
            }
            .accessibilityLabel("Repost")
            Spacer(minLength: 0)
            LikeButton(isLiked: engagement.like.isOn, count: engagement.like.count) {
                store.send(.likeButtonTapped(tweet))
            }
            Spacer(minLength: 0)
            if let views = tweet.viewCount {
                Label(views.compact, systemImage: "chart.bar")
                    .labelStyle(.titleAndIcon)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(views) views")
                Spacer(minLength: 0)
            }
            EngagementButton(
                action: { store.send(.bookmarkButtonTapped(tweet)) },
                activeSymbol: "bookmark.fill",
                isActive: engagement.bookmark.isOn,
                label: engagement.bookmark.isOn ? "Remove Bookmark" : "Bookmark",
                symbol: "bookmark"
            )
            ShareLink(item: tweet.url) {
                Image(systemName: "square.and.arrow.up")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 24, minHeight: 32)
            }
            .buttonStyle(.plain)
        }
    }
}

package struct TweetMenu: View {
    let tweet: Tweet
    let engagement: Engagement
    let store: StoreOf<FeedFeature>

    package var body: some View {
        Button {
            store.send(.replyButtonTapped(tweet))
        } label: {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }
        Button {
            store.send(.repostButtonTapped(tweet))
        } label: {
            Label(engagement.repost.isOn ? "Undo Repost" : "Repost", systemImage: "arrow.2.squarepath")
        }
        Button {
            store.send(.quoteButtonTapped(tweet))
        } label: {
            Label("Quote", systemImage: "quote.bubble")
        }
        Button {
            store.send(.authorTapped(tweet.author))
        } label: {
            Label("View @\(tweet.author.screenName)", systemImage: "person")
        }
        Divider()
        ShareLink(item: tweet.url)
        Button {
            UIPasteboard.general.url = tweet.url
        } label: {
            Label("Copy Link", systemImage: "link")
        }
    }
}

package struct NotificationRow: View {
    let notification: TwitterNotification
    let store: StoreOf<FeedFeature>

    package var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NotificationIcon(icon: notification.icon)
                .frame(width: 44, alignment: .trailing)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: -8) {
                    ForEach(notification.users.prefix(8)) { user in
                        Button {
                            store.send(.authorTapped(user))
                        } label: {
                            Avatar(user: user, size: 32)
                                .overlay { Circle().strokeBorder(.background, lineWidth: 2) }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(notification.attributedMessage)
                    .font(.subheadline)
                if let tweet = notification.tweet, !tweet.text.isEmpty {
                    Text(tweet.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(.rect)
        .onTapGesture {
            if let tweet = notification.tweet {
                store.send(.tweetTapped(tweet))
            } else if let user = notification.users.first {
                store.send(.authorTapped(user))
            }
        }
    }
}

extension TwitterNotification {
    package var attributedMessage: AttributedString {
        var result = AttributedString(message)
        let scalars = Array(message.unicodeScalars)
        for range in boldRanges where range.lowerBound >= 0 && range.upperBound <= scalars.count {
            let prefix = String(String.UnicodeScalarView(scalars[..<range.lowerBound]))
            let token = String(String.UnicodeScalarView(scalars[range]))
            guard
                let start = result.characters.index(
                    result.startIndex, offsetBy: prefix.count, limitedBy: result.endIndex
                ),
                let end = result.characters.index(start, offsetBy: token.count, limitedBy: result.endIndex)
            else { continue }
            result[start..<end].inlinePresentationIntent = .stronglyEmphasized
        }
        return result
    }
}

private struct NotificationIcon: View {
    let icon: String

    var body: some View {
        let style = NotificationIconStyle(icon: icon)
        Image(systemName: style.symbol)
            .font(.title2)
            .foregroundStyle(style.color)
            .accessibilityHidden(true)
    }
}

private struct NotificationIconStyle {
    let color: Color
    let symbol: String

    init(icon: String) {
        switch icon {
        case let icon where icon.contains("heart"):
            (symbol, color) = ("heart.fill", .pink)
        case let icon where icon.contains("retweet"):
            (symbol, color) = ("arrow.2.squarepath", .green)
        case let icon where icon.contains("person") || icon.contains("follow"):
            (symbol, color) = ("person.fill", .accentColor)
        case let icon where icon.contains("bell"):
            (symbol, color) = ("bell.fill", .accentColor)
        case let icon where icon.contains("star") || icon.contains("bird"):
            (symbol, color) = ("star.fill", .purple)
        case let icon where icon.contains("security") || icon.contains("safety"):
            (symbol, color) = ("lock.shield.fill", .orange)
        case let icon where icon.contains("live") || icon.contains("space"):
            (symbol, color) = ("waveform", .purple)
        case let icon where icon.contains("milestone") || icon.contains("trending"):
            (symbol, color) = ("chart.line.uptrend.xyaxis", .accentColor)
        default:
            (symbol, color) = ("sparkles", .accentColor)
        }
    }
}
