// File: Shared/Services/ImageStore.swift
// Profile and community photos without Cloud Storage (free Spark plan).
// Each image is one Firestore doc, `images/{imageId}`:
//   { ownerId, kind, data: Bytes (JPEG), width, height, updatedAt }
// Ids: avatar_{uid}, community_avatar_{cid}, community_banner_{cid}.
// The firestore.rules match allows the write only from the owner, under 700 KB, and for a
// community image only when `communities/{cid}` already exists with `createdBy == me`.
// Uploads return `arkad-image://{imageId}?v={unix seconds}`, which ArkadAsyncImage resolves.

import UIKit
import FirebaseAuth
import FirebaseFirestore

enum ArkadImageKind: String {
    case avatar
    case communityAvatar = "community_avatar"
    case communityBanner = "community_banner"
}

enum ImageStoreError: LocalizedError {
    case notSignedIn
    case unreadableImage
    case tooLarge(bytes: Int)
    case permissionDenied(imageId: String)
    case saveFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You need to be signed in to change photos."
        case .unreadableImage:
            return "This photo couldn't be read. Try a different one."
        case .tooLarge(let bytes):
            return "This photo is still too large after compressing (\(bytes / 1024) KB). Try a smaller one."
        case .permissionDenied(let imageId):
            if imageId.hasPrefix("community_") {
                return "The photo was refused (permission denied). Only the community owner can change its photos."
            }
            return "The photo was refused (permission denied). Sign out and back in, then try again."
        case .saveFailed(let message):
            return "The photo couldn't be saved: \(message)"
        case .deleteFailed(let message):
            return "The photo couldn't be removed: \(message)"
        }
    }
}

final class ImageStore: @unchecked Sendable {
    static let shared = ImageStore()

    /// The rules allow up to 700 × 1024 bytes of `data`; stay well under that.
    static let maxBytes = 600 * 1024

    private var db: Firestore { FirebaseServices.shared.db }

    private init() {}

    // MARK: - Ids

    static func avatarId(userId: String) -> String { "avatar_\(userId)" }
    static func communityAvatarId(communityId: String) -> String { "community_avatar_\(communityId)" }
    static func communityBannerId(communityId: String) -> String { "community_banner_\(communityId)" }

    /// The `images/{imageId}` id inside an `arkad-image://` string, or nil for any other string.
    static func imageId(from urlString: String?) -> String? {
        guard let key = ArkadImageLoader.normalizedKey(urlString) else { return nil }
        return ArkadImageLoader.firestoreImageId(from: key)
    }

    // MARK: - Upload

    /// The signed-in user's profile photo: a 256 px square crop.
    func uploadAvatar(_ image: UIImage) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else { throw ImageStoreError.notSignedIn }
        return try await upload(image, id: Self.avatarId(userId: uid), kind: .avatar)
    }

    /// A community's avatar: a 256 px square crop. The community doc must already exist.
    func uploadCommunityAvatar(_ image: UIImage, communityId: String) async throws -> String {
        try await upload(image, id: Self.communityAvatarId(communityId: communityId), kind: .communityAvatar)
    }

    /// A community's banner: at most 1200 px wide. The community doc must already exist.
    func uploadCommunityBanner(_ image: UIImage, communityId: String) async throws -> String {
        try await upload(image, id: Self.communityBannerId(communityId: communityId), kind: .communityBanner)
    }

    /// Resizes, encodes and writes `images/{id}`. Returns `arkad-image://{id}?v={unix seconds}`.
    func upload(_ image: UIImage, id: String, kind: ArkadImageKind) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else { throw ImageStoreError.notSignedIn }

        let maxBytes = Self.maxBytes
        let encoded = try await Task.detached(priority: .userInitiated) {
            try ImageEncoder.encode(image, kind: kind, maxBytes: maxBytes)
        }.value

        let document: [String: Any] = [
            "ownerId": uid,
            "kind": kind.rawValue,
            "data": encoded.data,
            "width": encoded.width,
            "height": encoded.height,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        do {
            try await db.collection("images").document(id).setData(document)
        } catch {
            throw Self.describe(error, imageId: id, deleting: false)
        }

        let urlString = "\(ArkadImageLoader.firestoreScheme)\(id)?v=\(Int(Date().timeIntervalSince1970))"
        // Show the new photo straight away, without reading it back.
        ArkadImageDiskCache.store(encoded.data, for: urlString)
        if let decoded = UIImage(data: encoded.data) {
            ArkadImageCache.shared.insert(decoded, for: urlString)
        }
        return urlString
    }

    // MARK: - Delete

    /// Deletes `images/{id}`. Does nothing when the doc doesn't exist (the delete rule needs an
    /// existing doc owned by you, so deleting a missing one would be refused).
    func deleteImage(id: String) async throws {
        let reference = db.collection("images").document(id)
        do {
            let snapshot = try await reference.getDocument()
            guard snapshot.exists else { return }
            try await reference.delete()
        } catch {
            throw Self.describe(error, imageId: id, deleting: true)
        }
    }

    /// Deletes the Firestore image behind an `arkad-image://` string; ignores any other string.
    func deleteImage(urlString: String?) async throws {
        guard let id = Self.imageId(from: urlString) else { return }
        try await deleteImage(id: id)
    }

    // MARK: - Errors

    private static func describe(_ error: Error, imageId: String, deleting: Bool) -> Error {
        let nsError = error as NSError
        // FIRFirestoreErrorDomain code 7 is PERMISSION_DENIED (the rules refused the write).
        if nsError.domain == "FIRFirestoreErrorDomain", nsError.code == 7 {
            return ImageStoreError.permissionDenied(imageId: imageId)
        }
        let message = nsError.localizedDescription
        return deleting ? ImageStoreError.deleteFailed(message) : ImageStoreError.saveFailed(message)
    }
}

