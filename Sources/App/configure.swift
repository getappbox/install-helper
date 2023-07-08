import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

	if let port = Int(Environment.get("PORT") ?? "2550") {
		app.http.server.configuration.port = port
	}

    // register routes
    try routes(app)
}
