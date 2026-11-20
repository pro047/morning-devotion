//
//  YouTubeAPIKey.swift
//  MorningDevotion
//

import Foundation

nonisolated enum YouTubeAPIKey {
    /// Info.plist key that carries $(YOUTUBE_API_KEY).
    static let infoKey = "YouTubeAPIKey"

    static func read(from info: [String: Any]?) -> String? {
        guard let value = info?[infoKey] as? String, !value.isEmpty else { return nil }
        return value
    }
}
