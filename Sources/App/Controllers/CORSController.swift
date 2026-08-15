//
//  CORSController.swift
//
//
//  Created by Vineet Choudhary on 10/09/23.
//

import Vapor

struct CORSController: RouteCollection {
	struct QueryURL: Codable {
		let url: String
	}

	func boot(routes: Vapor.RoutesBuilder) throws {
		let install = routes.grouped("cors")
		install.get(.init(), use: processRequest(req:))
	}

	func processRequest(req: Request) async throws -> ClientResponse {
		let urlString = try req.query.decode(QueryURL.self).url
		guard let url = URL(string: urlString),
			  url.scheme == "https",
			  let host = url.host,
			  Self.isAllowedHost(host, allowedSuffixes: Environment.corsProxyAllowedHosts) else {
			throw Abort(.forbidden, reason: "URL not allowed.")
		}
		return try await req.proxyGet(urlString)
	}

	/// True when `host` equals an allowed suffix or is a subdomain of one.
	static func isAllowedHost(_ host: String, allowedSuffixes: [String]) -> Bool {
		HostAllowlist.isAllowed(host, suffixes: allowedSuffixes)
	}
}
