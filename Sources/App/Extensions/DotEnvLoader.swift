//
//  DotEnvLoader.swift
//
//  Loads environment variables from .env files into the process environment
//  so Vapor's Environment.get can read them locally.
//

import Vapor
import Foundation

enum DotEnvLoader {
    static func load(into app: Application) {
        let cwd = app.directory.workingDirectory
        let path = cwd + ".env"
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }
        if let text = try? String(contentsOfFile: path, encoding: .utf8) {
            parseAndSet(text)
        }
    }

    private static func parseAndSet(_ contents: String) {
        let lines = contents.components(separatedBy: .newlines)
        for rawLine in lines {
            var line = rawLine
            // Trim whitespace
            line = line.trimmingCharacters(in: .whitespaces)
            // Skip empty or comment lines
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            // Support inline comments after a space + #
            if let hashIndex = line.firstIndex(of: "#") {
                // Only treat as comment if preceded by whitespace
                let before = line[..<hashIndex]
                if before.last?.isWhitespace == true {
                    line = String(before).trimmingCharacters(in: .whitespaces)
                }
            }

            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)

            // Strip surrounding quotes if present
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            // Don't override existing environment variables
            if ProcessInfo.processInfo.environment[key] == nil {
                setenv(key, value, 0)
            }
        }
    }
}
