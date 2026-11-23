// File: Core/Payments/WebAuthSession.swift
// Opens Stripe and SnapTrade web flows in an in-app browser sheet and waits for the
// arkad:// callback (see docs/backend-contracts.md).

import AuthenticationServices
import UIKit

@MainActor
final class WebAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let callbackURLScheme = "arkad"

    /// Kept alive while the sheet is open
    private var session: ASWebAuthenticationSession?

    /// Opens `url` and returns the `arkad://` URL it finished on,
    /// or nil if the person closed the sheet without finishing.
    func open(_ url: URL) async throws -> URL? {
        session?.cancel()
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callback: .customScheme(Self.callbackURLScheme),
                completionHandler: Self.completionHandler(resuming: continuation)
            )
            session.presentationContextProvider = self
            // Share Safari's cookies so Stripe and brokerages can remember the sign-in
            session.prefersEphemeralWebBrowserSession = false
            self.session = session

            if !session.start() {
                continuation.resume(throwing: WebAuthSessionError.couldNotStart)
            }
        }
    }

    /// Built outside the main actor so the handler can run on whatever queue the system uses.
    nonisolated private static func completionHandler(
        resuming continuation: CheckedContinuation<URL?, Error>
    ) -> ASWebAuthenticationSession.CompletionHandler {
        { callbackURL, error in
            if let error {
                let nsError = error as NSError
                if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                   nsError.code == ASWebAuthenticationSessionError.Code.canceledLogin.rawValue {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(throwing: error)
                }
                return
            }
            continuation.resume(returning: callbackURL)
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        if let window = scene?.keyWindow ?? scene?.windows.first {
            return window
        }
        if let scene {
            return UIWindow(windowScene: scene)
        }
        return ASPresentationAnchor()
    }
}

enum WebAuthSessionError: LocalizedError {
    case couldNotStart

    var errorDescription: String? {
        "Couldn't open the page. Try again."
    }
}

extension URL {
    /// True for `arkad://<host>/<path>`, e.g. `isArkadCallback(host: "checkout", path: "success")`
    func isArkadCallback(host expectedHost: String, path expectedPath: String) -> Bool {
        guard scheme?.lowercased() == WebAuthSession.callbackURLScheme else { return false }
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return host?.lowercased() == expectedHost && trimmedPath == expectedPath
    }
}
