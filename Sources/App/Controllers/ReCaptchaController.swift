//
//  ReCaptchaController.swift
//  
//
//  Created by Vineet Choudhary on 10/09/23.
//

import Vapor

struct ReCaptchaController: RouteCollection {
	let reCaptchaKey: String
	let recaptchVerifyURL = "https://recaptcha.google.com/recaptcha/api/siteverify"

	struct VerifyReqParams: Content {
		let response: String
	}

	struct ReVerifyRequest: Content {
		let secret: String
		let response: String
	}

	struct ReVerifyResponse: Content {
		let result: Bool
		let score: Double?

		enum CodingKeys: String, CodingKey {
			case result = "success"
			case score
		}
	}

	init() {
		reCaptchaKey = Environment.reCaptchaKey
	}

	func boot(routes: Vapor.RoutesBuilder) throws {
		let reCaptcha = routes.grouped("recaptcha")
		reCaptcha.get(.init(), use: verify(req:))
	}

	func verify(req: Request) throws -> EventLoopFuture<ReVerifyResponse> {
		let response = try req.query.decode(VerifyReqParams.self).response

		let requestData = ReVerifyRequest(
			secret: reCaptchaKey,
			response: response)

		return req.client.post(.init(stringLiteral: recaptchVerifyURL)) { req in
			try req.content.encode(requestData, as: .formData)
		}.flatMapThrowing { response in
			return try response.content.decode(ReVerifyResponse.self)
		}
	}
}
