//
//  BiblePassageLoader.swift
//  MorningDevotion
//

import Foundation

nonisolated struct BibleVerse: Equatable, Sendable {
    let number: Int
    let text: String
}

nonisolated struct BibleChapterSection: Equatable, Sendable {
    let chapter: Int
    let verses: [BibleVerse]
}

nonisolated struct BiblePassageText: Equatable, Sendable {
    /// Same string as the devotion header, e.g. "잠언 23:24-35".
    let title: String
    /// One per chapter, in order (chapter … endChapter).
    let sections: [BibleChapterSection]

    /// True for every section after the first (view shows "<n>장" before it).
    func showsChapterHeader(at index: Int) -> Bool {
        index > 0
    }
}

nonisolated enum BiblePassageSlicer {
    /// Pure. `chapters[c]` = parsed verses of chapter c. nil on any failed rule.
    static func slice(_ passage: Passage, chapters: [Int: [BibleVerse]]) -> [BibleChapterSection]? {
        guard passage.endChapter >= passage.chapter else { return nil }
        var sections: [BibleChapterSection] = []
        for c in passage.chapter...passage.endChapter {
            guard let page = chapters[c], !page.isEmpty else { return nil }
            // Two independent conditions: a middle chapter is whole (1…max).
            let lo = c == passage.chapter ? passage.startVerse : 1
            let hi = c == passage.endChapter ? passage.endVerse : (page.map(\.number).max() ?? 0)
            let picked = page.filter { $0.number >= lo && $0.number <= hi }
            guard let first = picked.first, let last = picked.last else { return nil }
            if c == passage.chapter && first.number != passage.startVerse { return nil }
            if c == passage.endChapter && last.number != passage.endVerse { return nil }
            sections.append(BibleChapterSection(chapter: c, verses: picked))
        }
        return sections
    }
}

nonisolated enum BiblePassageLoader {
    /// Requests chapter … endChapter in ascending order, one at a time, and stops at the first failure.
    /// nil = unknown book code, endChapter < chapter, fetch throws, or slice fails.
    static func load(_ passage: Passage, title: String,
                     using fetcher: some DevotionHTMLFetching) async -> BiblePassageText? {
        guard let code = BibleBookCode.code(for: passage.book),
              passage.endChapter >= passage.chapter else { return nil }
        var chapters: [Int: [BibleVerse]] = [:]
        for c in passage.chapter...passage.endChapter {
            guard let url = BiblePassageURL.url(bookCode: code, chapter: c) else { return nil }
            do {
                let html = try await fetcher.fetchHTML(from: url)
                chapters[c] = BibleChapterParser.parse(html: html)
            } catch {
                return nil
            }
        }
        guard let sections = BiblePassageSlicer.slice(passage, chapters: chapters) else { return nil }
        return BiblePassageText(title: title, sections: sections)
    }
}
