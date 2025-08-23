//
//  File.swift
//  install-helper
//
//  Created by Vineet Choudhary on 03/08/25.
//

import Vapor

struct TurnstileController: RouteCollection {
	let turnstileSecretKey: String
	let turnstileVerify = "https://challenges.cloudflare.com/turnstile/v0/siteverify"

	struct VerifyReqParams: Content {
		let response: String
	}

	struct TurnstileVerifyRequest: Content {
		let secret: String
		let response: String
		let ip: String?
	}

	struct TurnstileVerifyResponse: Content {
		let result: Bool

		enum CodingKeys: String, CodingKey {
			case result = "success"
		}
	}

	init() {
		turnstileSecretKey = Environment.turnstileSecretKey
	}

	func boot(routes: Vapor.RoutesBuilder) throws {
		let reCaptcha = routes.grouped("turnstile")
		reCaptcha.get(.init(), use: verify(req:))
	}

	func verify(req: Request) throws -> EventLoopFuture<TurnstileVerifyResponse> {
		let response = try req.query.decode(VerifyReqParams.self).response
		let remoteIP = req.remoteAddress?.ipAddress ?? req.headers.first(name: "CF-Connecting-IP")

		let requestData = TurnstileVerifyRequest(secret: turnstileSecretKey, response: response, ip: remoteIP)

		return req.client.post(.init(stringLiteral: turnstileVerify)) { req in
			try req.content.encode(requestData, as: .formData)
		}.flatMapThrowing { response in
			return try response.content.decode(TurnstileVerifyResponse.self)
		}
	}
}
