//
//  AppInfoController.swift
//
//
//  Created by Vineet Choudhary on 02/09/25.
//

import Vapor

/// A controller to handle requests to the `/appinfo/s/*` endpoint.
///
/// This controller processes requests to the `/appinfo/s/*` endpoint,
/// modifies the URL to ensure direct download from Dropbox, and forwards
/// the request to Dropbox. (https://dl.dropboxusercontent.com/s/...)
struct DBUCAppInfoController: RouteCollection {
	let ignoreQueryParams = ["$web_only", "_branch_match_id", "_branch_referrer"]

	func boot(routes: Vapor.RoutesBuilder) throws {
		let install = routes.grouped("appinfo", "s")
		install.get(.catchall, use: processRequest(req:))
	}

	func processRequest(req: Request) async throws -> ClientResponse {
		var queryItems: [URLQueryItem] = req.url.query?.split(separator: "&").compactMap { param in
			return getQueryParam(from: param.split(separator: "="))
		} ?? []

		var path = req.url.path
		let possibleParams = path.split(separator: "&")
		if (path.contains("?") || path.contains("&")) && queryItems.isEmpty {
			queryItems = possibleParams.compactMap { param in
				path = path.replacingOccurrences(of: "&\(param)", with: "")
				return getQueryParam(from: param.split(separator: "="))
			}
			path = path.replacingOccurrences(of: "?", with: "").replacingOccurrences(of: "&", with: "")
		}

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
		components.path = path.replacingOccurrences(of: "/appinfo/", with: "/")
		components.queryItems = queryItems

		guard let urlString = components.string else {
			throw Abort(.badRequest, reason: "Invalid URL.")
		}

		return try await req.client.get(.init(string: urlString))
	}

	private func getQueryParam(from keyValue: [Substring.SubSequence]) -> URLQueryItem? {
		guard keyValue.count == 2 else {
			return nil
		}
		guard !ignoreQueryParams.contains(String(keyValue[0])) else {
			return nil
		}
		return URLQueryItem(name: String(keyValue[0]), value: String(keyValue[1]))
	}
}
