import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // Load variables from .env files before anything else so Environment.get works locally
    DotEnvLoader.load(into: app)

    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
	app.middleware.use(CORSMiddleware.current, at: .beginning)

	if let port = Int(Environment.get("PORT") ?? "2550") {
		app.http.server.configuration.port = port
	}

    // register routes
    try routes(app)
}
