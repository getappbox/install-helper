//
//  ProxyClient.swift
//
//
//  Created by Vineet Choudhary on 13/07/26.
//

import AsyncHTTPClient
import Vapor

extension Request {
	/// GET an upstream URL for the proxy routes, refusing to buffer more than `Environment.proxyMaxBodyBytes` of response body.
	func proxyGet(_ urlString: String) async throws -> ClientResponse {
		let clientRequest: HTTPClient.Request
		do {
			clientRequest = try HTTPClient.Request(url: urlString, method: .GET)
		} catch {
			throw Abort(.badRequest, reason: "Invalid upstream URL.")
		}

		let maxBytes = Environment.proxyMaxBodyBytes
		let accumulator = ResponseAccumulator(request: clientRequest, maxBodySize: maxBytes)
		do {
			let response = try await application.http.client.shared
				.execute(request: clientRequest, delegate: accumulator, deadline: nil, logger: logger)
				.futureResult
				.get()
			return ClientResponse(status: response.status, headers: response.headers, body: response.body)
		} catch is ResponseAccumulator.ResponseTooBigError {
			throw Abort(.badGateway, reason: "Upstream response exceeds the \(maxBytes) byte proxy limit.")
		}
	}
}
