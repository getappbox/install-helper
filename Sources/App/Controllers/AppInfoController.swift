//
//  AppInfoController.swift
//
//
//  Created by Vineet Choudhary on 02/09/25.
//

import Vapor

struct AppInfoController: RouteCollection {
	struct QueryURL: Codable {
		let url: String
	}

	func boot(routes: Vapor.RoutesBuilder) throws {
		let install = routes.grouped("appinfo")
		install.get(.catchall, use: processRequest(req:))
	}

	func processRequest(req: Request) async throws -> ClientResponse {
		var queryItems: [URLQueryItem] = req.url.query?.split(separator: "&").compactMap { param in
			let keyValue = param.split(separator: "=")
			guard keyValue.count == 2 else {
				return nil
			}
			return URLQueryItem(name: String(keyValue[0]), value: String(keyValue[1]))
		} ?? []
		queryItems.append(URLQueryItem(name: "dl", value: "1"))

		var components = URLComponents()
		components.scheme = "https"
		components.host = "www.dropbox.com"
		components.path = req.url.path.replacingOccurrences(of: "/appinfo", with: "")
		components.queryItems = queryItems

		guard let urlString = components.string else {
			throw Abort(.badRequest, reason: "Invalid URL.")
		}

		return try await req.client.get(.init(string: urlString))
	}
}
