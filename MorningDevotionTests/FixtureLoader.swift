//
//  FixtureLoader.swift
//  MorningDevotionTests
//

import Foundation

private final class BundleToken {}

struct FixtureNotFound: Error, CustomStringConvertible {
    let name: String
    let tried: [String]
    var description: String {
        "Fixture '\(name).html' not found. Tried: \(tried.joined(separator: ", "))"
    }
}

enum FixtureLoader {
    /// name without extension, e.g. "cast-search-john-5". UTF-8. Throws if not found.
    static func html(_ name: String) throws -> String {
        let bundle = Bundle(for: BundleToken.self)
        var candidates: [URL] = []
        // 1) bundle root (resources flattened)
        if let url = bundle.url(forResource: name, withExtension: "html") {
            candidates.append(url)
        }
        // 2) bundle "Fixtures" subdirectory
        if let url = bundle.url(forResource: name, withExtension: "html", subdirectory: "Fixtures") {
            candidates.append(url)
        }
        // 3) source tree next to this file
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("\(name).html")
        candidates.append(sourceURL)

        for url in candidates {
            if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                return text
            }
        }
        throw FixtureNotFound(name: name, tried: candidates.map(\.path))
    }
}
