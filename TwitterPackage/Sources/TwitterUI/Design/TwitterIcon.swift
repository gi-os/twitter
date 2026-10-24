import SwiftUI

/// Twitter's own action glyphs: 24 × 24 template vectors, tinted by the foreground style. Reply, repost, like and share
/// draw as Twitter 4.x's embossed bitmaps instead, in their own colors (grey, green when reposted, an orange star when
/// liked).
package enum TwitterIcon: String, Sendable {
    case bookmark
    case bookmarkStroke = "bookmark_stroke"
    case heart
    case heartStroke = "heart_stroke"
    case home
    case homeStroke = "home_stroke"
    case notifications
    case notificationsStroke = "notifications_stroke"
    case person
    case personStroke = "person_stroke"
    case replyStroke = "reply_stroke"
    /// Reposted (4.x's only).
    case repost = "retweet"
    case repostStroke = "retweet_stroke"
    case search
    case searchStroke = "search_stroke"
    case shareStroke = "share_stroke"
    case views = "bar_chart"

    package var image: Image {
        if let classicName {
            Image(classicName, bundle: .module).renderingMode(.original)
        } else {
            Image(rawValue, bundle: .module).renderingMode(.template)
        }
    }

    /// The 4.x bitmap drawn in this glyph's place (`ic_action_*_inline_default`), wider than tall.
    var classicName: String? {
        switch self {
        case .heart: "ActionFavoriteOn"
        case .heartStroke: "ActionFavorite"
        case .replyStroke: "ActionReply"
        case .repost: "ActionRetweetOn"
        case .repostStroke: "ActionRetweet"
        case .shareStroke: "ActionShare"
        default: nil
        }
    }
}

/// A glyph drawn at the action bar's size. Twitter's vectors are pressed into the page like 4.x's bitmaps beside them,
/// with a highlight along their lower edge.
package struct TwitterIconView: View {
    let icon: TwitterIcon
    var size: CGFloat?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.engagementIconSize) private var engagementIconSize

    package init(_ icon: TwitterIcon, size: CGFloat? = nil) {
        self.icon = icon
        self.size = size
    }

    package var body: some View {
        let size = size ?? engagementIconSize
        icon.image
            .resizable()
            .scaledToFit()
            // 4.x's bitmaps are 5:4.
            .frame(width: icon.classicName == nil ? size : size * 1.25, height: size)
            .shadow(
                color: icon.classicName == nil && colorScheme == .light ? .white : .clear,
                radius: 0,
                y: 1
            )
            .accessibilityHidden(true)
    }
}

extension EnvironmentValues {
    /// How tall action bar glyphs draw: 18 pt in a timeline, 4.x's full 24 pt in a post's details.
    @Entry package var engagementIconSize: CGFloat = 18
}
