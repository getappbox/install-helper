//
//  DropboxPathValidation.swift
//
//
//  Created by Vineet Choudhary on 06/07/26.
//

import Vapor

/// Validates a client-supplied Dropbox share path before it is proxied.
enum DropboxPathValidation {
	static let maxPathLength = 1024

	static func validate(_ path: String) throws {
		guard path.count <= maxPathLength else {
			throw Abort(.badRequest, reason: "Path too long.")
		}
		guard path.hasPrefix("/scl/") || path.hasPrefix("/s/") else {
			throw Abort(.badRequest, reason: "Unsupported Dropbox path.")
		}
		guard !path.components(separatedBy: "/").contains("..") else {
			throw Abort(.badRequest, reason: "Invalid path.")
		}
	}
}
