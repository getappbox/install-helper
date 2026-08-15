//
//  ClientTokenMiddleware.swift
//
//
//  Created by Vineet Choudhary on 06/07/26.
//

import Vapor

/// Requires the static AppBox client token on every `/api/v1` request.
struct ClientTokenMiddleware: AsyncMiddleware {
	static let header = HTTPHeaders.Name("X-AppBox-Client-Token")

	func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
		guard let expected = Environment.appboxClientToken, !expected.isEmpty,
			  let provided = request.headers.first(name: Self.header),
			  constantTimeEquals(provided, expected) else {
			return APIErrorResponse.response(status: .unauthorized, code: "invalid_client_token",
											 message: "Missing or invalid client token.")
		}
		return try await next.respond(to: request)
	}

	/// Comparison that doesn't leak the match length/prefix through timing.
	private func constantTimeEquals(_ a: String, _ b: String) -> Bool {
		let aBytes = Array(a.utf8)
		let bBytes = Array(b.utf8)
		guard aBytes.count == bBytes.count else { return false }
		var difference: UInt8 = 0
		for index in 0..<aBytes.count {
			difference |= aBytes[index] ^ bBytes[index]
		}
		return difference == 0
	}
}
