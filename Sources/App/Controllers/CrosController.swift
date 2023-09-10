//
//  CrosController.swift
//  
//
//  Created by Vineet Choudhary on 10/09/23.
//

import Vapor

struct CrosController: RouteCollection {
	struct QueryURL: Codable {
		let url: String
	}

	func boot(routes: Vapor.RoutesBuilder) throws {
		let install = routes.grouped("cros")
		install.get(.init(), use: processRequest(req:))
	}

	func processRequest(req: Request) async throws -> ClientResponse {
		let url = try req.query.decode(QueryURL.self).url
		var response = try await req.client.get(.init(stringLiteral: url))
		return response.removeCrosHeaders()
	}
}
