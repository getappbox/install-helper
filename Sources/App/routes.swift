import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "AppBox Install Service Helper"
    }

	// MARK: - Controller
	try app.register(collection: CORSController())
	try app.register(collection: InstallController())
	try app.register(collection: DBAppInfoController())
	try app.register(collection: DBUCAppInfoController())
}
