import UIKit

/// Prefetch and visible artwork share both decoded images and in-flight work.
@MainActor
final class ArtworkCache {
    static let shared = ArtworkCache()
    private let images = NSCache<NSURL, UIImage>()
    private var requests: [URL: (id: UUID, prefetch: Bool, task: Task<UIImage?, Never>)] = [:]
    private let session: URLSession

    init() {
        images.totalCostLimit = 24 * 1024 * 1024
        images.countLimit = 24
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 64 * 1024 * 1024,
                                          directory: URL.cachesDirectory.appendingPathComponent("TaleForkArtwork"))
        configuration.httpMaximumConnectionsPerHost = 2
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        session = URLSession(configuration: configuration)
    }

    func cachedImage(for url: URL) -> UIImage? { images.object(forKey: url as NSURL) }

    func image(for url: URL, prefetch: Bool = false) async -> UIImage? {
        if let image = cachedImage(for: url) { return image }
        if let request = requests[url] {
            let result = await request.task.value
            // A visible consumer may have joined a speculative request that
            // Low Data Mode refused. Retry once with normal viewing policy.
            if result == nil && !prefetch && request.prefetch {
                if requests[url]?.id == request.id { requests[url] = nil }
                return await image(for: url)
            }
            return result
        }
        let id = UUID()
        let request = Task(priority: prefetch ? .utility : .userInitiated) { [session] () -> UIImage? in
            do {
                var request = URLRequest(url: url)
                // Low Data Mode may skip speculative artwork; visible loads remain available.
                request.allowsConstrainedNetworkAccess = !prefetch
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                      data.count <= 12 * 1024 * 1024, let source = UIImage(data: data) else { return nil }
                return await source.byPreparingThumbnail(ofSize: CGSize(width: 1200, height: 1200))
            } catch { return nil }
        }
        requests[url] = (id, prefetch, request)
        let image = await request.value
        if requests[url]?.id == id { requests[url] = nil }
        if let image {
            let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            images.setObject(image, forKey: url as NSURL, cost: cost)
        }
        return image
    }

    func prefetch(_ urls: [URL]) async {
        for url in urls {
            guard !Task.isCancelled else { return }
            _ = await image(for: url, prefetch: true)
        }
    }

    func clearMemory() { images.removeAllObjects() }
}
