import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "AppBox Install Service Helper"
    }

	try app.register(collection: InstallController())
	try app.register(collection: ReCaptchaController())
}
