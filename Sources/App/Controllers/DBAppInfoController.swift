//
//  DBAppInfoController.swift
//
//
//  Created by Vineet Choudhary on 02/09/25.
//

import Vapor
import SwiftSoup

/// A controller to handle requests to the `/appinfo/scl/*` endpoint.
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

		let dlQueryItem = URLQueryItem(name: "dl", value: "1")
		if let dlQueryItemIndex = queryItems.firstIndex(where: { $0.name == dlQueryItem.name }) {
			queryItems[dlQueryItemIndex] = dlQueryItem
		} else {
			queryItems.append(dlQueryItem)
		}

		let path = req.url.path.replacingOccurrences(of: "/appinfo/", with: "/")
		try DropboxPathValidation.validate(path)

		var components = URLComponents()
		components.scheme = "https"
		components.host = "www.dropbox.com"
		components.path = path
		components.queryItems = queryItems

		guard let urlString = components.string else {
			throw Abort(.badRequest, reason: "Invalid URL.")
		}

		let response = try await req.proxyGet(urlString)
		return try await processResponse(response)
	}

	func processResponse(_ response: ClientResponse) async throws -> ClientResponse {
		guard
			let body = response.body,
			let htmlData = body.getData(at: 0, length: body.readableBytes),
			let htmlString = String(data: htmlData, encoding: .utf8) else {
			return response
		}

		if response.headers.contentType == .html {
			let document = try SwiftSoup.parse(htmlString)
			let title = try document.title().lowercased()
			if title.contains("deleted") {
				throw Abort(.notFound, reason: "App info not found on Dropbox.")
			} else if title.contains("link temporarily disabled") {
				throw Abort(.locked, reason: "Share link is temporarily disabled by Dropbox.")
			}
		}

		return response
	}
}
