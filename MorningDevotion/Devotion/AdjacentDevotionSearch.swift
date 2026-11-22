//
//  AdjacentDevotionSearch.swift
//  MorningDevotion
//

import Foundation

nonisolated enum MoveDirection: Equatable, Sendable {
    case previous
    case next
}

nonisolated enum MoveOutcome: Equatable, Sendable {
    case moved(DevotionEntry)
    case notFound
    case networkError
}

nonisolated enum AdjacentDevotionSearch {
    /// Same window as NextDevotionSearch.maxDays.
    static let maxDays = NextDevotionSearch.maxDays

    /// Latest entry with date < `date`. Ties keep the first in `entries` order.
    static func previousEntry(in entries: [DevotionEntry], before date: DevotionDate) -> DevotionEntry? {
        var best: DevotionEntry?
        for entry in entries where entry.date < date {
            if let current = best, entry.date <= current.date { continue }
            best = entry
        }
        return best
    }

    /// Searches date-1 ... date-maxDays by date; the first day with an entry older than `date` wins.
    /// Fetch errors are rethrown unchanged and stop the loop.
    static func findPrevious(
        before date: DevotionDate,
        using fetcher: some DevotionHTMLFetching
    ) async throws -> DevotionEntry? {
        for offset in 1...maxDays {
            guard let url = DevotionSearchURL.url(date: date.addingDays(-offset)) else {
                throw DevotionLoadError.invalidURL
            }
            let html = try await fetcher.fetchHTML(from: url)
            let entries = DevotionListParser.parseEntries(fromHTML: html)
            if let previous = previousEntry(in: entries, before: date) {
                return previous
            }
        }
        return nil
    }

    /// Never throws: nil → .notFound, any thrown error → .networkError.
    static func move(
        _ direction: MoveDirection,
        from date: DevotionDate,
        using fetcher: some DevotionHTMLFetching
    ) async -> MoveOutcome {
        do {
            let found: DevotionEntry?
            switch direction {
            case .next: found = try await NextDevotionSearch.findNext(after: date, using: fetcher)
            case .previous: found = try await findPrevious(before: date, using: fetcher)
            }
            guard let entry = found else { return .notFound }
            return .moved(entry)
        } catch {
            return .networkError
        }
    }

    static func message(for outcome: MoveOutcome, direction: MoveDirection) -> String? {
        switch outcome {
        case .moved:
            return nil
        case .notFound:
            return direction == .previous ? "이전 묵상을 찾지 못했습니다" : "다음 묵상을 찾지 못했습니다"
        case .networkError:
            return "인터넷 연결을 확인해 주세요"
        }
    }
}
