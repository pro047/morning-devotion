//
//  DevotionSearchURL.swift
//  MorningDevotion
//

import Foundation

nonisolated enum DevotionSearchURL {
    /// Slashes in the date are intentionally not percent-encoded.
    static func string(date: DevotionDate) -> String {
        "https://100church.org/home/board.php?board=cast&config=6&category=6&search=\(date.description)&shwhere=subject"
    }

    static func url(date: DevotionDate) -> URL? {
        URL(string: string(date: date))
    }
}
