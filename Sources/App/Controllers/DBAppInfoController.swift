//
//  DBAppInfoController.swift
//
//
//  Created by Vineet Choudhary on 02/09/25.
//

import Vapor

/// A controller to handle requests to the `/appinfo/scl/*` endpoint.
///
/// This controller processes requests to the `/appinfo/scl/*` endpoint,
/// modifies the URL to ensure direct download from Dropbox, and forwards
/// the request to Dropbox. (https://www.dropbox.com/scl/...)
struct DBAppInfoController: RouteCollection {
	func boot(routes: Vapor.RoutesBuilder) throws {
		let install = routes.grouped("appinfo", "scl")
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

		// ensure dl=1 is present to force direct download from Dropbox
		let dlQueryItem = URLQueryItem(name: "dl", value: "1")
		if let dlQueryItemIndex = queryItems.firstIndex(where: { $0.name == dlQueryItem.name }) {
			queryItems[dlQueryItemIndex] = dlQueryItem
		} else {
			queryItems.append(dlQueryItem)
		}

		var components = URLComponents()
		components.scheme = "https"
		components.host = "www.dropbox.com"
		components.path = req.url.path.replacingOccurrences(of: "/appinfo/", with: "/")
		components.queryItems = queryItems

		guard let urlString = components.string else {
			throw Abort(.badRequest, reason: "Invalid URL.")
		}

		return try await req.client.get(.init(string: urlString))
	}
}
