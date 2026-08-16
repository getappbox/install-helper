@testable import App
import XCTVapor

final class AppTests: XCTestCase {

	private func makeApp() async throws -> Application {
		setenv("APPBOX_CLIENT_TOKEN", "test-client-token", 1)
		setenv("DROPBOX_APP_KEY", "test-app-key", 1)
		setenv("MAILGUN_API_KEY", "test-mailgun-key", 1)
		setenv("YOURLS_SIGNATURE_SECRET", "test-yourls-secret", 1)
		let app = Application(.testing)
		try await configure(app)
		return app
	}

	// MARK: - Health

	func testHealthRoute() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }

		try app.test(.GET, "", afterResponse: { res in
			XCTAssertEqual(res.status, .ok)
			XCTAssertEqual(res.body.string, "AppBox Install Service Helper")
		})
	}

	// MARK: - /cors allowlist

	func testCORSProxy_rejectsDisallowedAndNonHTTPSURLs() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }

		try app.test(.GET, "cors?url=https://169.254.169.254/latest/meta-data", afterResponse: { res in
			XCTAssertEqual(res.status, .forbidden)
		})
		try app.test(.GET, "cors?url=https://evil.example.com/x", afterResponse: { res in
			XCTAssertEqual(res.status, .forbidden)
		})
		try app.test(.GET, "cors?url=http://www.dropbox.com/scl/x", afterResponse: { res in
			XCTAssertEqual(res.status, .forbidden)
		})
		try app.test(.GET, "cors?url=https://notdropbox.com.evil.com/x", afterResponse: { res in
			XCTAssertEqual(res.status, .forbidden)
		})
	}

	func testCORSProxy_missingURLParamIsBadRequest() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }
		try app.test(.GET, "cors", afterResponse: { res in
			XCTAssertEqual(res.status, .badRequest)
		})
	}

	func testCORSAllowedHostMatching() {
		let suffixes = ["dropbox.com", "getappbox.com"]
		XCTAssertTrue(CORSController.isAllowedHost("dropbox.com", allowedSuffixes: suffixes))
		XCTAssertTrue(CORSController.isAllowedHost("www.dropbox.com", allowedSuffixes: suffixes))
		XCTAssertTrue(CORSController.isAllowedHost("WEB.GETAPPBOX.COM", allowedSuffixes: suffixes))
		XCTAssertFalse(CORSController.isAllowedHost("evildropbox.com", allowedSuffixes: suffixes))
		XCTAssertFalse(CORSController.isAllowedHost("dropbox.com.evil.io", allowedSuffixes: suffixes))
	}

	// MARK: - Dropbox path validation

	func testDropboxPathValidation() {
		XCTAssertNoThrow(try DropboxPathValidation.validate("/scl/fi/abc/manifest.plist"))
		XCTAssertNoThrow(try DropboxPathValidation.validate("/s/abc/appinfo.json"))
		XCTAssertThrowsError(try DropboxPathValidation.validate("/other/thing"))
		XCTAssertThrowsError(try DropboxPathValidation.validate("/scl/../../etc/passwd"))
		XCTAssertThrowsError(try DropboxPathValidation.validate("/scl/" + String(repeating: "a", count: 1025)))
	}

	func testInstallRoute_rejectsNonShareLinkPaths() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }

		try app.test(.GET, "install/notascl/manifest.plist", afterResponse: { res in
			XCTAssertEqual(res.status, .badRequest)
		})
	}

	// MARK: - /api/v1 authentication

	private struct StubVerifier: DropboxTokenVerifying {
		let verdict: DropboxTokenVerdict?
		func verify(token: String, on request: Request) async -> DropboxTokenVerdict? { verdict }
	}

	private struct StubShortener: ShortLinkProviding {
		let shortURL: String?
		func shorten(_ request: ShortenRequest, on req: Request) async throws -> String {
			guard let shortURL else {
				throw APIError(status: .badGateway, code: "shortener_unavailable", message: "down")
			}
			return shortURL
		}
	}

	private struct StubMailer: MailSending {
		let id: String?
		let fails: Bool
		func send(_ mail: MailSendRequest, on req: Request) async throws -> String? {
			if fails { throw APIError(status: .badGateway, code: "mail_provider_error", message: "down") }
			return id
		}
	}

	/// Counts how many times the verifier is consulted, so tests can prove the cache short-circuits it.
	private final class CountingVerifier: DropboxTokenVerifying, @unchecked Sendable {
		private let lock = NSLock()
		private var _count = 0
		let verdict: DropboxTokenVerdict?
		init(_ verdict: DropboxTokenVerdict?) { self.verdict = verdict }
		var count: Int { lock.lock(); defer { lock.unlock() }; return _count }
		func verify(token: String, on request: Request) async -> DropboxTokenVerdict? {
			lock.lock(); _count += 1; lock.unlock()
			return verdict
		}
	}

	private struct OKResponder: AsyncResponder {
		func respond(to request: Request) async throws -> Response { Response(status: .ok) }
	}

	private struct StubLatestVersion: LatestVersionProviding {
		let result: LatestVersionResponse?
		func latestVersion(on req: Request) async throws -> LatestVersionResponse {
			guard let result else {
				throw APIError(status: .badGateway, code: "update_check_unavailable", message: "down")
			}
			return result
		}
	}

	private final class RecordingNotifier: NotifySending, @unchecked Sendable {
		private let lock = NSLock()
		private(set) var sent: [NotifyRequest] = []
		let fails: Bool
		init(fails: Bool = false) { self.fails = fails }
		func send(_ request: NotifyRequest, on req: Request) async throws {
			lock.lock(); sent.append(request); lock.unlock()
			if fails { throw APIError(status: .badGateway, code: "notify_failed", message: "down") }
		}
	}

	private var clientTokenHeaders: HTTPHeaders {
		HTTPHeaders([("X-AppBox-Client-Token", "test-client-token")])
	}

	private var fullAuthHeaders: HTTPHeaders {
		var headers = clientTokenHeaders
		headers.bearerAuthorization = BearerAuthorization(token: "some-dropbox-token")
		return headers
	}

	func testConfig_requiresClientToken() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }

		try app.test(.GET, "api/v1/config", afterResponse: { res in
			XCTAssertEqual(res.status, .unauthorized)
		})
		try app.test(.GET, "api/v1/config",
					 headers: HTTPHeaders([("X-AppBox-Client-Token", "wrong")]),
					 afterResponse: { res in
			XCTAssertEqual(res.status, .unauthorized)
		})
		try app.test(.GET, "api/v1/config", headers: clientTokenHeaders, afterResponse: { res in
			XCTAssertEqual(res.status, .ok)
			let body = try res.content.decode(ConfigResponse.self)
			XCTAssertEqual(body.dropboxAppKey, "test-app-key")
		})
	}

	func testShorten_requiresDropboxBearerAndVerification() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }
		app.shortLinkProvider = StubShortener(shortURL: "https://appbox.me/x1")

		try app.test(.POST, "api/v1/shorten", headers: clientTokenHeaders, afterResponse: { res in
			XCTAssertEqual(res.status, .unauthorized)
		})
		app.dropboxTokenVerifier = StubVerifier(verdict: .rejected)
		try app.test(.POST, "api/v1/shorten", headers: fullAuthHeaders, afterResponse: { res in
			XCTAssertEqual(res.status, .unauthorized)
		})
		app.dropboxTokenVerifier = StubVerifier(verdict: nil)
		var unreachableHeaders = clientTokenHeaders
		unreachableHeaders.bearerAuthorization = BearerAuthorization(token: "another-token")
		try app.test(.POST, "api/v1/shorten", headers: unreachableHeaders, afterResponse: { res in
			XCTAssertEqual(res.status, .serviceUnavailable)
		})
	}

	func testShorten_successAndFailurePaths() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }
		app.dropboxTokenVerifier = StubVerifier(verdict: .verified(accountID: "acct"))

		let request = ShortenRequest(url: "https://www.dropbox.com/scl/fi/x/appinfo.json?rlkey=1",
									 name: "App", version: "1.0", build: "7", identifier: "com.x.y")

		app.shortLinkProvider = StubShortener(shortURL: "https://appbox.me/x1")
		try app.test(.POST, "api/v1/shorten", headers: fullAuthHeaders, beforeRequest: { req in
			try req.content.encode(request)
		}, afterResponse: { res in
			XCTAssertEqual(res.status, .ok)
			XCTAssertEqual(try res.content.decode(ShortenResponse.self).shortURL, "https://appbox.me/x1")
		})

		app.shortLinkProvider = StubShortener(shortURL: nil)
		try app.test(.POST, "api/v1/shorten", headers: fullAuthHeaders, beforeRequest: { req in
			try req.content.encode(request)
		}, afterResponse: { res in
			XCTAssertEqual(res.status, .badGateway)
			XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error.code, "shortener_unavailable")
		})
	}

	func testDropboxToken_verifiedResultIsCachedAcrossRequests() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }
		let verifier = CountingVerifier(.verified(accountID: "acct"))
		app.dropboxTokenVerifier = verifier
		app.shortLinkProvider = StubShortener(shortURL: "https://appbox.me/x1")

		let body = ShortenRequest(url: "https://www.dropbox.com/scl/fi/x/appinfo.json?rlkey=1",
								  name: "App", version: "1.0", build: "7", identifier: "com.x.y")
		for _ in 0..<3 {
			try app.test(.POST, "api/v1/shorten", headers: fullAuthHeaders, beforeRequest: { req in
				try req.content.encode(body)
			}, afterResponse: { res in
				XCTAssertEqual(res.status, .ok)
			})
		}
		XCTAssertEqual(verifier.count, 1)
	}

	func testDropboxToken_rejectionIsCached() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }
		let verifier = CountingVerifier(.rejected)
		app.dropboxTokenVerifier = verifier
		app.shortLinkProvider = StubShortener(shortURL: "https://appbox.me/x1")

		let body = ShortenRequest(url: "https://www.dropbox.com/scl/fi/x/appinfo.json",
								  name: "A", version: "1", build: "1", identifier: "id")
		for _ in 0..<2 {
			try app.test(.POST, "api/v1/shorten", headers: fullAuthHeaders, beforeRequest: { req in
				try req.content.encode(body)
			}, afterResponse: { res in
				XCTAssertEqual(res.status, .unauthorized)
			})
		}
		XCTAssertEqual(verifier.count, 1)
	}

	func testMailSend_validatesRecipientsAndMapsProviderErrors() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }
		app.dropboxTokenVerifier = StubVerifier(verdict: .verified(accountID: "acct"))
		app.mailSender = StubMailer(id: "<msg-id>", fails: false)

		func mail(to recipients: [String]) -> MailSendRequest {
			MailSendRequest(name: "App", version: "1.0", build: "7", to: recipients,
							installURL: "https://appbox.me/x1", personalMessage: nil)
		}

		try app.test(.POST, "api/v1/mail/send", headers: fullAuthHeaders, beforeRequest: { req in
			try req.content.encode(mail(to: ["not-an-email"]))
		}, afterResponse: { res in
			XCTAssertEqual(res.status, .badRequest)
			XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error.code, "invalid_recipients")
		})

		try app.test(.POST, "api/v1/mail/send", headers: fullAuthHeaders, beforeRequest: { req in
			try req.content.encode(mail(to: []))
		}, afterResponse: { res in
			XCTAssertEqual(res.status, .badRequest)
			XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error.code, "invalid_recipients")
		})
		try app.test(.POST, "api/v1/mail/send", headers: fullAuthHeaders, beforeRequest: { req in
			try req.content.encode(mail(to: Array(repeating: "a@b.com", count: 101)))
		}, afterResponse: { res in
			XCTAssertEqual(res.status, .badRequest)
			XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error.code, "invalid_recipients")
		})

		try app.test(.POST, "api/v1/mail/send", headers: fullAuthHeaders, beforeRequest: { req in
			try req.content.encode(mail(to: ["a@b.com", "c@d.io"]))
		}, afterResponse: { res in
			XCTAssertEqual(res.status, .ok)
			XCTAssertEqual(try res.content.decode(MailSendResponse.self).id, "<msg-id>")
		})

		app.mailSender = StubMailer(id: nil, fails: true)
		try app.test(.POST, "api/v1/mail/send", headers: fullAuthHeaders, beforeRequest: { req in
			try req.content.encode(mail(to: ["a@b.com"]))
		}, afterResponse: { res in
			XCTAssertEqual(res.status, .badGateway)
			XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error.code, "mail_provider_error")
		})
	}

	// MARK: - GET /api/v1/latest-version

	func testLatestVersion_requiresClientTokenAndReturnsMergedResult() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }
		app.latestVersionProvider = StubLatestVersion(result:
			LatestVersionResponse(version: "3.8.0",
								  downloadURL: "https://github.com/getappbox/x/releases/tag/3.8.0",
								  homebrewVersion: "3.7.9"))

		try app.test(.GET, "api/v1/latest-version", afterResponse: { res in
			XCTAssertEqual(res.status, .unauthorized)
		})
		try app.test(.GET, "api/v1/latest-version", headers: clientTokenHeaders, afterResponse: { res in
			XCTAssertEqual(res.status, .ok)
			let body = try res.content.decode(LatestVersionResponse.self)
			XCTAssertEqual(body.version, "3.8.0")
			XCTAssertEqual(body.homebrewVersion, "3.7.9")
			XCTAssertEqual(body.downloadURL, "https://github.com/getappbox/x/releases/tag/3.8.0")
		})
	}

	func testLatestVersion_upstreamUnavailableIs502() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }
		app.latestVersionProvider = StubLatestVersion(result: nil)
		try app.test(.GET, "api/v1/latest-version", headers: clientTokenHeaders, afterResponse: { res in
			XCTAssertEqual(res.status, .badGateway)
			XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error.code, "update_check_unavailable")
		})
	}

	// MARK: - POST /api/v1/notify

	private func notifyBody(service: String, url: String) -> NotifyRequest {
		NotifyRequest(service: service, webhookURL: url, text: "App 1.0 (7) — https://appbox.me/x")
	}

	func testNotify_requiresClientTokenAndDropboxBearer() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }
		app.notifySender = RecordingNotifier()

		try app.test(.POST, "api/v1/notify", headers: clientTokenHeaders, beforeRequest: { req in
			try req.content.encode(notifyBody(service: "slack", url: "https://hooks.slack.com/services/x"))
		}, afterResponse: { res in
			XCTAssertEqual(res.status, .unauthorized)
		})
	}

	func testNotify_forwardsToSenderOnSuccess() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }
		app.dropboxTokenVerifier = StubVerifier(verdict: .verified(accountID: "acct"))
		let notifier = RecordingNotifier()
		app.notifySender = notifier

		try app.test(.POST, "api/v1/notify", headers: fullAuthHeaders, beforeRequest: { req in
			try req.content.encode(notifyBody(service: "teams", url: "https://acme.webhook.office.com/x"))
		}, afterResponse: { res in
			XCTAssertEqual(res.status, .ok)
		})
		XCTAssertEqual(notifier.sent.count, 1)
		XCTAssertEqual(notifier.sent.first?.service, "teams")
	}

	func testNotify_providerFailureMapsTo502() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }
		app.dropboxTokenVerifier = StubVerifier(verdict: .verified(accountID: "acct"))
		app.notifySender = RecordingNotifier(fails: true)

		try app.test(.POST, "api/v1/notify", headers: fullAuthHeaders, beforeRequest: { req in
			try req.content.encode(notifyBody(service: "slack", url: "https://hooks.slack.com/services/x"))
		}, afterResponse: { res in
			XCTAssertEqual(res.status, .badGateway)
			XCTAssertEqual(try res.content.decode(APIErrorResponse.self).error.code, "notify_failed")
		})
	}

	func testNotify_webhookHostAllowlist() {
		let allowed = Environment.notifyAllowedHosts
		XCTAssertTrue(HostAllowlist.isAllowed("hooks.slack.com", suffixes: allowed))
		XCTAssertTrue(HostAllowlist.isAllowed("acme.webhook.office.com", suffixes: allowed))
		XCTAssertTrue(HostAllowlist.isAllowed("outlook.office365.com", suffixes: allowed))
		XCTAssertFalse(HostAllowlist.isAllowed("chat.googleapis.com", suffixes: allowed))
		XCTAssertFalse(HostAllowlist.isAllowed("evil.example.com", suffixes: allowed))
		XCTAssertFalse(HostAllowlist.isAllowed("hooks.slack.com.evil.io", suffixes: allowed))
	}

	/// Teams Workflows (Power Automate) replaced the retired Office 365 connectors; its webhook host
	/// depends on the tenant's Power Platform environment, and the URL carries an explicit `:443`.
	func testNotify_allowsTeamsWorkflowsWebhookHosts() throws {
		let allowed = Environment.notifyAllowedHosts
		let workflowURL = try XCTUnwrap(URL(string:
			"https://prod-27.westus.logic.azure.com:443/workflows/abc/triggers/manual/paths/invoke?sig=xyz"))
		XCTAssertEqual(workflowURL.host, "prod-27.westus.logic.azure.com", "the :443 port must not leak into the host")
		XCTAssertTrue(HostAllowlist.isAllowed(try XCTUnwrap(workflowURL.host), suffixes: allowed))

		let powerPlatformURL = try XCTUnwrap(URL(string:
			"https://default123.05.environment.api.powerplatform.com/powerautomate/automations/direct/workflows/abc"))
		XCTAssertTrue(HostAllowlist.isAllowed(try XCTUnwrap(powerPlatformURL.host), suffixes: allowed))

		XCTAssertFalse(HostAllowlist.isAllowed("logic.azure.com.evil.io", suffixes: allowed))
	}

	/// A Workflows flow answers 2xx to the retired connectors' `{"text": …}` body but posts nothing,
	/// so Teams must always receive the Adaptive Card envelope.
	func testNotify_teamsPayloadIsAdaptiveCard() throws {
		// Encoded through Vapor's content encoder — the same path `NotifyService.send` uses — so a
		// key-encoding strategy that mangled `$schema` would be caught here.
		var clientRequest = ClientRequest()
		try clientRequest.content.encode(NotifyService.TeamsPayload(text: "MyApp 1.0 (7) is ready"))
		XCTAssertEqual(clientRequest.headers.contentType, .json)

		let encoded = Data(buffer: try XCTUnwrap(clientRequest.body))
		let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])

		XCTAssertEqual(json["type"] as? String, "message")
		let attachments = try XCTUnwrap(json["attachments"] as? [[String: Any]])
		XCTAssertEqual(attachments.count, 1)
		XCTAssertEqual(attachments[0]["contentType"] as? String, "application/vnd.microsoft.card.adaptive")

		let card = try XCTUnwrap(attachments[0]["content"] as? [String: Any])
		XCTAssertEqual(card["type"] as? String, "AdaptiveCard")
		XCTAssertEqual(card["version"] as? String, "1.4")
		XCTAssertEqual(card["$schema"] as? String, "http://adaptivecards.io/schemas/adaptive-card.json")

		let body = try XCTUnwrap(card["body"] as? [[String: Any]])
		XCTAssertEqual(body[0]["type"] as? String, "TextBlock")
		XCTAssertEqual(body[0]["text"] as? String, "MyApp 1.0 (7) is ready")
		XCTAssertEqual(body[0]["wrap"] as? Bool, true)

		XCTAssertNil(json["text"], "the retired connector body must not be sent alongside the card")
	}

	// MARK: - Service internals (pure logic)

	func testYOURLSOutcome_treats400WithShortURLAsSuccess() {
		XCTAssertEqual(YOURLSService.outcome(status: 200, shortURL: "https://appbox.me/a"), .success("https://appbox.me/a"))
		XCTAssertEqual(YOURLSService.outcome(status: 400, shortURL: "https://appbox.me/a"), .success("https://appbox.me/a"))
		XCTAssertEqual(YOURLSService.outcome(status: 400, shortURL: nil), .permanentFailure)
		XCTAssertEqual(YOURLSService.outcome(status: 500, shortURL: nil), .retryable)
		XCTAssertEqual(YOURLSService.outcome(status: 200, shortURL: ""), .retryable)
	}

	func testYOURLSTargetURL_wrapsDropboxSharePath() throws {
		let target = try YOURLSService.targetURL(
			forShareURL: "https://www.dropbox.com/scl/fi/x/appinfo.json?rlkey=abc",
			base: "https://web.getappbox.com")
		XCTAssertEqual(target, "https://web.getappbox.com?url=/scl/fi/x/appinfo.json?rlkey=abc")
	}

	func testYOURLSTargetURL_rejectsNonDropboxURL() {
		XCTAssertThrowsError(try YOURLSService.targetURL(forShareURL: "https://example.com/x",
														base: "https://web.getappbox.com")) { error in
			XCTAssertEqual((error as? APIError)?.code, "invalid_url")
		}
	}

	func testYOURLSSHA512Hex_matchesKnownVector() {
		XCTAssertEqual(YOURLSService.sha512Hex("abc"),
			"ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a" +
			"2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f")
	}

	func testMailgunHTMLBody_carriesBuildDetailsAndInstallLink() {
		let base = MailSendRequest(name: "MyApp", version: "2.0", build: "42", to: ["a@b.com"],
								   installURL: "https://appbox.me/x1", personalMessage: nil)
		let plain = BuildEmailTemplate.html(for: base)
		XCTAssertTrue(plain.contains("MyApp 2.0 (42) is ready to test"))
		XCTAssertTrue(plain.contains("href=\"https://appbox.me/x1\""))
		XCTAssertTrue(plain.contains("Install MyApp"))
		XCTAssertFalse(plain.contains("Message from the developer"))

		let withMessage = MailSendRequest(name: "MyApp", version: "2.0", build: "42", to: ["a@b.com"],
										  installURL: "https://appbox.me/x1", personalMessage: "Hello QA\nSecond line")
		let personal = BuildEmailTemplate.html(for: withMessage)
		XCTAssertTrue(personal.contains("Message from the developer"))
		XCTAssertTrue(personal.contains("Hello QA<br />Second line"))
	}

	func testMailgunHTMLBody_escapesUserSuppliedValues() {
		let hostile = MailSendRequest(name: "<script>alert(1)</script>", version: "1.0 & 2.0", build: "\"42\"",
									  to: ["a@b.com"], installURL: "https://appbox.me/x?a=1&b=2",
									  personalMessage: "<b>bold</b>")
		let html = BuildEmailTemplate.html(for: hostile)
		XCTAssertFalse(html.contains("<script>"))
		XCTAssertTrue(html.contains("&lt;script&gt;"))
		XCTAssertTrue(html.contains("1.0 &amp; 2.0"))
		XCTAssertTrue(html.contains("https://appbox.me/x?a=1&amp;b=2"))
		XCTAssertTrue(html.contains("&lt;b&gt;bold&lt;/b&gt;"))
	}

	func testMailgunTextBody_includesLinkAndDeveloperMessage() {
		let base = MailSendRequest(name: "MyApp", version: "2.0", build: "42", to: ["a@b.com"],
								   installURL: "https://appbox.me/x1", personalMessage: nil)
		let plain = BuildEmailTemplate.text(for: base)
		XCTAssertTrue(plain.contains("MyApp 2.0 (42) is ready to test"))
		XCTAssertTrue(plain.contains("https://appbox.me/x1"))
		XCTAssertFalse(plain.contains("Message from the developer"))

		let withMessage = MailSendRequest(name: "MyApp", version: "2.0", build: "42", to: ["a@b.com"],
										  installURL: "https://appbox.me/x1", personalMessage: "Hello QA")
		XCTAssertTrue(BuildEmailTemplate.text(for: withMessage).contains("Message from the developer:\nHello QA"))
	}

	// MARK: - Rate limiting

	func testRateLimitStore_blocksOverLimitAndReportsRetryAfter() async {
		let store = RateLimitStore()
		let first = await store.register(key: "k", limit: 2, window: 60)
		let second = await store.register(key: "k", limit: 2, window: 60)
		let third = await store.register(key: "k", limit: 2, window: 60)
		XCTAssertNil(first)
		XCTAssertNil(second)
		XCTAssertNotNil(third)
		XCTAssertLessThanOrEqual(third ?? 999, 60)
		let other = await store.register(key: "k2", limit: 2, window: 60)
		XCTAssertNil(other)
	}

	func testRateLimitMiddleware_returns429WithRetryAfterOverLimit() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }
		let middleware = RateLimitMiddleware(bucket: "test", limit: 1, trustedProxyCount: 1)
		let next = OKResponder()

		func makeRequest() -> Request {
			let req = Request(application: app, method: .GET, url: "/x", on: app.eventLoopGroup.next())
			req.headers.replaceOrAdd(name: .xForwardedFor, value: "1.2.3.4")
			return req
		}

		let first = try await middleware.respond(to: makeRequest(), chainingTo: next)
		XCTAssertEqual(first.status, .ok)

		let second = try await middleware.respond(to: makeRequest(), chainingTo: next)
		XCTAssertEqual(second.status, .tooManyRequests)
		XCTAssertNotNil(second.headers.first(name: .retryAfter))
		XCTAssertEqual(try second.content.decode(APIErrorResponse.self).error.code, "rate_limited")
	}

	/// nginx's `$proxy_add_x_forwarded_for` appends the address it observed, so a caller-supplied hop
	/// lands on the LEFT. Keying on it would hand every request a fresh bucket.
	func testRateLimitMiddleware_spoofedLeftmostForwardedHopCannotEscapeTheBucket() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }
		let middleware = RateLimitMiddleware(bucket: "test", limit: 1, trustedProxyCount: 1)
		let next = OKResponder()

		// Same real client (appended last by the proxy), different spoofed first hop each time.
		func request(spoofed: String) -> Request {
			let req = Request(application: app, method: .GET, url: "/x", on: app.eventLoopGroup.next())
			req.headers.replaceOrAdd(name: .xForwardedFor, value: "\(spoofed), 9.9.9.9")
			return req
		}

		let first = try await middleware.respond(to: request(spoofed: "1.1.1.1"), chainingTo: next)
		XCTAssertEqual(first.status, .ok)

		let second = try await middleware.respond(to: request(spoofed: "2.2.2.2"), chainingTo: next)
		XCTAssertEqual(second.status, .tooManyRequests, "rotating the spoofable left hop must not reset the window")
	}

	func testRateLimitMiddleware_clientIPHonoursTrustedProxyCount() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }

		func request(_ forwardedFor: String?) -> Request {
			let req = Request(application: app, method: .GET, url: "/x", on: app.eventLoopGroup.next())
			if let forwardedFor {
				req.headers.replaceOrAdd(name: .xForwardedFor, value: forwardedFor)
			}
			return req
		}

		// One proxy: the rightmost hop is the address it observed.
		let onePr = RateLimitMiddleware(bucket: "b", limit: 1, trustedProxyCount: 1)
		XCTAssertEqual(onePr.clientIP(for: request("1.1.1.1, 9.9.9.9")), "9.9.9.9")
		XCTAssertEqual(onePr.clientIP(for: request("9.9.9.9")), "9.9.9.9")

		// Two proxies (e.g. CDN in front of nginx): the real client sits one further left.
		let twoPr = RateLimitMiddleware(bucket: "b", limit: 1, trustedProxyCount: 2)
		XCTAssertEqual(twoPr.clientIP(for: request("1.1.1.1, 8.8.8.8, 9.9.9.9")), "8.8.8.8")

		// Shorter chain than configured falls back to the leftmost entry rather than crashing.
		XCTAssertEqual(twoPr.clientIP(for: request("7.7.7.7")), "7.7.7.7")

		// Whitespace and empty hops are tolerated.
		XCTAssertEqual(onePr.clientIP(for: request("  1.1.1.1 ,  9.9.9.9  ")), "9.9.9.9")
		XCTAssertEqual(onePr.clientIP(for: request("1.1.1.1, , 9.9.9.9")), "9.9.9.9")

		// Zero means "nothing fronts us": ignore the header entirely.
		let direct = RateLimitMiddleware(bucket: "b", limit: 1, trustedProxyCount: 0)
		XCTAssertNotEqual(direct.clientIP(for: request("1.1.1.1, 9.9.9.9")), "1.1.1.1")
		XCTAssertNotEqual(direct.clientIP(for: request("1.1.1.1, 9.9.9.9")), "9.9.9.9")

		// No header at all: the socket address (nil in a synthetic Request) must not trap.
		XCTAssertEqual(onePr.clientIP(for: request(nil)), "unknown")
		XCTAssertEqual(onePr.clientIP(for: request("")), "unknown")
	}

	func testRateLimitMiddleware_separateClientIPsAreIndependent() async throws {
		let app = try await makeApp()
		defer { app.shutdown() }
		let middleware = RateLimitMiddleware(bucket: "test", limit: 1, trustedProxyCount: 1)
		let next = OKResponder()

		func request(ip: String) -> Request {
			let req = Request(application: app, method: .GET, url: "/x", on: app.eventLoopGroup.next())
			req.headers.replaceOrAdd(name: .xForwardedFor, value: ip)
			return req
		}

		let a = try await middleware.respond(to: request(ip: "1.1.1.1"), chainingTo: next)
		let b = try await middleware.respond(to: request(ip: "2.2.2.2"), chainingTo: next)
		XCTAssertEqual(a.status, .ok)
		XCTAssertEqual(b.status, .ok)
	}

	// MARK: - Token verdict store (memory bounds)

	func testTokenVerdictStore_expiredEntryIsNotReturnedAndIsRemoved() async {
		let store = TokenVerdictStore()
		await store.store(.init(verified: true, accountID: "acct"), for: "gone", ttl: -1)
		let verdict = await store.verdict(for: "gone")
		XCTAssertNil(verdict)
		let count = await store.entryCount()
		XCTAssertEqual(count, 0)
	}

	func testTokenVerdictStore_sweepDropsExpiredUnreadEntriesOnWrite() async {
		let store = TokenVerdictStore(maxEntries: 100, sweepInterval: 0)
		for i in 0..<10 {
			await store.store(.init(verified: false, accountID: nil), for: "expired-\(i)", ttl: -1)
		}
		await store.store(.init(verified: true, accountID: "acct"), for: "live", ttl: 600)
		let count = await store.entryCount()
		XCTAssertEqual(count, 1)
		let live = await store.verdict(for: "live")
		XCTAssertEqual(live?.verified, true)
	}

	func testTokenVerdictStore_capEvictsInsteadOfGrowing() async {
		let store = TokenVerdictStore(maxEntries: 3, sweepInterval: 3600)
		await store.store(.init(verified: true, accountID: "a"), for: "a", ttl: 10)
		await store.store(.init(verified: true, accountID: "b"), for: "b", ttl: 600)
		await store.store(.init(verified: true, accountID: "c"), for: "c", ttl: 600)
		await store.store(.init(verified: true, accountID: "d"), for: "d", ttl: 600)
		let count = await store.entryCount()
		XCTAssertEqual(count, 3)
		let evicted = await store.verdict(for: "a")
		XCTAssertNil(evicted)
		let kept = await store.verdict(for: "d")
		XCTAssertEqual(kept?.accountID, "d")
	}
}
