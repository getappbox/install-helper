//
//  HostAllowlist.swift
//
//
//  Created by Vineet Choudhary on 06/07/26.
//

import Foundation

/// Suffix-based host allowlisting used by the `/cors` proxy and `/api/v1/notify`.
enum HostAllowlist {
	static func isAllowed(_ host: String, suffixes: [String]) -> Bool {
		let lowercased = host.lowercased()
		return suffixes.contains { suffix in
			let s = suffix.lowercased()
			return lowercased == s || lowercased.hasSuffix("." + s)
		}
	}
}
