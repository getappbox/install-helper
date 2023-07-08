import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "AppBox Install Service Helper"
    }

	app.get("install", "**") { req async throws -> ClientResponse in
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
		manifestURLComponents?.queryItems = manifestURLQueryItems

		guard let manifestURL = manifestURLComponents?.url else {
			throw Abort(.badRequest, reason: "Invalid URL.")
		}

		return try await req.client.get(.init(stringLiteral: manifestURL.absoluteString))
    }
}
