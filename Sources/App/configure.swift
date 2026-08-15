import Vapor

public func configure(_ app: Application) async throws {
    DotEnvLoader.load(into: app)

	app.middleware.use(CORSMiddleware.current, at: .beginning)

	if let port = Int(Environment.get("PORT") ?? "8080") {
		app.http.server.configuration.port = port
	}

	app.caches.use(.memory)

	app.http.client.configuration.timeout = .init(connect: .seconds(10), read: .seconds(30))

	let missingConfig = Environment.missingAPIConfiguration()
	if !missingConfig.isEmpty {
		app.logger.warning("AppBox /api/v1 secrets missing (those endpoints will error until set): \(missingConfig.joined(separator: ", "))")
	}

    try routes(app)
}
