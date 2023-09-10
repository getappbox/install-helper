//
//  ClientResponseExtensions.swift
//  
//
//  Created by Vineet Choudhary on 10/09/23.
//

import Vapor

private enum CrosHeaders: String, CaseIterable {
	case accessControlAllowOrigin = "Access-Control-Allow-Origin"
	case accessControlAllowCredentials = "Access-Control-Allow-Credentials"
	case accessControlExposeHeaders = "Access-Control-Expose-Headers"
	case accessControlMaxAge = "Access-Control-Max-Age"
	case accessControlAllowMethods = "Access-Control-Allow-Methods"
	case accessControlAllowHeaders = "Access-Control-Allow-Headers"

	//other headers
	case contentSecurityPolicy = "Content-Security-Policy"
	case strictTransportSecurity = "Strict-Transport-Security"
	case setCookie = "Set-Cookie"
}

extension ClientResponse {
	mutating func removeCrosHeaders() -> ClientResponse {
		CrosHeaders.allCases.forEach { crosHeader in
			self.headers.remove(name: crosHeader.rawValue)
		}

		return self
	}
}
