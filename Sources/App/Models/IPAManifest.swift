//
//  IPAManifest.swift
//  install-helper
//
//  Created by Vineet Choudhary on 14/09/25.
//

import Foundation

struct IPAManifest: Codable {
	var items: [Item]

	struct Item: Codable {
		var assets: [Asset]
		var metadata: Metadata?

		struct Asset: Codable {
			var kind: String
			var url: String
		}

		struct Metadata: Codable {
			var bundleIdentifier: String?
			var bundleVersion: String?
			var kind: String?
			var title: String?

			private enum CodingKeys: String, CodingKey {
				case bundleIdentifier = "bundle-identifier"
				case bundleVersion = "bundle-version"
				case kind
				case title
			}
		}

	}

}

