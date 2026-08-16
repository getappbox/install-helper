//
//  BuildEmailTemplate.swift
//
//
//  Created by Vineet Choudhary on 15/08/26.
//

import Foundation

/// Renders the "build is ready to test" email — subject, HTML part and plain-text part.
enum BuildEmailTemplate {
	private enum Palette {
		static let pageBackground = "#f4f4f5"
		static let cardBackground = "#ffffff"
		static let noteBackground = "#fafafa"
		static let border = "#e4e4e7"
		static let heading = "#18181b"
		static let bodyText = "#3f3f46"
		static let mutedText = "#71717a"
		static let footerText = "#a1a1aa"
		static let buttonBackground = "#18181b"
		static let buttonText = "#ffffff"
	}

	private static let fontStack =
		"-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif"

	static func subject(for mail: MailSendRequest) -> String {
		"\(mail.name) \(mail.version) (\(mail.build)) is ready to test"
	}

	/// Escapes text for interpolation into HTML markup or an attribute value.
	static func escape(_ raw: String) -> String {
		raw.replacingOccurrences(of: "&", with: "&amp;")
			.replacingOccurrences(of: "<", with: "&lt;")
			.replacingOccurrences(of: ">", with: "&gt;")
			.replacingOccurrences(of: "\"", with: "&quot;")
			.replacingOccurrences(of: "'", with: "&#39;")
	}

	static func html(for mail: MailSendRequest) -> String {
		let name = escape(mail.name)
		let version = escape(mail.version)
		let build = escape(mail.build)
		let installURL = escape(mail.installURL)
		let title = "\(name) \(version) (\(build)) is ready to test"

		return """
		<!DOCTYPE html>
		<html lang="en">
		<head>
		<meta charset="utf-8" />
		<meta name="viewport" content="width=device-width,initial-scale=1" />
		<meta name="color-scheme" content="light" />
		<title>\(title)</title>
		<style>
		@media screen and (max-width:640px) {
		.ab-pad { padding-left:24px !important; padding-right:24px !important; }
		.ab-title { font-size:22px !important; line-height:30px !important; }
		.ab-lead { font-size:15px !important; line-height:23px !important; }
		.ab-stat { display:block !important; width:100% !important; padding:0 0 16px 0 !important; }
		.ab-stat-last { padding-bottom:0 !important; }
		.ab-btn { display:block !important; text-align:center !important; }
		.ab-shell { padding:16px 12px !important; }
		}
		</style>
		</head>
		<body style="margin:0;padding:0;background-color:\(Palette.pageBackground);">
		<div style="display:none;max-height:0;overflow:hidden;opacity:0;">Install \(name) \(version) (\(build)) on your iPhone or iPad.</div>
		<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="border-collapse:collapse;background-color:\(Palette.pageBackground);">
		<tr><td align="center" class="ab-shell" style="padding:48px 20px;">
		<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="680" style="border-collapse:collapse;width:100%;max-width:680px;background-color:\(Palette.cardBackground);border:1px solid \(Palette.border);border-radius:12px;font-family:\(fontStack);">

		<tr><td class="ab-pad" style="padding:36px 48px 0 48px;">
		<p style="margin:0;font-size:13px;line-height:18px;font-weight:600;letter-spacing:0.08em;text-transform:uppercase;color:\(Palette.mutedText);">AppBox</p>
		</td></tr>

		<tr><td class="ab-pad" style="padding:18px 48px 0 48px;">
		<h1 class="ab-title" style="margin:0;font-size:28px;line-height:36px;font-weight:600;letter-spacing:-0.01em;color:\(Palette.heading);">\(title)</h1>
		<p class="ab-lead" style="margin:14px 0 0 0;font-size:16px;line-height:26px;color:\(Palette.bodyText);">You have been invited to test this build. Open this email on your iPhone or iPad, then tap Install to add it to your home screen.</p>
		</td></tr>

		<tr><td class="ab-pad" style="padding:28px 48px 0 48px;">
		<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;">
		<tr><td align="center" style="border-radius:6px;background-color:\(Palette.buttonBackground);">
		<a href="\(installURL)" class="ab-btn" style="display:inline-block;padding:14px 32px;font-size:16px;line-height:20px;font-weight:600;color:\(Palette.buttonText);text-decoration:none;border-radius:6px;">Install \(name)</a>
		</td></tr>
		</table>
		<p style="margin:18px 0 0 0;font-size:13px;line-height:20px;color:\(Palette.mutedText);">If the button does not work, copy this link into Safari on your iPhone or iPad:<br />
		<a href="\(installURL)" style="color:\(Palette.bodyText);text-decoration:underline;word-break:break-all;">\(installURL)</a></p>
		</td></tr>

		<tr><td class="ab-pad" style="padding:32px 48px 0 48px;">
		<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="border-collapse:collapse;background-color:\(Palette.noteBackground);border:1px solid \(Palette.border);border-radius:8px;">
		<tr><td style="padding:22px 26px;">
		<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="border-collapse:collapse;">
		<tr>
		<td class="ab-stat" width="40%" valign="top" style="padding:0 16px 0 0;">
		<p style="margin:0 0 4px 0;font-size:11px;line-height:15px;font-weight:600;letter-spacing:0.06em;text-transform:uppercase;color:\(Palette.mutedText);">App</p>
		<p style="margin:0;font-size:16px;line-height:22px;font-weight:600;color:\(Palette.heading);">\(name)</p>
		</td>
		<td class="ab-stat" width="30%" valign="top" style="padding:0 16px 0 0;">
		<p style="margin:0 0 4px 0;font-size:11px;line-height:15px;font-weight:600;letter-spacing:0.06em;text-transform:uppercase;color:\(Palette.mutedText);">Version</p>
		<p style="margin:0;font-size:16px;line-height:22px;font-weight:600;color:\(Palette.heading);">\(version)</p>
		</td>
		<td class="ab-stat ab-stat-last" width="30%" valign="top" style="padding:0;">
		<p style="margin:0 0 4px 0;font-size:11px;line-height:15px;font-weight:600;letter-spacing:0.06em;text-transform:uppercase;color:\(Palette.mutedText);">Build</p>
		<p style="margin:0;font-size:16px;line-height:22px;font-weight:600;color:\(Palette.heading);">\(build)</p>
		</td>
		</tr>
		</table>
		</td></tr>
		</table>
		</td></tr>

		\(developerNote(for: mail))

		<tr><td class="ab-pad" style="padding:32px 48px 36px 48px;">
		<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="border-collapse:collapse;border-top:1px solid \(Palette.border);">
		<tr><td style="padding:22px 0 0 0;">
		<p style="margin:0;font-size:12px;line-height:20px;color:\(Palette.footerText);">Sent automatically by <a href="https://getappbox.com" style="color:\(Palette.mutedText);text-decoration:underline;">AppBox</a>. You received this because a developer added your email address when they uploaded this build.</p>
		</td></tr>
		</table>
		</td></tr>

		</table>
		</td></tr>
		</table>
		</body>
		</html>
		"""
	}

