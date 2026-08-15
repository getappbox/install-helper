//
//  ConfigController.swift
//
//
//  Created by Vineet Choudhary on 06/07/26.
//

import Vapor

/// `GET /api/v1/config` — client bootstrap values (currently the public Dropbox OAuth client_id).
struct ConfigController: RouteCollection {
	func boot(routes: Vapor.RoutesBuilder) throws {
		routes.get("config", use: config(req:))
	}

	func config(req: Request) async throws -> ConfigResponse {
		guard let key = Environment.dropboxAppKey, !key.isEmpty else {
			throw Abort(.internalServerError, reason: "DROPBOX_APP_KEY is not configured.")
		}
		return ConfigResponse(dropboxAppKey: key)
	}
}
