import ComposableArchitecture
import FeedFeature
import Models
import Routing
import SwiftUI
import TwitterClient
import TwitterUI

package struct ProfileView: View {
    let store: StoreOf<ProfileFeature>

    package init(store: StoreOf<ProfileFeature>) {
        self.store = store
    }

    package var body: some View {
        Group {
            if let feedsStore = store.scope(state: \.feeds, action: \.feeds), let user = store.user {
                FeedsView(store: feedsStore) {
                    ProfileHeader(user: user, isViewer: store.isViewer) {
                        store.send(.followButtonTapped)
                    }
                }
            } else if let errorMessage = store.errorMessage {
                ContentUnavailableView {
                    Label("Couldn't load @\(store.screenName)", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try Again") { store.send(.task) }
                        .buttonStyle(.glass)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(store.user?.name ?? "@\(store.screenName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.isViewer {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Account", systemImage: "person.crop.circle") {
                        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            store.send(.signOutButtonTapped)
                        }
                    }
                }
            }
        }
        .task { store.send(.task) }
    }
}

private struct ProfileHeader: View {
    let user: User
    let isViewer: Bool
    let followButtonTapped: () -> Void
    @ScaledMetric private var avatarSize: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                Banner(url: user.bannerURL)
                Avatar(user: user, size: avatarSize)
                    .overlay {
                        Circle().strokeBorder(.background, lineWidth: 4)
                    }
                    .padding(.leading, 16)
                    .offset(y: avatarSize / 2)
            }
            .padding(.bottom, avatarSize / 2)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(user.name).font(.title2.bold())
                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.tint)
                                .accessibilityLabel("Verified")
                        }
                    }
                    HStack(spacing: 6) {
                        Text(verbatim: "@\(user.screenName)").foregroundStyle(.secondary)
                        if user.followsYou {
                            Text("Follows you")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: .capsule)
                        }
                    }
                }
                Spacer()
                if !isViewer {
                    FollowButton(isFollowing: user.isFollowing, action: followButtonTapped)
                }
            }
            .padding(.horizontal, 16)

            if !user.bio.isEmpty {
                Text(user.bio)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ProfileDetails(user: user)
                .padding(.horizontal, 16)

            HStack(spacing: 16) {
                Text("**\(user.followingCount.compact)** Following")
                Text("**\(user.followersCount.compact)** Followers")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}

private struct Banner: View {
    let url: URL?
    @ScaledMetric private var height: CGFloat = 140

    var body: some View {
        Rectangle()
            .fill(.tint.opacity(0.25))
            .overlay {
                if let url {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .frame(height: height)
            .clipped()
            .accessibilityHidden(true)
    }
}

private struct FollowButton: View {
    let isFollowing: Bool
    let action: () -> Void

    var body: some View {
        Button(isFollowing ? "Following" : "Follow", action: action)
            .buttonStyle(.glassProminent)
            .tint(isFollowing ? .secondary : .accentColor)
            .sensoryFeedback(.success, trigger: isFollowing)
    }
}

private struct ProfileDetails: View {
    let user: User

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { ProfileDetailItems(user: user) }
            VStack(alignment: .leading, spacing: 4) { ProfileDetailItems(user: user) }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

}

private struct ProfileDetailItems: View {
    let user: User

    var body: some View {
        if !user.location.isEmpty {
            Label(user.location, systemImage: "mappin.and.ellipse")
        }
        if let website = user.website, let url = user.websiteURL {
            Link(destination: url) {
                Label(website, systemImage: "link")
            }
        }
        if let joined = user.joined {
            Label("Joined \(joined.formatted(.dateTime.month(.wide).year()))", systemImage: "calendar")
        }
    }
}
