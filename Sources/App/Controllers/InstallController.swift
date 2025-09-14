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
			var format = PropertyListSerialization.PropertyListFormat.xml
			let plistAny = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
			guard var plist = plistAny as? [String: Any] else {
				return nil
			}

			// Navigate to the first asset URL
			guard var items = plist["items"] as? [[String: Any]], !items.isEmpty else {
				return nil
			}

			var firstItem = items[0]
			guard var assets = firstItem["assets"] as? [[String: Any]], !assets.isEmpty else {
				return nil
			}

			var firstAsset = assets[0]
			guard let urlString = firstAsset["url"] as? String, var urlComponents = URLComponents(string: urlString) else {
				return nil
			}

			// Update host if needed
			if urlComponents.host == "dl.dropboxusercontent.com" {
				urlComponents.host = "www.dropbox.com"
			}

			// ensure dl=1 is present to force direct download from Dropbox
			var queryItems = urlComponents.queryItems ?? []
			let dlQueryItem = URLQueryItem(name: "dl", value: "1")
			if let dlQueryItemIndex = queryItems.firstIndex(where: { $0.name == dlQueryItem.name }) {
				queryItems[dlQueryItemIndex] = dlQueryItem
			} else {
				queryItems.append(dlQueryItem)
			}
			urlComponents.queryItems = queryItems

			// Set the modified URL back to the first asset
			if let newURL = urlComponents.string {
				firstAsset["url"] = newURL
				assets[0] = firstAsset
				firstItem["assets"] = assets
				items[0] = firstItem
				plist["items"] = items
			} else {
				return nil
			}

			// Serialize the modified plist back to Data
			let newData = try PropertyListSerialization.data(
				fromPropertyList: plist,
				format: .xml,
				options: 0
			)
			var newBuffer = ByteBufferAllocator().buffer(capacity: newData.count)
			newBuffer.writeBytes(newData)
			return newBuffer
		} catch {
			logger.error("Manifest plist modification failed: \(error.localizedDescription). \nRaw error: \(error)")
			return nil
		}
	}
}
