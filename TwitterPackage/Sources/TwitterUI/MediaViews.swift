import AVKit
import Models
import SwiftUI

package struct MediaGrid: View {
    let media: [Media]
    var maxHeight: CGFloat = 320

    package init(media: [Media], maxHeight: CGFloat = 320) {
        self.media = media
        self.maxHeight = maxHeight
    }

    @State private var presentedMedia: PresentedMedia?

    package var body: some View {
        Group {
            if media.count == 1, let item = media.first {
                tile(item, index: 0)
                    .aspectRatio(max(item.aspectRatio, 0.75), contentMode: .fit)
                    .frame(maxHeight: maxHeight * 1.4)
            } else {
                Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                    ForEach(Array(stride(from: 0, to: media.count, by: 2)), id: \.self) { start in
                        GridRow {
                            ForEach(start..<min(start + 2, media.count), id: \.self) { index in
                                tile(media[index], index: index)
                            }
                        }
                    }
                }
                .frame(height: media.count > 2 ? maxHeight : maxHeight * 0.66)
            }
        }
        .clipShape(.rect(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary)
        }
        .fullScreenCover(item: $presentedMedia) { presented in
            MediaViewer(media: media, selection: presented.index)
        }
    }

    private func tile(_ item: Media, index: Int) -> some View {
        Button {
            presentedMedia = PresentedMedia(index: index)
        } label: {
            Color.clear
                .overlay {
                    AsyncImage(url: item.previewURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(.quaternary)
                    }
                }
                .overlay {
                    if item.kind != .photo {
                        Image(systemName: item.kind == .gif ? "play.circle" : "play.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .padding(14)
                            .glassEffect(.regular, in: .circle)
                    }
                }
                .clipped()
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.altText ?? (item.kind == .photo ? "Image" : "Video"))
    }

    private struct PresentedMedia: Identifiable {
        let index: Int
        var id: Int { index }
    }
}

package struct MediaViewer: View {
    let media: [Media]
    @State var selection: Int
    @Environment(\.dismiss) private var dismiss

    package var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(Array(media.enumerated()), id: \.element.id) { index, item in
                    MediaPage(item: item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .automatic : .never))
            .background(.black)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .close) { dismiss() }
                }
                if let item = media[safe: selection], item.kind == .photo {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: item.fullSizeURL)
                    }
                }
            }
        }
    }
}

private struct MediaPage: View {
    let item: Media

    var body: some View {
        switch item.kind {
        case .photo:
            AsyncImage(url: item.fullSizeURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .accessibilityLabel(item.altText ?? "Image")
        case .gif, .video:
            if let url = item.videoURL {
                VideoPage(url: url, loops: item.kind == .gif)
            } else {
                ContentUnavailableView("Video unavailable", systemImage: "video.slash")
            }
        }
    }
}

private struct VideoPage: View {
    let url: URL
    let loops: Bool
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        VideoPlayer(player: player)
            .task {
                let player = AVQueuePlayer()
                if loops {
                    looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
                } else {
                    player.insert(AVPlayerItem(url: url), after: nil)
                }
                self.player = player
                player.play()
            }
            .onDisappear { player?.pause() }
    }
}

extension Array {
    package subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
