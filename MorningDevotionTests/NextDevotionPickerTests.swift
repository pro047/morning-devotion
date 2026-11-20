//
//  NextDevotionPickerTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

@MainActor
struct NextDevotionPickerTests {

    // MARK: - Helpers

    private static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private static let kst = calendar("Asia/Seoul")
    private static let utc = calendar("UTC")

    private static func time(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> DevotionDate {
        DevotionDate(year: year, month: month, day: day)
    }

    private static let progress = ReadingProgress(lastSeenOld: date(2025, 9, 10), lastSeenNew: date(2020, 7, 11))

    // MARK: - AC-1 old testament pick (morning)

    // AC-1: 08:00 KST + proverbs fixture → next old-testament entry 2025/09/11
    @Test func ac1_morningPicksNextOldTestamentEntry() throws {
        let html = try FixtureLoader.html("cast-search-proverbs-23")
        let now = try Self.time(Self.kst, 2026, 11, 20, 8, 0)

        let pick = NextDevotionPicker.pick(listHTML: html, progress: Self.progress, now: now, calendar: Self.kst)

        #expect(pick.testament == .oldTestament)
        let entry = try #require(pick.entry)
        #expect(entry.date == Self.date(2025, 9, 11))
        #expect(entry.weekday == "목")
        #expect(entry.passage == Passage(book: "잠언", chapter: 23, startVerse: 24, endChapter: 23, endVerse: 35))
        #expect(entry.author == "김광욱")
    }

    // MARK: - AC-2 new testament pick (afternoon)

    // AC-2: 13:00 KST + john fixture → 2020/07/13 박성호 (not 2015/06/22 윤순재)
    @Test func ac2_afternoonPicksNextNewTestamentEntry() throws {
        let html = try FixtureLoader.html("cast-search-john-5")
        let now = try Self.time(Self.kst, 2026, 11, 20, 13, 0)

        let pick = NextDevotionPicker.pick(listHTML: html, progress: Self.progress, now: now, calendar: Self.kst)

        #expect(pick.testament == .newTestament)
        let entry = try #require(pick.entry)
        #expect(entry.date == Self.date(2020, 7, 13))
        #expect(entry.weekday == "월")
        #expect(entry.passage == Passage(book: "요한복음", chapter: 5, startVerse: 30, endChapter: 5, endVerse: 47))
        #expect(entry.author == "박성호")
    }

    // MARK: - AC-7 hour boundaries

    // AC-7: 00:00/11:59 → old, 12:00/23:59 → new (KST calendar)
    @Test(arguments: [
        (0, 0, Testament.oldTestament),
        (11, 59, Testament.oldTestament),
        (12, 0, Testament.newTestament),
        (23, 59, Testament.newTestament),
    ])
    func ac7_hourBoundaries(hour: Int, minute: Int, expected: Testament) throws {
        let now = try Self.time(Self.kst, 2026, 11, 20, hour, minute)
        #expect(NextDevotionPicker.testament(at: now, calendar: Self.kst) == expected)
    }

    // MARK: - AC-8 calendar argument decides

    // AC-8: same instant (03:00 UTC = 12:00 KST) judged by the given calendar
    @Test func ac8_calendarArgumentDecidesTestament() throws {
        let instant = try Self.time(Self.utc, 2026, 11, 20, 3, 0)
        #expect(Self.kst.component(.hour, from: instant) == 12)
        #expect(NextDevotionPicker.testament(at: instant, calendar: Self.kst) == .newTestament)
        #expect(NextDevotionPicker.testament(at: instant, calendar: Self.utc) == .oldTestament)
    }

    // MARK: - AC-9 year rollover

    // AC-9: after 2025/12/31 → 2026/01/02 이태선 (not 2019/02/05 or 2014/01/21)
    @Test func ac9_crossesYearBoundary() throws {
        let entries = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-isaiah-19"))
        let entry = try #require(NextDevotionPicker.nextEntry(in: entries, after: Self.date(2025, 12, 31)))
        #expect(entry.date == Self.date(2026, 1, 2))
        #expect(entry.weekday == "금")
        #expect(entry.passage == Passage(book: "이사야", chapter: 19, startVerse: 1, endChapter: 19, endVerse: 15))
        #expect(entry.author == "이태선")
    }

    // MARK: - AC-10 none

    // AC-10: nothing after the newest date → nil
    @Test func ac10_nothingAfterLatestReturnsNil() throws {
        let entries = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-proverbs-23"))
        #expect(NextDevotionPicker.nextEntry(in: entries, after: Self.date(2025, 9, 11)) == nil)
    }

    // AC-10: pick on latest list with old progress at 2026/11/20 → entry nil, testament old
    @Test func ac10_pickReturnsNoEntry() throws {
        let html = try FixtureLoader.html("cast-list-latest")
        let progress = ReadingProgress(lastSeenOld: Self.date(2026, 11, 20), lastSeenNew: Self.date(2020, 7, 11))
        let now = try Self.time(Self.kst, 2026, 11, 20, 8, 0)

        let pick = NextDevotionPicker.pick(listHTML: html, progress: progress, now: now, calendar: Self.kst)

        #expect(pick == NextDevotionPick(testament: .oldTestament, entry: nil))
    }

    // MARK: - AC-14 not "+1 day", order independent

    // AC-14: after 2020/07/11 with no 07/12 entry → 07/13, on reversed input
    @Test func ac14_skipsMissingDayAndIgnoresInputOrder() throws {
        let entries = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-john-5"))
        let reversed = Array(entries.reversed())

        let fromReversed = try #require(NextDevotionPicker.nextEntry(in: reversed, after: Self.date(2020, 7, 11)))
        #expect(fromReversed.date == Self.date(2020, 7, 13))
        #expect(fromReversed.author == "박성호")

        let fromOriginal = try #require(NextDevotionPicker.nextEntry(in: entries, after: Self.date(2020, 7, 11)))
        #expect(fromOriginal == fromReversed)
    }

    // MARK: - AC-15 DevotionDate comparison

    // AC-15: lexicographic (year, month, day) ordering and zero-padded description
    @Test func ac15_devotionDateComparisonAndDescription() {
        #expect(Self.date(2025, 12, 31) < Self.date(2026, 1, 2))
        #expect(Self.date(2020, 7, 11) < Self.date(2020, 7, 13))
        #expect(Self.date(2015, 6, 22) < Self.date(2020, 7, 11))
        #expect(!(Self.date(2026, 1, 2) < Self.date(2025, 12, 31)))
        #expect(!(Self.date(2020, 7, 13) < Self.date(2020, 7, 13)))
        // month dominates day; year dominates month
        #expect(Self.date(2020, 6, 30) < Self.date(2020, 7, 1))
        #expect(Self.date(2019, 12, 31) < Self.date(2020, 1, 1))
        #expect(DevotionDate(year: 2025, month: 9, day: 11).description == "2025/09/11")
        #expect(DevotionDate(year: 2009, month: 2, day: 19).description == "2009/02/19")
    }

    // MARK: - Boundaries beyond the listed criteria

    @Test func emptyEntriesReturnNil() {
        #expect(NextDevotionPicker.nextEntry(in: [], after: Self.date(2000, 1, 1)) == nil)
    }

    // strictly after: an entry on the lastSeen date itself is not picked
    @Test func entryOnLastSeenDateIsExcluded() throws {
        let entries = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-proverbs-23"))
        let entry = try #require(NextDevotionPicker.nextEntry(in: entries, after: Self.date(2025, 9, 10)))
        #expect(entry.date == Self.date(2025, 9, 11))
    }

    // year not restricted: lastSeen far in the past picks the oldest entry
    @Test func veryOldLastSeenPicksEarliestEntry() throws {
        let entries = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-isaiah-19"))
        let entry = try #require(NextDevotionPicker.nextEntry(in: entries, after: Self.date(2000, 1, 1)))
        #expect(entry.date == Self.date(2009, 2, 19))
        #expect(entry.author == "김순식")
    }

    // Design decision 8: same date → first in input order
    @Test func sameDateTieBreaksByInputOrder() throws {
        let first = try #require(DevotionTitleParser.parse("2026/11/21(토) “잠언 1:1-7” / 작성: 첫번째"))
        let second = try #require(DevotionTitleParser.parse("2026/11/21(토) “잠언 1:8-19” / 작성: 두번째"))
        let later = try #require(DevotionTitleParser.parse("2026/11/22(일) “잠언 1:20-33” / 작성: 나중"))

        let a = NextDevotionPicker.nextEntry(in: [later, first, second], after: Self.date(2026, 11, 20))
        #expect(a?.author == "첫번째")
        let b = NextDevotionPicker.nextEntry(in: [later, second, first], after: Self.date(2026, 11, 20))
        #expect(b?.author == "두번째")
    }

    // Unparseable passage is still a candidate (design decision 4)
    @Test func entryWithoutPassageIsStillCandidate() throws {
        let odd = try #require(DevotionTitleParser.parse("2026/11/21(토) “특별새벽기도회” / 작성: 홍길동"))
        let normal = try #require(DevotionTitleParser.parse("2026/11/22(일) “잠언 1:1-7” / 작성: 김철수"))
        let entry = NextDevotionPicker.nextEntry(in: [normal, odd], after: Self.date(2026, 11, 20))
        #expect(entry?.author == "홍길동")
        #expect(entry?.passage == nil)
    }

    // ReadingProgress maps each testament to its own lastSeen
    @Test func readingProgressLastSeenPerTestament() {
        #expect(Self.progress.lastSeen(for: .oldTestament) == Self.date(2025, 9, 10))
        #expect(Self.progress.lastSeen(for: .newTestament) == Self.date(2020, 7, 11))
    }

    // pick uses the new-testament position in the afternoon even on an old-testament list
    @Test func pickUsesProgressOfCurrentTestament() throws {
        let html = try FixtureLoader.html("cast-search-proverbs-23")
        let progress = ReadingProgress(lastSeenOld: Self.date(2025, 9, 11), lastSeenNew: Self.date(2018, 12, 10))
        let morning = try Self.time(Self.kst, 2026, 11, 20, 11, 59)
        let afternoon = try Self.time(Self.kst, 2026, 11, 20, 12, 0)

        let m = NextDevotionPicker.pick(listHTML: html, progress: progress, now: morning, calendar: Self.kst)
        #expect(m == NextDevotionPick(testament: .oldTestament, entry: nil))

        let a = NextDevotionPicker.pick(listHTML: html, progress: progress, now: afternoon, calendar: Self.kst)
        #expect(a.testament == .newTestament)
        #expect(a.entry?.date == Self.date(2025, 9, 9))
        #expect(a.entry?.author == "이태선")
    }

    // pick on empty HTML → no entry
    @Test func pickOnEmptyHTMLReturnsNoEntry() throws {
        let now = try Self.time(Self.kst, 2026, 11, 20, 8, 0)
        let pick = NextDevotionPicker.pick(listHTML: "", progress: Self.progress, now: now, calendar: Self.kst)
        #expect(pick == NextDevotionPick(testament: .oldTestament, entry: nil))
    }
}
