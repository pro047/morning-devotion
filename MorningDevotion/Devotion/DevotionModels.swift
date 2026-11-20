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

nonisolated struct NextDevotionPick: Equatable, Sendable {
    let testament: Testament
    let entry: DevotionEntry?
}
