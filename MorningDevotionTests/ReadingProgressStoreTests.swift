//
//  ReadingProgressStoreTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

@MainActor
struct ReadingProgressStoreTests {

    // MARK: - Helpers

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> DevotionDate {
        DevotionDate(year: y, month: m, day: d)
    }

    private static let oldKey = "readingProgress.lastSeenOld"
    private static let newKey = "readingProgress.lastSeenNew"

    /// Isolated UserDefaults suite per test; removed afterwards.
    private static func withSuite(_ body: (_ suiteName: String, _ defaults: UserDefaults) throws -> Void) throws {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(suiteName, defaults)
    }

    /// "New instance": fresh UserDefaults and fresh store on the same suite name.
    private static func reopen(_ suiteName: String) throws -> (UserDefaults, ReadingProgressStore) {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (defaults, ReadingProgressStore(defaults: defaults))
    }

    private static func kst() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    // MARK: - Constants

    // AC-15: default progress and key names as designed
    @Test func ac15_constants() {
        #expect(ReadingProgressStore.defaultProgress == ReadingProgress(
            lastSeenOld: Self.date(2025, 9, 10),
            lastSeenNew: Self.date(2020, 7, 11)
        ))
        #expect(ReadingProgressStore.oldKey == Self.oldKey)
        #expect(ReadingProgressStore.newKey == Self.newKey)
    }

    // MARK: - AC-15 empty store

    // AC-15: empty store → defaults returned and written as strings
    @Test func ac15_emptyStoreLoadsAndWritesDefaults() throws {
        try Self.withSuite { _, defaults in
            let store = ReadingProgressStore(defaults: defaults)
            let progress = store.load()

            #expect(progress.lastSeenOld == Self.date(2025, 9, 10))
            #expect(progress.lastSeenNew == Self.date(2020, 7, 11))
            #expect(defaults.string(forKey: Self.oldKey) == "2025/09/10")
            #expect(defaults.string(forKey: Self.newKey) == "2020/07/11")
        }
    }

    // AC-15: default progress feeds NextDevotionPicker (M2 완료 조건 5)
    @Test func ac15_defaultProgressPicksExpectedEntries() throws {
        try Self.withSuite { _, defaults in
            let progress = ReadingProgressStore(defaults: defaults).load()
            let calendar = Self.kst()
            let morning = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 8)))
            let afternoon = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 13)))

            let old = NextDevotionPicker.pick(
                listHTML: try FixtureLoader.html("cast-search-proverbs-23"),
                progress: progress, now: morning, calendar: calendar
            )
            #expect(old.testament == .oldTestament)
            #expect(old.entry?.date == Self.date(2025, 9, 11))

            let new = NextDevotionPicker.pick(
                listHTML: try FixtureLoader.html("cast-search-john-5"),
                progress: progress, now: afternoon, calendar: calendar
            )
            #expect(new.testament == .newTestament)
            #expect(new.entry?.date == Self.date(2020, 7, 13))
            #expect(new.entry?.author == "박성호")
        }
    }

    // MARK: - AC-16 stored value is not overwritten

    // AC-16: only old stored → old kept, new defaulted; persists across instances
    @Test func ac16_storedOldKeptNewDefaulted() throws {
        try Self.withSuite { suiteName, defaults in
            defaults.set("2025/09/11", forKey: Self.oldKey)

            let p1 = ReadingProgressStore(defaults: defaults).load()
            #expect(p1 == ReadingProgress(lastSeenOld: Self.date(2025, 9, 11), lastSeenNew: Self.date(2020, 7, 11)))

            let (d2, s2) = try Self.reopen(suiteName)
            #expect(s2.load() == p1)
            #expect(d2.string(forKey: Self.oldKey) == "2025/09/11")
            #expect(d2.string(forKey: Self.newKey) == "2020/07/11")
        }
    }

    // AC-16 symmetric: only new stored → new kept, old defaulted
    @Test func ac16_storedNewKeptOldDefaulted() throws {
        try Self.withSuite { _, defaults in
            defaults.set("2020/07/13", forKey: Self.newKey)
            let p = ReadingProgressStore(defaults: defaults).load()
            #expect(p == ReadingProgress(lastSeenOld: Self.date(2025, 9, 10), lastSeenNew: Self.date(2020, 7, 13)))
            #expect(defaults.string(forKey: Self.newKey) == "2020/07/13")
            #expect(defaults.string(forKey: Self.oldKey) == "2025/09/10")
        }
    }

    // MARK: - AC-17 markSeen

    // AC-17: markSeen(old) changes only old; persists
    @Test func ac17_markSeenOldOnly() throws {
        try Self.withSuite { suiteName, defaults in
            let store = ReadingProgressStore(defaults: defaults)
            let returned = store.markSeen(.oldTestament, date: Self.date(2025, 9, 11))
            let expected = ReadingProgress(lastSeenOld: Self.date(2025, 9, 11), lastSeenNew: Self.date(2020, 7, 11))

            #expect(returned == expected)
            #expect(defaults.string(forKey: Self.oldKey) == "2025/09/11")
            #expect(store.load() == expected)

            let (_, s2) = try Self.reopen(suiteName)
            #expect(s2.load() == expected)
        }
    }

    // AC-17 symmetric: markSeen(new) changes only new; persists
    @Test func ac17_markSeenNewOnly() throws {
        try Self.withSuite { suiteName, defaults in
            let store = ReadingProgressStore(defaults: defaults)
            let returned = store.markSeen(.newTestament, date: Self.date(2020, 7, 13))
            let expected = ReadingProgress(lastSeenOld: Self.date(2025, 9, 10), lastSeenNew: Self.date(2020, 7, 13))

            #expect(returned == expected)
            #expect(defaults.string(forKey: Self.newKey) == "2020/07/13")

            let (_, s2) = try Self.reopen(suiteName)
            #expect(s2.load() == expected)
        }
    }

    // AC-17 boundary: markSeen does not touch the other key's stored value
    @Test func ac17_markSeenLeavesOtherKeyUntouched() throws {
        try Self.withSuite { _, defaults in
            defaults.set("2020/07/13", forKey: Self.newKey)
            let returned = ReadingProgressStore(defaults: defaults).markSeen(.oldTestament, date: Self.date(2025, 9, 11))

            #expect(returned == ReadingProgress(lastSeenOld: Self.date(2025, 9, 11), lastSeenNew: Self.date(2020, 7, 13)))
            #expect(defaults.string(forKey: Self.newKey) == "2020/07/13")
        }
    }

    // AC-17 boundary: marking the same date twice is idempotent
    @Test func ac17_markSeenTwiceSameDate() throws {
        try Self.withSuite { _, defaults in
            let store = ReadingProgressStore(defaults: defaults)
            let a = store.markSeen(.oldTestament, date: Self.date(2025, 9, 11))
            let b = store.markSeen(.oldTestament, date: Self.date(2025, 9, 11))
            #expect(a == b)
            #expect(defaults.string(forKey: Self.oldKey) == "2025/09/11")
        }
    }

    // MARK: - AC-18 load alone does not change position

    // AC-18: load without markSeen → new instance sees the same defaults
    @Test func ac18_loadWithoutMarkSeenIsStable() throws {
        try Self.withSuite { suiteName, defaults in
            let p1 = ReadingProgressStore(defaults: defaults).load()
            let (_, s2) = try Self.reopen(suiteName)
            let p2 = s2.load()
            #expect(p1 == p2)
            #expect(p2 == ReadingProgress(lastSeenOld: Self.date(2025, 9, 10), lastSeenNew: Self.date(2020, 7, 11)))
        }
    }

    // AC-18: non-default stored values survive repeated loads across instances
    @Test func ac18_nonDefaultValuesStable() throws {
        try Self.withSuite { suiteName, defaults in
            defaults.set("2025/09/11", forKey: Self.oldKey)
            defaults.set("2020/07/13", forKey: Self.newKey)
            let expected = ReadingProgress(lastSeenOld: Self.date(2025, 9, 11), lastSeenNew: Self.date(2020, 7, 13))

            #expect(ReadingProgressStore(defaults: defaults).load() == expected)
            let (d2, s2) = try Self.reopen(suiteName)
            #expect(s2.load() == expected)
            #expect(s2.load() == expected)
            #expect(d2.string(forKey: Self.oldKey) == "2025/09/11")
            #expect(d2.string(forKey: Self.newKey) == "2020/07/13")
        }
    }

    // MARK: - AC-19 storage string

    // AC-19: storageString format and round trip
    @Test func ac19_storageStringRoundTrip() {
        #expect(Self.date(2025, 9, 11).storageString == "2025/09/11")
        #expect(Self.date(2009, 2, 19).storageString == "2009/02/19")
        #expect(Self.date(2020, 12, 31).storageString == "2020/12/31")
        #expect(DevotionDate(storageString: "2020/07/11") == Self.date(2020, 7, 11))
        #expect(DevotionDate(storageString: "2025/09/10") == Self.date(2025, 9, 10))
        #expect(DevotionDate(storageString: Self.date(2009, 2, 19).storageString) == Self.date(2009, 2, 19))
    }

    // AC-19: strict parsing rejects anything else
    @Test(arguments: [
        "", "2020/7/11", "2020/13/01", "2020/07/32", "abcd/ef/gh", "2020/07/11 ",
        " 2020/07/11", "2020-07-11", "202/07/11", "20200/07/11", "2020/00/10", "2020/07/00", "2020/07",
    ])
    func ac19_invalidStorageStringIsNil(input: String) {
        #expect(DevotionDate(storageString: input) == nil)
    }

    // MARK: - AC-20 unreadable stored value ([결정] 1 = 예)

    // AC-20: garbage old value → default used and written back; new untouched
    @Test func ac20_garbageReplacedByDefault() throws {
        try Self.withSuite { _, defaults in
            defaults.set("garbage", forKey: Self.oldKey)
            defaults.set("2020/07/13", forKey: Self.newKey)

            let p = ReadingProgressStore(defaults: defaults).load()
            #expect(p.lastSeenOld == Self.date(2025, 9, 10))
            #expect(p.lastSeenNew == Self.date(2020, 7, 13))
            #expect(defaults.string(forKey: Self.oldKey) == "2025/09/10")
            #expect(defaults.string(forKey: Self.newKey) == "2020/07/13")
        }
    }

    // AC-20 boundary: wrongly formatted (non zero-padded) new value is also treated as unreadable
    @Test func ac20_malformedNewReplacedByDefault() throws {
        try Self.withSuite { _, defaults in
            defaults.set("2020/7/13", forKey: Self.newKey)
            let p = ReadingProgressStore(defaults: defaults).load()
            #expect(p.lastSeenNew == Self.date(2020, 7, 11))
            #expect(defaults.string(forKey: Self.newKey) == "2020/07/11")
        }
    }

    // MARK: - AC-21 backwards record ([결정] 2 = 예)

    // AC-21: markSeen with an earlier date overwrites
    @Test func ac21_backwardsMarkSeenOverwrites() throws {
        try Self.withSuite { suiteName, defaults in
            defaults.set("2025/09/11", forKey: Self.oldKey)
            let returned = ReadingProgressStore(defaults: defaults).markSeen(.oldTestament, date: Self.date(2025, 9, 10))

            #expect(returned.lastSeenOld == Self.date(2025, 9, 10))
            #expect(defaults.string(forKey: Self.oldKey) == "2025/09/10")
            let (_, s2) = try Self.reopen(suiteName)
            #expect(s2.load().lastSeenOld == Self.date(2025, 9, 10))
        }
    }

    // MARK: - M4 additions (AC-17 (M4): finished day keys and non-writing read)

    private static let finishedOldRaw = "readingProgress.finishedDayOld"
    private static let finishedNewRaw = "readingProgress.finishedDayNew"

    // AC-17 (M4) ①⑦: new key names; existing constants unchanged
    @Test func m4_ac17_constants() {
        #expect(ReadingProgressStore.finishedOldKey == Self.finishedOldRaw)
        #expect(ReadingProgressStore.finishedNewKey == Self.finishedNewRaw)
        #expect(ReadingProgressStore.oldKey == Self.oldKey)
        #expect(ReadingProgressStore.newKey == Self.newKey)
        #expect(ReadingProgressStore.defaultProgress == ReadingProgress(
            lastSeenOld: Self.date(2025, 9, 10),
            lastSeenNew: Self.date(2020, 7, 11)
        ))
    }

    // AC-17 (M4) ②: empty store → both finished days nil, nothing written to any key
    @Test func m4_ac17_emptyFinishedDayIsNilAndNotWritten() throws {
        try Self.withSuite { _, defaults in
            let store = ReadingProgressStore(defaults: defaults)
            #expect(store.finishedDay(for: .oldTestament) == nil)
            #expect(store.finishedDay(for: .newTestament) == nil)
            #expect(defaults.object(forKey: Self.finishedOldRaw) == nil)
            #expect(defaults.object(forKey: Self.finishedNewRaw) == nil)
            #expect(defaults.object(forKey: Self.oldKey) == nil)
            #expect(defaults.object(forKey: Self.newKey) == nil)
        }
    }

    // AC-17 (M4) ③: markFinished(old) persists "YYYY/MM/DD" under the old key only; survives a new instance
    @Test func m4_ac17_markFinishedOldPersists() throws {
        try Self.withSuite { suiteName, defaults in
            ReadingProgressStore(defaults: defaults).markFinished(.oldTestament, on: Self.date(2026, 11, 20))
            #expect(defaults.string(forKey: Self.finishedOldRaw) == "2026/11/20")
            #expect(defaults.object(forKey: Self.finishedNewRaw) == nil)

            let (_, s2) = try Self.reopen(suiteName)
            #expect(s2.finishedDay(for: .oldTestament) == Self.date(2026, 11, 20))
            #expect(s2.finishedDay(for: .newTestament) == nil)
        }
    }

    // AC-17 (M4) ③ symmetric: markFinished(new) uses the new key only; zero-padded
    @Test func m4_ac17_markFinishedNewPersists() throws {
        try Self.withSuite { suiteName, defaults in
            ReadingProgressStore(defaults: defaults).markFinished(.newTestament, on: Self.date(2026, 1, 5))
            #expect(defaults.string(forKey: Self.finishedNewRaw) == "2026/01/05")
            #expect(defaults.object(forKey: Self.finishedOldRaw) == nil)

            let (_, s2) = try Self.reopen(suiteName)
            #expect(s2.finishedDay(for: .newTestament) == Self.date(2026, 1, 5))
            #expect(s2.finishedDay(for: .oldTestament) == nil)
        }
    }

    // AC-17 (M4) boundary: a later markFinished overwrites the earlier day
    @Test func m4_ac17_markFinishedOverwrites() throws {
        try Self.withSuite { _, defaults in
            let store = ReadingProgressStore(defaults: defaults)
            store.markFinished(.oldTestament, on: Self.date(2026, 11, 20))
            store.markFinished(.oldTestament, on: Self.date(2026, 11, 21))
            #expect(store.finishedDay(for: .oldTestament) == Self.date(2026, 11, 21))
            #expect(defaults.string(forKey: Self.finishedOldRaw) == "2026/11/21")
        }
    }

    // AC-17 (M4) ④: markFinished does not touch lastSeen keys (empty or stored)
    @Test func m4_ac17_markFinishedLeavesLastSeenKeys() throws {
        try Self.withSuite { _, defaults in
            ReadingProgressStore(defaults: defaults).markFinished(.oldTestament, on: Self.date(2026, 11, 20))
            #expect(defaults.object(forKey: Self.oldKey) == nil)
            #expect(defaults.object(forKey: Self.newKey) == nil)
        }
        try Self.withSuite { _, defaults in
            defaults.set("2025/09/11", forKey: Self.oldKey)
            defaults.set("garbage", forKey: Self.newKey)
            ReadingProgressStore(defaults: defaults).markFinished(.newTestament, on: Self.date(2026, 11, 20))
            #expect(defaults.string(forKey: Self.oldKey) == "2025/09/11")
            #expect(defaults.string(forKey: Self.newKey) == "garbage")
        }
    }

    // AC-17 (M4) ④: markSeen does not touch finished-day keys
    @Test func m4_ac17_markSeenLeavesFinishedKeys() throws {
        try Self.withSuite { _, defaults in
            defaults.set("2026/11/19", forKey: Self.finishedOldRaw)
            let store = ReadingProgressStore(defaults: defaults)
            store.markSeen(.oldTestament, date: Self.date(2025, 9, 11))
            store.markSeen(.newTestament, date: Self.date(2020, 7, 13))
            #expect(defaults.string(forKey: Self.finishedOldRaw) == "2026/11/19")
            #expect(defaults.object(forKey: Self.finishedNewRaw) == nil)
            #expect(store.finishedDay(for: .oldTestament) == Self.date(2026, 11, 19))
        }
    }

    // AC-17 (M4) ⑤: unreadable finished values → nil, raw value left as is
    @Test(arguments: ["garbage", "2026/11/2", ""])
    func m4_ac17_unreadableFinishedDayIsNilAndKept(raw: String) throws {
        try Self.withSuite { _, defaults in
            defaults.set(raw, forKey: Self.finishedOldRaw)
            defaults.set(raw, forKey: Self.finishedNewRaw)
            let store = ReadingProgressStore(defaults: defaults)
            #expect(store.finishedDay(for: .oldTestament) == nil)
            #expect(store.finishedDay(for: .newTestament) == nil)
            #expect(defaults.string(forKey: Self.finishedOldRaw) == raw)
            #expect(defaults.string(forKey: Self.finishedNewRaw) == raw)
        }
    }

    // AC-17 (M4) ⑥: storedProgress on an empty store → defaults, nothing written
    @Test func m4_ac17_storedProgressEmptyDoesNotWrite() throws {
        try Self.withSuite { _, defaults in
            let store = ReadingProgressStore(defaults: defaults)
            #expect(store.storedProgress() == ReadingProgressStore.defaultProgress)
            #expect(defaults.object(forKey: Self.oldKey) == nil)
            #expect(defaults.object(forKey: Self.newKey) == nil)
            #expect(defaults.object(forKey: Self.finishedOldRaw) == nil)
            #expect(defaults.object(forKey: Self.finishedNewRaw) == nil)
        }
    }

    // AC-17 (M4) ⑥: storedProgress returns stored values per key, default for the missing one
    @Test func m4_ac17_storedProgressReadsStoredValues() throws {
        try Self.withSuite { _, defaults in
            defaults.set("2025/09/11", forKey: Self.oldKey)
            let store = ReadingProgressStore(defaults: defaults)
            #expect(store.storedProgress() == ReadingProgress(
                lastSeenOld: Self.date(2025, 9, 11),
                lastSeenNew: Self.date(2020, 7, 11)
            ))
            #expect(defaults.object(forKey: Self.newKey) == nil)

            defaults.set("2020/07/13", forKey: Self.newKey)
            #expect(store.storedProgress() == ReadingProgress(
                lastSeenOld: Self.date(2025, 9, 11),
                lastSeenNew: Self.date(2020, 7, 13)
            ))
        }
    }

    // AC-17 (M4) ⑥: garbage stored value → default returned, raw "garbage" left in place
    @Test func m4_ac17_storedProgressGarbageKept() throws {
        try Self.withSuite { _, defaults in
            defaults.set("garbage", forKey: Self.oldKey)
            defaults.set("2020/7/13", forKey: Self.newKey)
            let store = ReadingProgressStore(defaults: defaults)
            #expect(store.storedProgress() == ReadingProgressStore.defaultProgress)
            #expect(defaults.string(forKey: Self.oldKey) == "garbage")
            #expect(defaults.string(forKey: Self.newKey) == "2020/7/13")
        }
    }

    // AC-17 (M4) ⑥ boundary: storedProgress agrees with load() for readable values
    @Test func m4_ac17_storedProgressMatchesLoad() throws {
        try Self.withSuite { _, defaults in
            defaults.set("2025/09/12", forKey: Self.oldKey)
            defaults.set("2020/07/14", forKey: Self.newKey)
            let store = ReadingProgressStore(defaults: defaults)
            #expect(store.storedProgress() == store.load())
        }
    }
}
