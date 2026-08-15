//
//  NotifyController.swift
//
//
//  Created by Vineet Choudhary on 06/07/26.
//

import Vapor

/// `POST /api/v1/notify` — relay an upload notification to a Slack/Teams incoming webhook.
struct NotifyController: RouteCollection {
	func boot(routes: Vapor.RoutesBuilder) throws {
		routes.post("notify", use: notify(req:))
	}

	func notify(req: Request) async throws -> Response {
		let body: NotifyRequest
		do {
			body = try req.content.decode(NotifyRequest.self)
		} catch {
			return APIErrorResponse.response(status: .badRequest, code: "invalid_body",
											 message: "Expected JSON with service, webhookURL, text.")
		}
		do {
			try await req.application.notifySender.send(body, on: req)
			return Response(status: .ok)
		} catch let apiError as APIError {
			return APIErrorResponse.response(status: apiError.status, code: apiError.code, message: apiError.message)
		}
	}
}
