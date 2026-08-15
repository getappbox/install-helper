//
//  APIError.swift
//
//
//  Created by Vineet Choudhary on 06/07/26.
//

import Vapor

/// Thrown by the API services; controllers map it onto the `APIErrorResponse` envelope.
struct APIError: Error {
	let status: HTTPResponseStatus
	let code: String
	let message: String
}
