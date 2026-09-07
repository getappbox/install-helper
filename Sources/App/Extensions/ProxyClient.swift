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
			let filteredHeaders = ProxyResponseHeaders.filtered(response.headers, bodyByteCount: response.body?.readableBytes ?? 0)
			return ClientResponse(status: response.status, headers: filteredHeaders, body: response.body)
		} catch is ResponseAccumulator.ResponseTooBigError {
			throw Abort(.badGateway, reason: "Upstream response exceeds the \(maxBytes) byte proxy limit.")
		}
	}
}

/// Decides which upstream response headers a proxied response keeps.
enum ProxyResponseHeaders {
	/// Everything outside this list is dropped.
	static let forwarded: Set<String> = ["content-type", "content-encoding", "content-disposition", "cache-control"]

	/// The upstream headers worth keeping, with `Content-Length` restated from the body we actually hold.
	static func filtered(_ upstream: HTTPHeaders, bodyByteCount: Int) -> HTTPHeaders {
		var headers = HTTPHeaders()
		for (name, value) in upstream where forwarded.contains(name.lowercased()) {
			headers.add(name: name, value: value)
		}
		headers.replaceOrAdd(name: .contentLength, value: "\(bodyByteCount)")
		return headers
	}
}
