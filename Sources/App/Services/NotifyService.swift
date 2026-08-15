//
//  NotifyService.swift
//
//
//  Created by Vineet Choudhary on 06/07/26.
//

import Vapor

/// Seam for the webhook POST so tests can stub it.
protocol NotifySending {
	func send(_ request: NotifyRequest, on req: Request) async throws
}

extension Application {
	private struct NotifySenderKey: StorageKey {
		typealias Value = NotifySending
	}

	var notifySender: NotifySending {
		get { storage[NotifySenderKey.self] ?? NotifyService() }
		set { storage[NotifySenderKey.self] = newValue }
	}
}

/// Posts an upload notification to a Slack or Microsoft Teams incoming webhook.
struct NotifyService: NotifySending {
	static let slackIconURL = "https://getappbox.com/images/AppBoxIcon.png"

	private struct SlackPayload: Content { let username: String; let icon_url: String; let text: String }

	/// The Adaptive Card envelope Microsoft's Workflows (Power Automate) webhooks expect. The retired
	/// Office 365 connectors accept this shape too, so it's sent to every Teams webhook — the older
	/// `{"text": …}` connector body is silently dropped by a Workflows flow.
	struct TeamsPayload: Content {
		struct TextBlock: Content {
			var type = "TextBlock"
			var text: String
			var wrap = true
		}

		struct Card: Content {
			var schema = "http://adaptivecards.io/schemas/adaptive-card.json"
			var type = "AdaptiveCard"
			var version = "1.4"
			var body: [TextBlock]

			enum CodingKeys: String, CodingKey {
				case schema = "$schema"
				case type, version, body
			}
		}

		struct Attachment: Content {
			var contentType = "application/vnd.microsoft.card.adaptive"
			var content: Card
		}

		var type = "message"
		var attachments: [Attachment]

		init(text: String) {
			attachments = [Attachment(content: Card(body: [TextBlock(text: text)]))]
		}
	}

	func send(_ request: NotifyRequest, on req: Request) async throws {
		guard let url = URL(string: request.webhookURL), url.scheme == "https", let host = url.host,
			  HostAllowlist.isAllowed(host, suffixes: Environment.notifyAllowedHosts) else {
			throw APIError(status: .forbidden, code: "webhook_not_allowed",
						   message: "The webhook URL host is not permitted.")
		}

		let uri = URI(string: request.webhookURL)
		let response: ClientResponse
		do {
			switch request.service.lowercased() {
			case "slack":
				let payload = SlackPayload(username: "AppBox", icon_url: Self.slackIconURL, text: request.text)
				response = try await req.client.post(uri) { try $0.content.encode(payload) }
			case "teams":
				let payload = TeamsPayload(text: request.text)
				response = try await req.client.post(uri) { try $0.content.encode(payload) }
			default:
				throw APIError(status: .badRequest, code: "invalid_service",
							   message: "service must be \"slack\" or \"teams\".")
			}
		} catch let apiError as APIError {
			throw apiError
		} catch {
			throw APIError(status: .badGateway, code: "notify_failed", message: "Webhook request failed.")
		}

		guard (200..<300).contains(response.status.code) else {
			throw APIError(status: .badGateway, code: "notify_failed",
						   message: "Webhook responded \(response.status.code).")
		}
	}
}
