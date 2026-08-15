//
//  DropboxTokenMiddleware.swift
//
//
//  Created by Vineet Choudhary on 06/07/26.
//

import Vapor
import Crypto

/// The outcome of verifying a Dropbox access token, or nil when Dropbox couldn't be reached.
enum DropboxTokenVerdict {
	case verified(accountID: String)
	case rejected
}

/// Seam for the Dropbox verification call so tests can stub it.
protocol DropboxTokenVerifying {
	func verify(token: String, on request: Request) async -> DropboxTokenVerdict?
}

/// Production verifier: asks Dropbox who the token belongs to.
struct DropboxAPITokenVerifier: DropboxTokenVerifying {
	func verify(token: String, on request: Request) async -> DropboxTokenVerdict? {
		var headers = HTTPHeaders()
		headers.bearerAuthorization = BearerAuthorization(token: token)
		let response: ClientResponse
		do {
			response = try await request.client.post("https://api.dropboxapi.com/2/users/get_current_account", headers: headers)
		} catch {
			return nil
		}
		switch response.status.code {
		case 200:
			let accountID = (try? response.content.get(String.self, at: "account_id")) ?? "unknown"
			return .verified(accountID: accountID)
		case 400, 401:
			return .rejected
		default:
			return nil
		}
	}
}

extension Application {
	private struct DropboxTokenVerifierKey: StorageKey {
		typealias Value = DropboxTokenVerifying
	}

	var dropboxTokenVerifier: DropboxTokenVerifying {
		get { storage[DropboxTokenVerifierKey.self] ?? DropboxAPITokenVerifier() }
		set { storage[DropboxTokenVerifierKey.self] = newValue }
	}
}

/// Requires a valid Dropbox access token (`Authorization: Bearer …`) from a real, logged-in AppBox user.
struct DropboxTokenMiddleware: AsyncMiddleware {
	func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
		guard let token = request.headers.bearerAuthorization?.token, !token.isEmpty else {
			return APIErrorResponse.response(status: .unauthorized, code: "missing_dropbox_token",
											 message: "A Dropbox access token is required.")
		}

		let digest = SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
		let store = request.application.dropboxTokenVerdicts

		if let cached = await store.verdict(for: digest) {
			guard cached.verified else {
				return APIErrorResponse.response(status: .unauthorized, code: "invalid_dropbox_token",
												 message: "The Dropbox token was rejected.")
			}
			return try await next.respond(to: request)
		}

		guard let verdict = await request.application.dropboxTokenVerifier.verify(token: token, on: request) else {
			return APIErrorResponse.response(status: .serviceUnavailable, code: "verification_unavailable",
											 message: "Could not verify the Dropbox token. Try again shortly.")
		}

		switch verdict {
		case .verified(let accountID):
			await store.store(.init(verified: true, accountID: accountID), for: digest,
							  ttl: TimeInterval(Environment.dropboxTokenCacheTTLSeconds))
			return try await next.respond(to: request)
		case .rejected:
			await store.store(.init(verified: false, accountID: nil), for: digest, ttl: 60)
			return APIErrorResponse.response(status: .unauthorized, code: "invalid_dropbox_token",
											 message: "The Dropbox token was rejected.")
		}
	}
}
