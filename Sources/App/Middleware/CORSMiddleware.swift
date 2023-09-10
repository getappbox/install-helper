//
//  File.swift
//  
//
//  Created by Vineet Choudhary on 10/09/23.
//

import Vapor

extension CORSMiddleware {
	static var current: CORSMiddleware {
		let corsConfiguration = CORSMiddleware.Configuration(
			allowedOrigin: .any(Environment.corsAllowList),
			allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
			allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
		)

		return CORSMiddleware(configuration: corsConfiguration)
	}
}
