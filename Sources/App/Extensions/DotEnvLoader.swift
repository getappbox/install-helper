//
//  DotEnvLoader.swift
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
            line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if let hashIndex = line.firstIndex(of: "#") {
                let before = line[..<hashIndex]
                if before.last?.isWhitespace == true {
                    line = String(before).trimmingCharacters(in: .whitespaces)
                }
            }

            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)

            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            if ProcessInfo.processInfo.environment[key] == nil {
                setenv(key, value, 0)
            }
        }
    }
}
