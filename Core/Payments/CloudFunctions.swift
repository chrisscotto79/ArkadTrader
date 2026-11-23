// File: Core/Payments/CloudFunctions.swift
// Typed wrapper around Firebase callable functions, plus friendly error messages.
// Function names, inputs and outputs follow docs/backend-contracts.md (sections 4 and 5).

import Foundation
import FirebaseFunctions

enum CloudFunctions {
    /// All callables live in us-central1
    static let region = "us-central1"

    /// Calls `name` with `data` and decodes the result into `Response`.
    static func call<Response: Decodable & Sendable>(
        _ name: String,
        data: [String: any Sendable] = [:],
        as type: Response.Type = Response.self
    ) async throws -> Response {
        let result = try await Functions.functions(region: region)
            .httpsCallable(name)
            .call(data)
        return try decode(result.data, as: type)
    }

    /// Calls a function that returns `{ url }` and gives back the URL.
    static func callForURL(_ name: String, data: [String: any Sendable] = [:]) async throws -> URL {
        let response = try await call(name, data: data, as: CloudLinkResponse.self)
        guard let url = URL(string: response.url), url.scheme?.hasPrefix("http") == true else {
            throw CloudFunctionError.invalidResponse
        }
        return url
    }

    private static func decode<Response: Decodable>(_ value: Any, as type: Response.Type) throws -> Response {
        guard JSONSerialization.isValidJSONObject(value) else {
            throw CloudFunctionError.invalidResponse
        }
        do {
            let json = try JSONSerialization.data(withJSONObject: value)
            return try JSONDecoder().decode(type, from: json)
        } catch {
            throw CloudFunctionError.invalidResponse
        }
    }

    // MARK: - Errors

    /// Which feature a call belongs to, for the "not set up yet" message
    enum Feature: Sendable {
        case payments
        case brokerage

        var unavailableMessage: String {
            switch self {
            case .payments: return "Payments aren't available yet. Try again later."
            case .brokerage: return "Brokerage linking isn't available yet. Try again later."
            }
        }
    }

    /// A short message for the user. A missing or unavailable function means the server isn't set up yet.
    static func friendlyMessage(for error: Error, feature: Feature = .payments) -> String {
        if let error = error as? CloudFunctionError {
            return error.errorDescription ?? "Something went wrong. Try again."
        }
        // The brokerage Worker's own errors (Core/Brokerage/BrokerageService.swift)
        if let error = error as? BrokerageAPIError {
            return error.errorDescription ?? "Something went wrong. Try again."
        }

        let nsError = error as NSError
        if nsError.domain == FunctionsErrorDomain, let code = FunctionsErrorCode(rawValue: nsError.code) {
            switch code {
            case .notFound, .unavailable, .unimplemented:
                return feature.unavailableMessage
            case .unauthenticated:
                return "Sign in again to continue."
            case .deadlineExceeded:
                return "This is taking too long. Check your connection and try again."
            case .invalidArgument, .failedPrecondition, .permissionDenied, .alreadyExists, .resourceExhausted:
                // These carry a message written by our own functions
                return serverMessage(nsError) ?? "Something went wrong. Try again."
            default:
                return "Something went wrong. Try again."
            }
        }

        if nsError.domain == NSURLErrorDomain {
            return "Check your internet connection and try again."
        }
        return "Something went wrong. Try again."
    }

    private static func serverMessage(_ error: NSError) -> String? {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !message.uppercased().contains("INTERNAL") else { return nil }
        return message
    }
}

// MARK: - Shared response shapes

/// `{ url }`
struct CloudLinkResponse: Decodable, Sendable {
    let url: String
}

/// `{ ok }`
struct CloudOKResponse: Decodable, Sendable {
    let ok: Bool?
}

enum CloudFunctionError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Something went wrong. Try again."
        }
    }
}
