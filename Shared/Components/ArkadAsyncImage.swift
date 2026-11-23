// File: Shared/Components/ArkadAsyncImage.swift
// The one shared, cached image view. It resolves two kinds of image string:
//   https://…                      loaded with URLSession (HTTP cache on disk)
//   arkad-image://{imageId}?v=123  the JPEG bytes in Firestore `images/{imageId}` (field `data`)
// Decoded images are kept in memory, keyed by the full string, so a new `v` loads a fresh copy.
// Concurrent loads of the same string share one request. Nil, empty and failed strings show
// the placeholder.

import SwiftUI
import UIKit
import FirebaseFirestore

struct ArkadAsyncImage<Content: View, Placeholder: View>: View {
    private let key: String?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var loaded: LoadedImage?

    init(
        urlString: String?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.key = ArkadImageLoader.normalizedKey(urlString)
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = currentImage {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: key) {
            guard let key else {
                loaded = nil
                return
            }
            if let cached = ArkadImageCache.shared.image(for: key) {
                loaded = LoadedImage(key: key, image: cached)
                return
            }
            let image = await ArkadImageLoader.shared.image(for: key)
            guard !Task.isCancelled else { return }
            loaded = image.map { LoadedImage(key: key, image: $0) }
        }
    }

    /// The image for the current string: the one this view loaded, or a memory-cache hit
    /// (so a cached image shows on the first frame, with no placeholder flash).
    private var currentImage: UIImage? {
        guard let key else { return nil }
        if let loaded, loaded.key == key { return loaded.image }
        return ArkadImageCache.shared.image(for: key)
    }
}

private struct LoadedImage {
    let key: String
    let image: UIImage
}

// MARK: - Memory cache

/// Decoded images keyed by the full image string. NSCache is thread-safe.
final class ArkadImageCache: @unchecked Sendable {
    static let shared = ArkadImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 64 * 1024 * 1024
        cache.countLimit = 400
        return cache
    }()

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString, cost: Self.cost(of: image))
    }

    func remove(_ key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    private static func cost(of image: UIImage) -> Int {
        if let cgImage = image.cgImage {
            return cgImage.bytesPerRow * cgImage.height
        }
        return Int(image.size.width * image.scale * image.size.height * image.scale * 4)
    }
}

// MARK: - Loader

/// Loads and decodes images, sharing one in-flight request per string.
@MainActor
final class ArkadImageLoader {
    static let shared = ArkadImageLoader()

    /// Prefix of image strings stored in Firestore (`images/{imageId}`).
    nonisolated static let firestoreScheme = "arkad-image://"

    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private nonisolated static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 150 * 1024 * 1024)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration)
    }()

    /// Trimmed string, or nil when there's nothing to load.
    nonisolated static func normalizedKey(_ urlString: String?) -> String? {
        guard let trimmed = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// The Firestore image id in an `arkad-image://{imageId}?v=…` string, or nil for any other string.
    nonisolated static func firestoreImageId(from urlString: String) -> String? {
        guard urlString.hasPrefix(firestoreScheme) else { return nil }
        let rest = urlString.dropFirst(firestoreScheme.count)
        let id = rest.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        let trimmed = id.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty, !trimmed.contains("/") else { return nil }
        return trimmed
    }

    /// The image for `key` (already normalized), from memory, a shared in-flight load or a new load.
    func image(for key: String) async -> UIImage? {
        if let cached = ArkadImageCache.shared.image(for: key) { return cached }
        if let existing = inFlight[key] { return await existing.value }

        let task = Task<UIImage?, Never> {
            await Self.fetch(key)
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image {
            ArkadImageCache.shared.insert(image, for: key)
        }
        return image
    }

    private nonisolated static func fetch(_ key: String) async -> UIImage? {
        do {
            let data: Data?
            if let imageId = firestoreImageId(from: key) {
                let snapshot = try await Firestore.firestore().collection("images").document(imageId).getDocument()
                data = snapshot.data()?["data"] as? Data
            } else if let url = URL(string: key), let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" {
                let (body, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    data = nil
                } else {
                    data = body
                }
            } else {
                data = nil
            }
            guard let data, let image = UIImage(data: data) else { return nil }
            // Decode now, off the main thread, so scrolling doesn't stutter.
            return await image.byPreparingForDisplay() ?? image
        } catch {
            #if DEBUG
            print("⚠️ ArkadAsyncImage: couldn't load \(key): \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}
