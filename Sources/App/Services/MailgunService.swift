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
	static let emailTemplate = "<!DOCTYPE html> <html> <body> "
		+ "<h1>$1 $2 ($3) for iOS is ready to test.</h1> "
		+ "<h2><a href=\"$4\">$4</a></h2> "
		+ "<p>To test this app, open above url on your iOS device and install the app.</p> "
		+ "$5 "
		+ "<p>This is an auto-generated mail by <a href=\"https://getappbox.com\">AppBox - Build, Test and Distribute iOS Apps</a>.</p> "
		+ "</body> </html>"
	static let personalMessageTemplate = "<hr /> <p>Message from Developer : <br /> $5</p> <hr />"

	private struct MailgunForm: Content {
		let from: String
		let to: String
		let subject: String
		let html: String
	}

	func send(_ mail: MailSendRequest, on req: Request) async throws -> String? {
		guard let apiKey = Environment.mailgunAPIKey, !apiKey.isEmpty else {
			throw APIError(status: .internalServerError, code: "misconfigured", message: "Mail is not configured.")
		}

		let subject = "\(mail.name) \(mail.version) (\(mail.build)) is ready to test - AppBox"
		let form = MailgunForm(
			from: Environment.mailgunFrom,
			to: mail.to.joined(separator: ","),
			subject: subject,
			html: Self.htmlBody(for: mail))

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

	static func htmlBody(for mail: MailSendRequest) -> String {
		var body = emailTemplate
		body = body.replacingOccurrences(of: "$1", with: mail.name)
		body = body.replacingOccurrences(of: "$2", with: mail.version)
		body = body.replacingOccurrences(of: "$3", with: mail.build)
		body = body.replacingOccurrences(of: "$4", with: mail.installURL)
		if let personalMessage = mail.personalMessage, !personalMessage.isEmpty {
			let developerBlock = personalMessageTemplate.replacingOccurrences(of: "$5", with: personalMessage)
			body = body.replacingOccurrences(of: "$5", with: developerBlock)
		} else {
			body = body.replacingOccurrences(of: "$5", with: "")
		}
		return body
	}
}
