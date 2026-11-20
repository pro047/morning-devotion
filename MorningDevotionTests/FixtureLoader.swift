//
//  FixtureLoader.swift
//  MorningDevotionTests
//

import Foundation

private final class BundleToken {}

struct FixtureNotFound: Error, CustomStringConvertible {
    let name: String
    let ext: String
    let tried: [String]
    var description: String {
        "Fixture '\(name).\(ext)' not found. Tried: \(tried.joined(separator: ", "))"
    }
}

enum FixtureLoader {
    /// Raw bytes of `Fixtures/<name>.<ext>`. Throws if not found.
    static func data(_ name: String, ext: String) throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        var candidates: [URL] = []
        // 1) bundle root (resources flattened)
        if let url = bundle.url(forResource: name, withExtension: ext) {
            candidates.append(url)
        }
        // 2) bundle "Fixtures" subdirectory
        if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Fixtures") {
            candidates.append(url)
        }
        // 3) source tree next to this file
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("\(name).\(ext)")
        candidates.append(sourceURL)

        for url in candidates {
            if let data = try? Data(contentsOf: url) {
                return data
            }
        }
        throw FixtureNotFound(name: name, ext: ext, tried: candidates.map(\.path))
    }

    /// UTF-8 text of `Fixtures/<name>.<ext>`. Throws if not found or not UTF-8.
    static func text(_ name: String, ext: String) throws -> String {
        let data = try data(name, ext: ext)
        guard let text = String(data: data, encoding: .utf8) else {
            throw FixtureNotFound(name: name, ext: ext, tried: ["<not UTF-8>"])
        }
        return text
    }

    /// name without extension, e.g. "cast-search-john-5". UTF-8. Throws if not found.
    static func html(_ name: String) throws -> String {
        try text(name, ext: "html")
    }
}
