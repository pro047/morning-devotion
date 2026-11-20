//
//  DevotionTitleParser.swift
//  MorningDevotion
//

import Foundation

nonisolated enum DevotionTitleParser {
    private static let datePattern = try! NSRegularExpression(pattern: #"^(\d{4})/(\d{1,2})/(\d{1,2})/?"#)
    private static let weekdayPattern = try! NSRegularExpression(pattern: #"^\s*\(([^)]+)\)"#)
    private static let authorPattern = try! NSRegularExpression(pattern: #"^(.*)/\s*작성\s*:\s*(.*)$"#)
    private static let passagePattern = try! NSRegularExpression(pattern: #"^(.+?)\s+(\d+):(\d+)-(?:(\d+):)?(\d+)$"#)

    /// Returns nil only when the leading date can't be read.
    static func parse(_ title: String) -> DevotionEntry? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let ns = trimmed as NSString

        guard let dm = datePattern.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)),
              let year = Int(ns.substring(with: dm.range(at: 1))),
              let month = Int(ns.substring(with: dm.range(at: 2))),
              let day = Int(ns.substring(with: dm.range(at: 3))),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }

        var rest = ns.substring(from: dm.range.location + dm.range.length)

        var weekday: String?
        let restNS = rest as NSString
        if let wm = weekdayPattern.firstMatch(in: rest, range: NSRange(location: 0, length: restNS.length)) {
            weekday = restNS.substring(with: wm.range(at: 1))
            rest = restNS.substring(from: wm.range.location + wm.range.length)
        }

        var author: String?
        let restNS2 = rest as NSString
        if let am = authorPattern.firstMatch(in: rest, range: NSRange(location: 0, length: restNS2.length)) {
            let a = restNS2.substring(with: am.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            author = a.isEmpty ? nil : a
            rest = restNS2.substring(with: am.range(at: 1))
        }

        let passageText = rest
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "~", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return DevotionEntry(
            date: DevotionDate(year: year, month: month, day: day),
            weekday: weekday,
            passageText: passageText,
            passage: parsePassage(passageText),
            author: author
        )
    }

    private static func parsePassage(_ text: String) -> Passage? {
        let ns = text as NSString
        guard let m = passagePattern.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              let chapter = Int(ns.substring(with: m.range(at: 2))),
              let startVerse = Int(ns.substring(with: m.range(at: 3))),
              let endVerse = Int(ns.substring(with: m.range(at: 5)))
        else { return nil }
        let endChapterRange = m.range(at: 4)
        let endChapter = endChapterRange.location == NSNotFound
            ? chapter
            : (Int(ns.substring(with: endChapterRange)) ?? chapter)
        return Passage(
            book: ns.substring(with: m.range(at: 1)),
            chapter: chapter,
            startVerse: startVerse,
            endChapter: endChapter,
            endVerse: endVerse
        )
    }
}
