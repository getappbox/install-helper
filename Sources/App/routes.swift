import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "AppBox Install Service Helper"
    }

	// MARK: - Middleware
	app.middleware.use(CORSMiddleware.current, at: .beginning)

	// MARK: - Controller
	try app.register(collection: CORSController())
	try app.register(collection: InstallController())
	try app.register(collection: ReCaptchaController())
	try app.register(collection: TurnstileController())
}
