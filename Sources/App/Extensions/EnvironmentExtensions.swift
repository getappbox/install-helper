//
//  EnvironmentExtensions.swift
//  
//
//  Created by Vineet Choudhary on 10/09/23.
//

import Vapor

extension Environment {
	// Fetch a required environment variable and attempt base64 decode; fall back to raw value.
	// Throws a fatalError with a clear message if the variable is missing.
	private static func requiredDecoded(_ key: String) -> String {
		guard let raw = Self.get(key) else {
			fatalError("Missing required environment variable: \(key). Ensure it's set in the process or .env files.")
		}
		return raw
	}

	static let reCaptchaKey = requiredDecoded("RECAPTCHA")
	static let turnstileSiteKey = requiredDecoded("TURNSTILE_SITE")
	static let turnstileSecretKey = requiredDecoded("TURNSTILE_SECRET")

	// MARK: - Hardcoded
	static let corsAllowList = ["https://web.getappbox.com, https://web2.getappbox.com, http://localhost:8080"]
}
