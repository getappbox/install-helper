//
//  DropboxResponseValidation.swift
//
//
//  Created by Vineet Choudhary on 07/09/26.
//

import Vapor
import SwiftSoup

/// Validates the response Dropbox returned for a proxied share link.
enum DropboxResponseValidation {
	/// Maps a known Dropbox notice page onto an HTTP status, and reports the page title of any other
	/// HTML the caller was served instead of the file it asked for.
	///
	/// - Parameters:
	///   - response: the proxied upstream response.
	///   - subject: what was being fetched, used to phrase the not-found reason (e.g. `"App info"`).
	/// - Returns: the notice page's title when Dropbox answered with an HTML page the caller may not be
	///   able to use, or `nil` when the response is not HTML i.e. when it is the file itself.
	@discardableResult
	static func validate(_ response: ClientResponse, describing subject: String) throws -> String? {
		guard
			response.headers.contentType == .html,
			let body = response.body,
			let htmlData = body.getData(at: 0, length: body.readableBytes),
			let htmlString = String(data: htmlData, encoding: .utf8) else {
			return nil
		}

		let title = try SwiftSoup.parse(htmlString).title().lowercased()
		if title.contains("deleted") {
			throw Abort(.notFound, reason: "\(subject) not found on Dropbox.")
		} else if title.contains("invalid link") {
			throw Abort(.notFound, reason: "\(subject) link is not valid on Dropbox.")
		} else if title.contains("link temporarily disabled") {
			throw Abort(.locked, reason: "Share link is temporarily disabled by Dropbox.")
		}

		return title
	}
}
