//
//  RateLimitMiddleware.swift
//
//
//  Created by Vineet Choudhary on 06/07/26.
//

import Vapor

/// Fixed-window request counter. Each `RateLimitMiddleware` owns one, so buckets never share state.
actor RateLimitStore {
	private var windows: [String: (start: Date, count: Int)] = [:]
	private var lastSweep = Date()

	/// Count one request against `key`; returns nil when allowed, else seconds remaining in the window.
	func register(key: String, limit: Int, window: TimeInterval) -> Int? {
		let now = Date()
		sweepIfNeeded(now: now, window: window)

		if let entry = windows[key], now.timeIntervalSince(entry.start) < window {
			guard entry.count < limit else {
				return max(1, Int((window - now.timeIntervalSince(entry.start)).rounded(.up)))
			}
			windows[key] = (entry.start, entry.count + 1)
		} else {
			windows[key] = (now, 1)
		}
		return nil
	}

	/// Drop expired windows once a minute so the dictionary can't grow unbounded.
	private func sweepIfNeeded(now: Date, window: TimeInterval) {
		guard now.timeIntervalSince(lastSweep) > 60 else { return }
		lastSweep = now
		windows = windows.filter { now.timeIntervalSince($0.value.start) < window }
	}
}

/// Per-route fixed-window rate limiting keyed by client IP. Responds 429 with `Retry-After`.
struct RateLimitMiddleware: AsyncMiddleware {
	let bucket: String
	let limit: Int
	let window: TimeInterval
	let trustedProxyCount: Int
	let store: RateLimitStore

	init(bucket: String, limit: Int, per window: TimeInterval = 60,
		 trustedProxyCount: Int = Environment.trustedProxyCount,
		 store: RateLimitStore = RateLimitStore()) {
		self.bucket = bucket
		self.limit = limit
		self.window = window
		self.trustedProxyCount = trustedProxyCount
		self.store = store
	}

	func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
		let key = "\(bucket):\(clientIP(for: request))"
		if let retryAfter = await store.register(key: key, limit: limit, window: window) {
			let response = Response(status: .tooManyRequests)
			response.headers.replaceOrAdd(name: .retryAfter, value: "\(retryAfter)")
			try response.content.encode(APIErrorResponse(code: "rate_limited", message: "Too many requests. Try again later."))
			return response
		}
		return try await next.respond(to: request)
	}

	/// The client address `trustedProxyCount` hops in from the right of `X-Forwarded-For`, else the socket address.
	func clientIP(for request: Request) -> String {
		let socketAddress = request.remoteAddress?.ipAddress ?? "unknown"
		guard trustedProxyCount > 0 else { return socketAddress }

		let hops = (request.headers.first(name: .xForwardedFor) ?? "")
			.split(separator: ",")
			.map { $0.trimmingCharacters(in: .whitespaces) }
			.filter { !$0.isEmpty }
		guard !hops.isEmpty else { return socketAddress }

		return hops[max(0, hops.count - trustedProxyCount)]
	}
}