// MARK: - Encoding

/// Resizes and JPEG-encodes an image until it fits `maxBytes`.
enum ImageEncoder {
    struct Encoded {
        let data: Data
        let width: Int
        let height: Int
    }

    static let avatarSide: CGFloat = 256
    static let bannerMaxWidth: CGFloat = 1200
    static let bannerMaxHeight: CGFloat = 800

    /// Tries quality 0.7 down to 0.35, then shrinks the pixel size by a quarter and tries again.
    static func encode(_ image: UIImage, kind: ArkadImageKind, maxBytes: Int) throws -> Encoded {
        guard image.size.width >= 1, image.size.height >= 1 else { throw ImageStoreError.unreadableImage }

        var scale: CGFloat = 1
        var smallest = Int.max
        for _ in 0..<5 {
            let rendered = render(image, kind: kind, scale: scale)
            for quality in [0.7, 0.6, 0.5, 0.42, 0.35] as [CGFloat] {
                guard let data = rendered.jpegData(compressionQuality: quality) else {
                    throw ImageStoreError.unreadableImage
                }
                if data.count <= maxBytes {
                    return Encoded(
                        data: data,
                        width: Int(rendered.size.width.rounded()),
                        height: Int(rendered.size.height.rounded())
                    )
                }
                smallest = min(smallest, data.count)
            }
            scale *= 0.75
        }
        throw ImageStoreError.tooLarge(bytes: smallest)
    }

    /// Draws the image at 1x: a centre square crop for avatars, a width-limited copy for banners.
    private static func render(_ image: UIImage, kind: ArkadImageKind, scale: CGFloat) -> UIImage {
        let source = image.size
        let target: CGSize
        let drawRect: CGRect

        switch kind {
        case .avatar, .communityAvatar:
            let side = max(1, (min(avatarSide, min(source.width, source.height)) * scale).rounded())
            let fill = max(side / source.width, side / source.height)
            let drawn = CGSize(width: source.width * fill, height: source.height * fill)
            target = CGSize(width: side, height: side)
            drawRect = CGRect(
                x: (side - drawn.width) / 2,
                y: (side - drawn.height) / 2,
                width: drawn.width,
                height: drawn.height
            )
        case .communityBanner:
            let fit = min(1, bannerMaxWidth / source.width, bannerMaxHeight / source.height) * scale
            let size = CGSize(
                width: max(1, (source.width * fit).rounded()),
                height: max(1, (source.height * fit).rounded())
            )
            target = size
            drawRect = CGRect(origin: .zero, size: size)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { context in
            // JPEG has no transparency; give see-through pixels a neutral background.
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: drawRect)
        }
    }
}
