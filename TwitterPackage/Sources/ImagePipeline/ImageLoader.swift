import CoreGraphics
import Dependencies
import DependenciesMacros
import Foundation
import ImageIO
import Synchronization

/// An image at a decoded size: the same URL shown as a 44pt avatar and a 400pt header are different entries.
package struct ImageRequest: Hashable, Sendable {
    package var url: URL
    package var maxPixelSize: Int

    /// Sizes are bucketed so nearby layouts share decoded images instead of each decoding their own.
    package init(url: URL, pointSize: CGFloat, scale: CGFloat) {
        self.url = url
        let pixels = Int((pointSize * scale).rounded(.up))
        maxPixelSize = Self.buckets.first { $0 >= pixels } ?? Self.buckets[Self.buckets.count - 1]
    }

    private static let buckets = [64, 128, 192, 256, 384, 512, 768, 1024, 1536, 2048, 4096]
}

/// Loads remote images, decodes them off the main actor at display size, and keeps the decoded bitmaps in memory.
///
/// `AsyncImage` on iOS 27 caches the downloaded bytes, but it decodes every image at full size and holds nothing in
/// memory, so lazily recycled rows flash a placeholder and decode again on every scroll back. Here a recycled row can
/// read its image synchronously on its first frame.
@DependencyClient
package struct ImageLoader: Sendable {
    /// The decoded image, if it's already in memory. Cheap enough to call from a view's body.
    package var cached: @Sendable (_ request: ImageRequest) -> CGImage? = { _ in nil }
    package var image: @Sendable (_ request: ImageRequest) async -> CGImage?
    /// Starts loading images that are about to scroll into view. Only an optimization, so it does nothing by default.
    package var prefetch: @Sendable (_ requests: [ImageRequest]) -> Void = { _ in }
}

extension ImageLoader: DependencyKey {
    package static var liveValue: ImageLoader {
        let pipeline = ImagePipeline()
        return ImageLoader(
            cached: { pipeline.cached($0) },
            image: { await pipeline.image($0) },
            prefetch: { pipeline.prefetch($0) }
        )
    }

    package static var previewValue: ImageLoader { liveValue }

    package static let testValue = ImageLoader()
}

extension URLSession {
    /// Downloaded image bytes, cached on disk. Twitter's media URLs are immutable, so cached data never goes stale.
    package static let images: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 32 << 20, diskCapacity: 1 << 30)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpMaximumConnectionsPerHost = 8
        return URLSession(configuration: configuration)
    }()
}

private final class ImagePipeline: Sendable {
    private let cache = DecodedImageCache()
    private let inflight = Mutex<[ImageRequest: Task<CGImage?, Never>]>([:])

    func cached(_ request: ImageRequest) -> CGImage? {
        cache[request]
    }

    func image(_ request: ImageRequest) async -> CGImage? {
        if let hit = cache[request] { return hit }
        guard let task = load(request, priority: .userInitiated) else { return cache[request] }
        // Awaiting an unstructured task's value doesn't cancel it, so a joiner whose view goes away leaves the shared
        // load running for everyone else. Awaiting from a higher priority escalates a prefetch's `.utility` task.
        return await task.value
    }

    func prefetch(_ requests: [ImageRequest]) {
        for request in requests where cache[request] == nil {
            _ = load(request, priority: .utility)
        }
    }

    /// The shared load for a request, started if nobody holds one, or `nil` when the image is already cached.
    private func load(_ request: ImageRequest, priority: TaskPriority) -> Task<CGImage?, Never>? {
        inflight.withLock { inflight in
            if let existing = inflight[request] { return existing }
            // A load caches its image before leaving `inflight`, so missing both means nobody holds it.
            guard cache[request] == nil else { return nil }
            let task = Task(priority: priority) { @concurrent () -> CGImage? in
                defer { self.inflight.withLock { _ = $0.removeValue(forKey: request) } }
                guard let (data, _) = try? await URLSession.images.data(from: request.url),
                    let image = Self.downsample(data, maxPixelSize: request.maxPixelSize)
                else { return nil }
                self.cache[request] = image
                return image
            }
            inflight[request] = task
            return task
        }
    }

    private static func downsample(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

/// `NSCache` evicts under memory pressure on its own; it's thread-safe but not annotated `Sendable`.
private final class DecodedImageCache: @unchecked Sendable {
    private let storage: NSCache<Key, Entry> = {
        let cache = NSCache<Key, Entry>()
        cache.totalCostLimit = 192 << 20
        return cache
    }()

    subscript(request: ImageRequest) -> CGImage? {
        get { storage.object(forKey: Key(request))?.image }
        set {
            guard let newValue else { return storage.removeObject(forKey: Key(request)) }
            storage.setObject(Entry(newValue), forKey: Key(request), cost: newValue.bytesPerRow * newValue.height)
        }
    }

    private final class Key: NSObject {
        let request: ImageRequest
        init(_ request: ImageRequest) { self.request = request }
        override var hash: Int { request.hashValue }
        override func isEqual(_ object: Any?) -> Bool { (object as? Key)?.request == request }
    }

    private final class Entry {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }
}
