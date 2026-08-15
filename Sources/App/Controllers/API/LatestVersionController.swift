//
//  LatestVersionController.swift
//
//
//  Created by Vineet Choudhary on 06/07/26.
//

import Vapor

/// `GET /api/v1/latest-version` — the latest AppBox version (GitHub + Homebrew, merged + cached).
struct LatestVersionController: RouteCollection {
	func boot(routes: Vapor.RoutesBuilder) throws {
		routes.get("latest-version", use: latest(req:))
	}

	func latest(req: Request) async throws -> Response {
		do {
			let result = try await req.application.latestVersionProvider.latestVersion(on: req)
			let response = Response(status: .ok)
			try response.content.encode(result)
			return response
		} catch let apiError as APIError {
			return APIErrorResponse.response(status: apiError.status, code: apiError.code, message: apiError.message)
		}
	}
}