	/// The optional developer message block; empty when no message was supplied.
	private static func developerNote(for mail: MailSendRequest) -> String {
		guard let message = mail.personalMessage, !message.isEmpty else { return "" }
		let rendered = escape(message)
			.replacingOccurrences(of: "\r\n", with: "<br />")
			.replacingOccurrences(of: "\n", with: "<br />")
		return """
		<tr><td class="ab-pad" style="padding:20px 48px 0 48px;">
		<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="border-collapse:collapse;border-left:3px solid \(Palette.border);">
		<tr><td style="padding:2px 0 2px 20px;">
		<p style="margin:0 0 8px 0;font-size:12px;line-height:16px;font-weight:600;letter-spacing:0.04em;text-transform:uppercase;color:\(Palette.mutedText);">Message from the developer</p>
		<p style="margin:0;font-size:15px;line-height:24px;color:\(Palette.bodyText);">\(rendered)</p>
		</td></tr>
		</table>
		</td></tr>
		"""
	}

	/// Plain-text alternative sent alongside the HTML part.
	static func text(for mail: MailSendRequest) -> String {
		var lines = [
			subject(for: mail),
			"",
			"You have been invited to test this build. Open this link on your iPhone or iPad to install it:",
			mail.installURL,
			"",
			"App: \(mail.name)",
			"Version: \(mail.version)",
			"Build: \(mail.build)"
		]
		if let message = mail.personalMessage, !message.isEmpty {
			lines.append(contentsOf: ["", "Message from the developer:", message])
		}
		lines.append(contentsOf: [
			"",
			"Sent automatically by AppBox. You received this because a developer added your email address when they uploaded this build. https://getappbox.com"
		])
		return lines.joined(separator: "\n")
	}
}
