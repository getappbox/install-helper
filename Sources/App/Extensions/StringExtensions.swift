//
//  StringExtensions.swift
//  
//
//  Created by Vineet Choudhary on 10/09/23.
//

import Vapor

extension String {
	func base64Decoed() -> String? {
		guard let data = Data(base64Encoded: self) else {
			return nil
		}

		return String(data: data, encoding: .utf8)
	}
}
