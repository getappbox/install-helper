//
//  InstallController.swift
//  
//
//  Created by Vineet Choudhary on 10/09/23.
//

import Vapor

struct InstallController: RouteCollection {
	func boot(routes: Vapor.RoutesBuilder) throws {
		let install = routes.grouped("install")
		install.get(.catchall, use: installManifest(req:))
	}

	func installManifest(req: Request) async throws -> ClientResponse {
		let pathComponents = req.url.path.components(separatedBy: "/")
		var path = ""
		var manifestURLQueryItems = [URLQueryItem]()
		manifestURLQueryItems.append(.init(name: "dl", value: "1"))
		for pathComponent in pathComponents {
			if pathComponent.isEmpty || pathComponent == "install" {
				continue
			} else if pathComponent.hasPrefix("queryparam-") {
				let queryParam = pathComponent.replacingOccurrences(of: "queryparam-", with: "").components(separatedBy: "-value-")
				guard queryParam.count == 2 else {
					continue
				}
				manifestURLQueryItems.append(.init(name: queryParam[0], value: queryParam[1]))
			} else {
				path.append("/\(pathComponent)")
			}
		}
		var manifestURLComponents = URLComponents()
		manifestURLComponents.scheme = "https"
		manifestURLComponents.host = "www.dropbox.com"
		manifestURLComponents.path = path
		manifestURLComponents.queryItems = manifestURLQueryItems

		guard let manifestURLString = manifestURLComponents.string else {
			throw Abort(.badRequest, reason: "Invalid URL.")
		}

		var manifestResponse = try await req.client.get(.init(stringLiteral: manifestURLString))

		// ensure we got a valid response with body
		guard manifestResponse.status == .ok, let body = manifestResponse.body else {
			return manifestResponse
		}

		// modify manifest body to update asset URL
		guard let updatedBody = updatedManifestBody(from: body, logger: req.logger) else {
			return manifestResponse
		}

		manifestResponse.body = updatedBody
		manifestResponse.headers.replaceOrAdd(name: .contentLength, value: "\(updatedBody.readableBytes)")
		manifestResponse.headers.replaceOrAdd(name: .contentType, value: "application/xml")
		return manifestResponse
	}

	/// Update manifest body to modify asset URL to ensure direct download from Dropbox
	private func updatedManifestBody(from buffer: ByteBuffer, logger: Logger) -> ByteBuffer? {
		guard let data = buffer.getData(at: 0, length: buffer.readableBytes) else {
			return nil
		}

		do {
			let decoder = PropertyListDecoder()
			let ipaManifest = try decoder.decode(IPAManifest.self, from: data)
			guard var ipaItem = ipaManifest.items.first, var ipaAsset = ipaItem.assets.first else {
				return nil
			}

			guard var ipaURLComponents = URLComponents(string: ipaAsset.url) else {
				return nil
			}

			if ipaURLComponents.host == "dl.dropboxusercontent.com" {
				ipaURLComponents.host = "www.dropbox.com"
			}

			var queryItems = ipaURLComponents.queryItems ?? []
			let dlQueryItem = URLQueryItem(name: "dl", value: "1")
			if let index = queryItems.firstIndex(where: { $0.name == "dl" }) {
				queryItems[index] = dlQueryItem
			} else {
				queryItems.append(dlQueryItem)
			}
			ipaURLComponents.queryItems = queryItems

			guard let newIPAURL = ipaURLComponents.string else {
				return nil
			}

			ipaAsset.url = newIPAURL

			// Rebuild updated manifest
			var updatedIPAManifest = ipaManifest
			ipaItem.assets[0] = ipaAsset
			updatedIPAManifest.items[0] = ipaItem

			let encoder = PropertyListEncoder()
			encoder.outputFormat = .xml
			let newData = try encoder.encode(updatedIPAManifest)

			var newBuffer = ByteBufferAllocator().buffer(capacity: newData.count)
			newBuffer.writeBytes(newData)
			return newBuffer
		} catch {
			logger.error("Manifest plist modification failed: \(error.localizedDescription).")
			return nil
		}
	}
}
