//
//  NextDevotionPicker.swift
//  MorningDevotion
//

import Foundation

nonisolated enum NextDevotionPicker {
    static func testament(at now: Date, calendar: Calendar) -> Testament {
        calendar.component(.hour, from: now) < 12 ? .oldTestament : .newTestament
    }

    /// Earliest entry with date > lastSeen. Ties keep the first in `entries` order.
    static func nextEntry(in entries: [DevotionEntry], after lastSeen: DevotionDate) -> DevotionEntry? {
        var best: DevotionEntry?
        for entry in entries where entry.date > lastSeen {
            if let current = best, current.date <= entry.date { continue }
            best = entry
        }
        return best
    }

    static func pick(
        listHTML: String,
        progress: ReadingProgress,
        now: Date,
        calendar: Calendar
    ) -> NextDevotionPick {
        let testament = testament(at: now, calendar: calendar)
        let entries = DevotionListParser.parseEntries(fromHTML: listHTML)
        return NextDevotionPick(
            testament: testament,
            entry: nextEntry(in: entries, after: progress.lastSeen(for: testament))
        )
    }
}
