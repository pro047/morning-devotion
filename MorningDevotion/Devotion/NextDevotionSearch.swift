//
//  NextDevotionSearch.swift
//  MorningDevotion
//

import Foundation

nonisolated enum NextDevotionSearch {
    static let maxDays = 7

    /// Searches lastSeen+1 ... lastSeen+maxDays by date; the first day with an entry newer than lastSeen wins.
    /// Fetch errors are rethrown unchanged and stop the loop.
    static func findNext(
        after lastSeen: DevotionDate,
        using fetcher: some DevotionHTMLFetching
    ) async throws -> DevotionEntry? {
        for offset in 1...maxDays {
            guard let url = DevotionSearchURL.url(date: lastSeen.addingDays(offset)) else {
                throw DevotionLoadError.invalidURL
            }
            let html = try await fetcher.fetchHTML(from: url)
            let entries = DevotionListParser.parseEntries(fromHTML: html)
            if let next = NextDevotionPicker.nextEntry(in: entries, after: lastSeen) {
                return next
            }
        }
        return nil
    }
}
