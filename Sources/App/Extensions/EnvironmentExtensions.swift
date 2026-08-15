//
//  EnvironmentExtensions.swift
//
//
//  Created by Vineet Choudhary on 10/09/23.
//

import Vapor

/// Typed accessors for every environment variable the service reads.
extension Environment {
	// MARK: - API authentication

	/// Static shared secret the AppBox client sends as `X-AppBox-Client-Token`.
	static var appboxClientToken: String? { Self.get("APPBOX_CLIENT_TOKEN") }

	// MARK: - Dropbox

	/// The public OAuth client_id served by `GET /api/v1/config`.
	static var dropboxAppKey: String? { Self.get("DROPBOX_APP_KEY") }

	/// How long a verified Dropbox token stays cached before re-verification (seconds).
	static var dropboxTokenCacheTTLSeconds: Int {
		Self.get("DROPBOX_TOKEN_CACHE_TTL_SECONDS").flatMap(Int.init) ?? 600
	}

	// MARK: - Mailgun

	static var mailgunAPIKey: String? { Self.get("MAILGUN_API_KEY") }
	static var mailgunDomain: String { Self.get("MAILGUN_DOMAIN") ?? "mail.getappbox.com" }
	static var mailgunFrom: String { Self.get("MAILGUN_FROM") ?? "AppBox Build <build@getappbox.com>" }

	// MARK: - YOURLS short links

	static var yourlsAPIURL: String { Self.get("YOURLS_API_URL") ?? "https://appbox.me/yourls-api.php" }
	static var yourlsSignatureSecret: String? { Self.get("YOURLS_SIGNATURE_SECRET") }
	/// The installer web page the short link ultimately points at.
	static var shortlinkTargetBase: String { Self.get("SHORTLINK_TARGET_BASE") ?? "https://web.getappbox.com" }

	// MARK: - CORS proxy

	/// Host suffixes `/cors?url=` may proxy to (exact host or any subdomain).
	static var corsProxyAllowedHosts: [String] {
		hostList("CORS_PROXY_ALLOWED_HOSTS", default: "dropbox.com,dropboxusercontent.com,getappbox.com")
	}

	/// Upper bound (bytes) on a single proxied upstream response body.
	static var proxyMaxBodyBytes: Int {
		Self.get("PROXY_MAX_BODY_BYTES").flatMap(Int.init) ?? 4 * 1024 * 1024
	}

	// MARK: - Update check (GET /api/v1/latest-version)

	static var githubLatestReleaseURL: String {
		Self.get("GITHUB_LATEST_RELEASE_URL")
			?? "https://api.github.com/repos/getappbox/AppBox-iOSAppsWirelessInstallation/releases/latest"
	}
	static var homebrewCaskURL: String {
		Self.get("HOMEBREW_CASK_URL") ?? "https://formulae.brew.sh/api/cask/appbox.json"
	}
	/// How long the merged latest-version result is cached before re-fetching upstream (seconds).
	static var updateCacheTTLSeconds: Int {
		Self.get("UPDATE_CACHE_TTL_SECONDS").flatMap(Int.init) ?? 3600
	}

	// MARK: - Notify (POST /api/v1/notify)

	/// Host suffixes `/api/v1/notify` may POST an incoming webhook to.
	static var notifyAllowedHosts: [String] {
		hostList("NOTIFY_ALLOWED_HOSTS",
				 default: "hooks.slack.com,office.com,office365.com,logic.azure.com,powerplatform.com")
	}

	// MARK: - Rate limiting

	/// How many reverse proxies sit in front of this service and append to `X-Forwarded-For`.
	static var trustedProxyCount: Int {
		max(0, Self.get("TRUSTED_PROXY_COUNT").flatMap(Int.init) ?? 1)
	}

	private static func hostList(_ key: String, default defaultValue: String) -> [String] {
		let raw = Self.get(key) ?? defaultValue
		return raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
	}

	// MARK: - Boot check

	/// The `/api/v1` secret env vars that are missing/empty.
	static func missingAPIConfiguration() -> [String] {
		var missing: [String] = []
		if appboxClientToken?.isEmpty != false { missing.append("APPBOX_CLIENT_TOKEN") }
		if dropboxAppKey?.isEmpty != false { missing.append("DROPBOX_APP_KEY") }
		if mailgunAPIKey?.isEmpty != false { missing.append("MAILGUN_API_KEY") }
		if yourlsSignatureSecret?.isEmpty != false { missing.append("YOURLS_SIGNATURE_SECRET") }
		return missing
	}
}
