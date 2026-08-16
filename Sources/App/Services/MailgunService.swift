//
//  MailgunService.swift
//
//
//  Created by Vineet Choudhary on 06/07/26.
//

import Vapor

/// Seam for the mail provider so tests can stub it.
protocol MailSending {
	/// Sends the build email; returns Mailgun's message id when it provides one.
	func send(_ mail: MailSendRequest, on req: Request) async throws -> String?
}

extension Application {
	private struct MailSenderKey: StorageKey {
		typealias Value = MailSending
	}

	var mailSender: MailSending {
		get { storage[MailSenderKey.self] ?? MailgunService() }
		set { storage[MailSenderKey.self] = newValue }
	}
}

/// Sends the "build is ready to test" email via Mailgun.
struct MailgunService: MailSending {
	private struct MailgunForm: Content {
		let from: String
		let to: String
		let subject: String
		let html: String
		let text: String
	}

	func send(_ mail: MailSendRequest, on req: Request) async throws -> String? {
		guard let apiKey = Environment.mailgunAPIKey, !apiKey.isEmpty else {
			throw APIError(status: .internalServerError, code: "misconfigured", message: "Mail is not configured.")
		}

		let form = MailgunForm(
			from: Environment.mailgunFrom,
			to: mail.to.joined(separator: ","),
			subject: BuildEmailTemplate.subject(for: mail),
			html: BuildEmailTemplate.html(for: mail),
			text: BuildEmailTemplate.text(for: mail))

		var headers = HTTPHeaders()
		headers.basicAuthorization = BasicAuthorization(username: "api", password: apiKey)

		let uri = URI(string: "https://api.mailgun.net/v3/\(Environment.mailgunDomain)/messages")
		let response: ClientResponse
		do {
			response = try await req.client.post(uri, headers: headers) { clientRequest in
				try clientRequest.content.encode(form, as: .urlEncodedForm)
			}
		} catch {
			throw APIError(status: .badGateway, code: "mail_provider_error", message: "Mail provider unreachable.")
		}

		guard (200..<300).contains(response.status.code) else {
			throw APIError(status: .badGateway, code: "mail_provider_error",
						   message: "Mail provider responded \(response.status.code).")
		}
		return try? response.content.get(String.self, at: "id")
	}

}
