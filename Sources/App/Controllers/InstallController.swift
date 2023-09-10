//
//  InstallController.swift
//  
//
//  Created by Vineet Choudhary on 10/09/23.
//

import Vapor

struct InstallController: RouteCollection {
	func boot(routes: Vapor.RoutesBuilder) throws {
		let install = routes.grouped("install")
		install.get(.catchall, use: installManifest(req:))
	}

	func installManifest(req: Request) async throws -> ClientResponse {
		let pathComponents = req.url.path.components(separatedBy: "/")
		var manifestURLString = "https://dl.dropboxusercontent.com"
		var manifestURLQueryItems = [URLQueryItem]()
		for pathComponent in pathComponents {
			if pathComponent.isEmpty || pathComponent == "install" {
				continue
			} else if pathComponent.hasPrefix("queryparam-") {
				let queryParam = pathComponent.replacingOccurrences(of: "queryparam-", with: "").components(separatedBy: "-value-")
				guard queryParam.count == 2 else {
					continue
				}
				manifestURLQueryItems.append(.init(name: queryParam[0], value: queryParam[1]))
			} else {
				manifestURLString.append("/\(pathComponent)")
			}
		}
		var manifestURLComponents = URLComponents(string: manifestURLString)
		if !manifestURLString.isEmpty {
			manifestURLComponents?.queryItems = manifestURLQueryItems
		}

		guard let manifestURL = manifestURLComponents?.url else {
			throw Abort(.badRequest, reason: "Invalid URL.")
		}

		return try await req.client.get(.init(stringLiteral: manifestURL.absoluteString))
	}
}
