//
//  MailController.swift
//
//
//  Created by Vineet Choudhary on 06/07/26.
//

import Vapor

/// `POST /api/v1/mail/send` — send the "build is ready to test" email.
struct MailController: RouteCollection {
	static let maxRecipients = 100
	private static let emailPattern = "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"

	func boot(routes: Vapor.RoutesBuilder) throws {
		let mail = routes.grouped("mail")
		mail.post("send", use: send(req:))
	}

	func send(req: Request) async throws -> Response {
		let body: MailSendRequest
		do {
			body = try req.content.decode(MailSendRequest.self)
		} catch {
			return APIErrorResponse.response(status: .badRequest, code: "invalid_body",
											 message: "Expected JSON with name, version, build, to, installURL.")
		}

		guard (1...Self.maxRecipients).contains(body.to.count),
			  body.to.allSatisfy({ $0.range(of: Self.emailPattern, options: .regularExpression) != nil }) else {
			return APIErrorResponse.response(status: .badRequest, code: "invalid_recipients",
											 message: "Provide 1–\(Self.maxRecipients) valid email addresses.")
		}

		do {
			let id = try await req.application.mailSender.send(body, on: req)
			let response = Response(status: .ok)
			try response.content.encode(MailSendResponse(id: id))
			return response
		} catch let apiError as APIError {
			return APIErrorResponse.response(status: apiError.status, code: apiError.code, message: apiError.message)
		}
	}
}
