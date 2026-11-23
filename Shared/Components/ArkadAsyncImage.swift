// File: Shared/Components/ArkadAsyncImage.swift
// The one shared, cached image view. It resolves two kinds of image string:
//   https://…                      loaded with URLSession (HTTP cache on disk)
//   arkad-image://{imageId}?v=123  the JPEG bytes in Firestore `images/{imageId}` (field `data`)
// Decoded images are kept in memory, and Firestore images also on disk (Caches), keyed by the
// full string, so a new `v` (set on every upload) loads a fresh copy. A Firestore image is read
// from Firestore's own cache first and only fetched from the server when that's missing or
// older than `v`. Concurrent loads of the same string share one request. Nil, empty and failed
// strings show the placeholder.

import SwiftUI
import UIKit
import CryptoKit
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
                data = try await firestoreImageData(imageId: imageId, key: key)
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
            print("ArkadAsyncImage: couldn't load \(key): \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// JPEG bytes for `images/{imageId}`: from the disk cache, else Firestore's local cache
    /// (when it's at least as new as the string's `v`), else the server. Saved to disk after.
    private nonisolated static func firestoreImageData(imageId: String, key: String) async throws -> Data? {
        if let cached = ArkadImageDiskCache.data(for: key) {
            return cached
        }

        let reference = FirebaseServices.shared.db.collection("images").document(imageId)
        if let snapshot = try? await reference.getDocument(source: .cache),
           let data = snapshot.get("data") as? Data,
           isCurrent(snapshot, for: key) {
            ArkadImageDiskCache.store(data, for: key)
            return data
        }

        let snapshot = try await reference.getDocument()
        guard let data = snapshot.get("data") as? Data else { return nil }
        ArkadImageDiskCache.store(data, for: key)
        return data
    }

    /// Whether a cached `images/{id}` doc is the upload `key` points at: its `updatedAt` is no
    /// older than the `v` seconds in the string (a minute of clock slack). No `v` means any copy.
    private nonisolated static func isCurrent(_ snapshot: DocumentSnapshot, for key: String) -> Bool {
        guard let version = URLComponents(string: key)?.queryItems?.first(where: { $0.name == "v" })?.value,
              let seconds = TimeInterval(version) else { return true }
        guard let updatedAt = snapshot.get("updatedAt") as? Timestamp else { return false }
        return updatedAt.dateValue().timeIntervalSince1970 >= seconds - 60
    }
}

// MARK: - Disk cache

/// Firestore image bytes on disk (Caches/ArkadImages), one file per full image string. The
/// system may clear Caches when space is low; files unused for 30 days are removed at launch.
enum ArkadImageDiskCache {
    private static let maxAge: TimeInterval = 30 * 24 * 60 * 60

    private static let directory: URL? = {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = caches.appendingPathComponent("ArkadImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        pruneOldFiles(in: url)
        return url
    }()

    static func data(for key: String) -> Data? {
        guard let url = fileURL(for: key), let data = try? Data(contentsOf: url) else { return nil }
        // Mark as recently used
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return data
    }

    static func store(_ data: Data, for key: String) {
        guard let url = fileURL(for: key) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func fileURL(for key: String) -> URL? {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory?.appendingPathComponent(digest + ".jpg")
    }

    private static func pruneOldFiles(in directory: URL) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        let cutoff = Date().addingTimeInterval(-maxAge)
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
