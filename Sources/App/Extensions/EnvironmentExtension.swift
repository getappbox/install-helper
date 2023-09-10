//
//  EnvironmentExtension.swift
//  
//
//  Created by Vineet Choudhary on 10/09/23.
//

import Vapor

extension Environment {
	static let reCaptchaKey = Self.get("RECAPTCHA")!.base64Decoed()!
}
