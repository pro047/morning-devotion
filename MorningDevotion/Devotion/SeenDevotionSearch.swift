//
//  SeenDevotionSearch.swift
//  MorningDevotion
//

import Foundation

nonisolated enum SeenDevotionSearch {
    /// One date search for `date`; returns the first entry (list order) whose date == `date`, else nil.
    /// Fetch errors are rethrown unchanged.
    static func find(
        on date: DevotionDate,
        using fetcher: some DevotionHTMLFetching
    ) async throws -> DevotionEntry? {
        guard let url = DevotionSearchURL.url(date: date) else {
            throw DevotionLoadError.invalidURL
        }
        let html = try await fetcher.fetchHTML(from: url)
        return entry(in: DevotionListParser.parseEntries(fromHTML: html), on: date)
    }

    /// First entry in `entries` whose date equals `date`.
    static func entry(in entries: [DevotionEntry], on date: DevotionDate) -> DevotionEntry? {
        entries.first { $0.date == date }
    }
}
