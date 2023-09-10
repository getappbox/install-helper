import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "AppBox Install Service Helper"
    }

	// MARK: - CORS
	let corsConfiguration = CORSMiddleware.Configuration(
		allowedOrigin: .any(Environment.corsAllowList),
		allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
		allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
	)
	let cors = CORSMiddleware(configuration: corsConfiguration)
	app.middleware.use(cors, at: .beginning)

	// MARK: - Controller
	try app.register(collection: CrosController())
	try app.register(collection: InstallController())
	try app.register(collection: ReCaptchaController())
}
