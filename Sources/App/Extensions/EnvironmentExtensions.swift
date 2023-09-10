//
//  EnvironmentExtensions.swift
//  
//
//  Created by Vineet Choudhary on 10/09/23.
//

import Vapor

extension Environment {
	static let reCaptchaKey = Self.get("RECAPTCHA")!.base64Decoed()!

	// MARK: - Hardcoded
	static let corsAllowList = ["https://web.getappbox.com, https://web2.getappbox.com, http://localhost:8080"]
}
