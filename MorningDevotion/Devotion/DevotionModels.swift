//
//  DevotionModels.swift
//  MorningDevotion
//

import Foundation

nonisolated enum Testament: Equatable, Sendable {
    case oldTestament   // morning: 00:00-11:59
    case newTestament   // afternoon: 12:00-23:59
}

/// Calendar date (not an instant), so time zones cannot shift it by a day.
nonisolated struct DevotionDate: Comparable, Hashable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    static func < (lhs: DevotionDate, rhs: DevotionDate) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }

    var description: String {
        let m = month < 10 ? "0\(month)" : "\(month)"
        let d = day < 10 ? "0\(day)" : "\(day)"
        return "\(year)/\(m)/\(d)"
    }
}

extension DevotionDate {
    /// Persisted form, "YYYY/MM/DD" (same as `description`).
    nonisolated var storageString: String { description }

    /// Strict inverse of `storageString`: 4 digits "/" 2 digits "/" 2 digits.
    nonisolated init?(storageString: String) {
        let parts = storageString.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d)
        else { return nil }
        self.init(year: y, month: m, day: d)
    }
}

nonisolated struct Passage: Equatable, Sendable {
    let book: String
    let chapter: Int
    let startVerse: Int
    let endChapter: Int
    let endVerse: Int
}

nonisolated struct DevotionEntry: Equatable, Sendable {
    let date: DevotionDate
    let weekday: String?
    let passageText: String
    let passage: Passage?
    let author: String?
    /// `no=<n>` of the list link. nil when parsed from a bare title.
    var articleNo: Int? = nil
}

nonisolated struct DevotionArticle: Equatable, Sendable {
    let titleEntry: DevotionEntry?
    let passageText: String
    let hymn: String?
    let sermon: String
}

nonisolated struct ReadingProgress: Equatable, Sendable {
    var lastSeenOld: DevotionDate
    var lastSeenNew: DevotionDate

    func lastSeen(for testament: Testament) -> DevotionDate {
        switch testament {
        case .oldTestament: return lastSeenOld
        case .newTestament: return lastSeenNew
        }
    }
}

extension ReadingProgress {
    /// Read ⇔ date <= lastSeen of that testament.
    nonisolated func isRead(_ date: DevotionDate, for testament: Testament) -> Bool {
        date <= lastSeen(for: testament)
    }
}

nonisolated struct NextDevotionPick:Equatable, Sendable {
    let testament: Testament
    let entry: DevotionEntry?
}
