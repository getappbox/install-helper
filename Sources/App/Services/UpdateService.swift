//
//  UpdateService.swift
//
//
//  Created by Vineet Choudhary on 06/07/26.
//

import Vapor

/// Seam for the latest-version lookup so tests can stub the upstream fetch.
protocol LatestVersionProviding {
	func latestVersion(on req: Request) async throws -> LatestVersionResponse
}

extension Application {
	private struct LatestVersionProviderKey: StorageKey {
		typealias Value = LatestVersionProviding
	}

	var latestVersionProvider: LatestVersionProviding {
		get { storage[LatestVersionProviderKey.self] ?? UpdateService() }
		set { storage[LatestVersionProviderKey.self] = newValue }
	}
}

/// Resolves the latest AppBox version by merging the GitHub release and Homebrew cask APIs.
struct UpdateService: LatestVersionProviding {
	private static let cacheKey = "latest-version"

	private struct GitHubRelease: Content { let tag_name: String; let html_url: String }
	private struct HomebrewCask: Content { let version: String }

	func latestVersion(on req: Request) async throws -> LatestVersionResponse {
		if let cached = try? await req.cache.get(Self.cacheKey, as: LatestVersionResponse.self) {
			return cached
		}

		var headers = HTTPHeaders()
		headers.add(name: .userAgent, value: "AppBox-install-helper")

		async let releaseTask = fetchGitHub(on: req, headers: headers)
		async let homebrewTask = fetchHomebrew(on: req, headers: headers)
		let release = await releaseTask
		let homebrewVersion = await homebrewTask

		guard let release else {
			throw APIError(status: .badGateway, code: "update_check_unavailable",
						   message: "Could not reach the release feed.")
		}

		let result = LatestVersionResponse(version: release.tag_name,
										   downloadURL: release.html_url,
										   homebrewVersion: homebrewVersion)
		try? await req.cache.set(Self.cacheKey, to: result,
								 expiresIn: .seconds(Environment.updateCacheTTLSeconds))
		return result
	}

	private func fetchGitHub(on req: Request, headers: HTTPHeaders) async -> GitHubRelease? {
		guard let response = try? await req.client.get(URI(string: Environment.githubLatestReleaseURL), headers: headers),
			  response.status == .ok else { return nil }
		return try? response.content.decode(GitHubRelease.self)
	}

	private func fetchHomebrew(on req: Request, headers: HTTPHeaders) async -> String? {
		guard let response = try? await req.client.get(URI(string: Environment.homebrewCaskURL), headers: headers),
			  response.status == .ok else { return nil }
		return (try? response.content.decode(HomebrewCask.self))?.version
	}
}
