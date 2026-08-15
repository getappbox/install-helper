import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "AppBox Install Service Helper"
    }

	// MARK: - Install / appinfo proxies (install.getappbox.com)
	let legacy = app.grouped(RateLimitMiddleware(bucket: "legacy", limit: 300))
	try legacy.register(collection: CORSController())
	try legacy.register(collection: InstallController())
	try legacy.register(collection: DBAppInfoController())
	try legacy.register(collection: DBUCAppInfoController())

	// MARK: - AppBox client API (api.getappbox.com — same service, routes are host-agnostic)
	let api = app.grouped("api", "v1").grouped(ClientTokenMiddleware())
	try api.grouped(RateLimitMiddleware(bucket: "config", limit: 120))
		.register(collection: ConfigController())
	try api.grouped(RateLimitMiddleware(bucket: "latest-version", limit: 120))
		.register(collection: LatestVersionController())

	let authenticated = api.grouped(DropboxTokenMiddleware())
	try authenticated.grouped(RateLimitMiddleware(bucket: "shorten", limit: 60))
		.register(collection: ShortLinkController())
	try authenticated.grouped(RateLimitMiddleware(bucket: "mail", limit: 20))
		.register(collection: MailController())
	try authenticated.grouped(RateLimitMiddleware(bucket: "notify", limit: 60))
		.register(collection: NotifyController())
}
