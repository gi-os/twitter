import Models
import SwiftUI

package struct QuoteCard: View {
    let tweet: Tweet
    let action: () -> Void

    package init(tweet: Tweet, action: @escaping () -> Void) {
        self.tweet = tweet
        self.action = action
    }

    package var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Avatar(user: tweet.author, size: 20)
                    AuthorLine(user: tweet.author, date: tweet.createdAt)
                }
                if !tweet.text.isEmpty {
                    Text(tweet.text)
                        .font(.subheadline)
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !tweet.media.isEmpty {
                    MediaGrid(media: tweet.media, maxHeight: 180)
                }
            }
            .padding(12)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.quaternary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

package struct LinkCardView: View {
    let card: LinkCard

    package init(card: LinkCard) {
        self.card = card
    }

    package var body: some View {
        Link(destination: card.url) {
            VStack(alignment: .leading, spacing: 0) {
                if let imageURL = card.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(.quaternary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.domain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(card.title)
                        .font(.subheadline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.quaternary)
            }
        }
        .buttonStyle(.plain)
    }
}
