//
//  AdjacentDevotionSearchTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

/// Fake homepage for the date-search loop: search value → reply; unknown dates → 0-entry page. No network.
private actor FakeAdjacentHomepage: DevotionHTMLFetching {
    enum Reply: Sendable {
        case html(String)
        case failure(any Error)
    }

    private let search: [String: Reply]
    private let defaultSearch: String
    private(set) var requested: [URL] = []

    init(search: [String: Reply], defaultSearch: String) {
        self.search = search
        self.defaultSearch = defaultSearch
    }

    func fetchHTML(from url: URL) async throws -> String {
        requested.append(url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let value = items.first(where: { $0.name == "search" })?.value else {
            throw URLError(.badURL)
        }
        switch search[value] ?? .html(defaultSearch) {
        case .html(let html): return html
        case .failure(let error): throw error
        }
    }
}

@MainActor
struct AdjacentDevotionSearchTests {

    // MARK: - Helpers

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> DevotionDate {
        DevotionDate(year: y, month: m, day: d)
    }

    private static func searchValues(_ urls: [URL]) -> [String] {
        urls.map { url in
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "search" })?.value ?? "<none>"
        }
    }

    private static func emptyPage() throws -> String {
        try FixtureLoader.html("cast-search-date-20250914")
    }

    private static func entry(_ d: DevotionDate, no: Int, text: String = "x") -> DevotionEntry {
        DevotionEntry(date: d, weekday: nil, passageText: text, passage: nil, author: nil, articleNo: no)
    }

    // MARK: - AC-40 previousEntry

    // AC-40: proverbs-23 entries, before 09/12 → 09/11 #15155
    @Test func ac40_previousEntryLatestBefore() throws {
        let entries = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-proverbs-23"))
        let e = try #require(AdjacentDevotionSearch.previousEntry(in: entries, before: Self.date(2025, 9, 12)))
        #expect(e.date == Self.date(2025, 9, 11))
        #expect(e.articleNo == 15155)
    }

    // AC-40: the same date is excluded (strictly before) → 09/10 #15148
    @Test func ac40_previousEntryExcludesSameDate() throws {
        let entries = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-proverbs-23"))
        let e = try #require(AdjacentDevotionSearch.previousEntry(in: entries, before: Self.date(2025, 9, 11)))
        #expect(e.date == Self.date(2025, 9, 10))
        #expect(e.articleNo == 15148)
    }

    // AC-40: input order does not matter (reversed john-5) → 07/11 #11477
    @Test func ac40_previousEntryOrderIndependent() throws {
        let entries = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-john-5"))
        let forward = try #require(AdjacentDevotionSearch.previousEntry(in: entries, before: Self.date(2020, 7, 13)))
        let reversed = try #require(
            AdjacentDevotionSearch.previousEntry(in: Array(entries.reversed()), before: Self.date(2020, 7, 13)))
        #expect(reversed.date == Self.date(2020, 7, 11))
        #expect(reversed.articleNo == 11477)
        #expect(forward == reversed)
    }

    // AC-40: two entries on the same (best) date → first in input order
    @Test func ac40_previousEntryTieKeepsFirst() throws {
        let a = Self.entry(Self.date(2025, 9, 11), no: 1, text: "a")
        let b = Self.entry(Self.date(2025, 9, 11), no: 2, text: "b")
        let older = Self.entry(Self.date(2025, 9, 9), no: 3)
        #expect(AdjacentDevotionSearch.previousEntry(in: [older, a, b], before: Self.date(2025, 9, 12)) == a)
        #expect(AdjacentDevotionSearch.previousEntry(in: [b, older, a], before: Self.date(2025, 9, 12)) == b)
    }

    // AC-40: empty input → nil; every entry >= date → nil
    @Test func ac40_previousEntryNilCases() throws {
        #expect(AdjacentDevotionSearch.previousEntry(in: [], before: Self.date(2025, 9, 12)) == nil)
        let entries = [
            Self.entry(Self.date(2025, 9, 12), no: 1),
            Self.entry(Self.date(2025, 9, 13), no: 2),
        ]
        #expect(AdjacentDevotionSearch.previousEntry(in: entries, before: Self.date(2025, 9, 12)) == nil)
        let proverbs = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-proverbs-23"))
        #expect(AdjacentDevotionSearch.previousEntry(in: proverbs, before: Self.date(2008, 12, 24)) == nil)
    }

    // AC-40 boundary: across a year — before 2009/01/01 picks 2008/12/24 from proverbs-23
    @Test func ac40_previousEntryAcrossYear() throws {
        let proverbs = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-proverbs-23"))
        let e = try #require(AdjacentDevotionSearch.previousEntry(in: proverbs, before: Self.date(2009, 1, 1)))
        #expect(e.date == Self.date(2008, 12, 24))
    }

    // MARK: - AC-41 / AC-42 findPrevious hits

    // AC-41: first day back (09/11) has a result → #15155, one request
    @Test func ac41_findPreviousFirstDayHit() async throws {
        let homepage = FakeAdjacentHomepage(
            search: ["2025/09/11": .html(try FixtureLoader.html("cast-search-proverbs-23"))],
            defaultSearch: try Self.emptyPage())
        let entry = try await AdjacentDevotionSearch.findPrevious(before: Self.date(2025, 9, 12), using: homepage)

        let e = try #require(entry)
        #expect(e.date == Self.date(2025, 9, 11))
        #expect(e.articleNo == 15155)
        #expect(e.passageText == "잠언 23:24-35")
        let requested = await homepage.requested
        #expect(Self.searchValues(requested) == ["2025/09/11"])
        #expect(requested.first?.absoluteString == DevotionSearchURL.string(date: Self.date(2025, 9, 11)))
    }

    // AC-42: empty day (07/12), hit on 07/11 → 07/11 #11477, two requests in descending order
    @Test func ac42_findPreviousSecondDayHit() async throws {
        let homepage = FakeAdjacentHomepage(
            search: [
                "2020/07/12": .html(try Self.emptyPage()),
                "2020/07/11": .html(try FixtureLoader.html("cast-search-john-5")),
            ],
            defaultSearch: try Self.emptyPage())
        let entry = try await AdjacentDevotionSearch.findPrevious(before: Self.date(2020, 7, 13), using: homepage)

        let e = try #require(entry)
        #expect(e.date == Self.date(2020, 7, 11))
        #expect(e.articleNo == 11477)
        #expect(Self.searchValues(await homepage.requested) == ["2020/07/12", "2020/07/11"])
    }

    // AC-42 boundary: a page whose entries are all >= date counts as empty → next day back is requested
    @Test func ac42_onlyNewerEntriesCountsAsEmpty() async throws {
        // 09/11 returns date-20250912 (only 09/12) → not before 09/12; 09/10 returns proverbs → 09/11.
        let homepage = FakeAdjacentHomepage(
            search: [
                "2025/09/11": .html(try FixtureLoader.html("cast-search-date-20250912")),
                "2025/09/10": .html(try FixtureLoader.html("cast-search-proverbs-23")),
            ],
            defaultSearch: try Self.emptyPage())
        let entry = try await AdjacentDevotionSearch.findPrevious(before: Self.date(2025, 9, 12), using: homepage)

        let e = try #require(entry)
        #expect(e.date == Self.date(2025, 9, 11))
        #expect(e.articleNo == 15155)
        #expect(Self.searchValues(await homepage.requested) == ["2025/09/11", "2025/09/10"])
    }

    // MARK: - AC-43 window

    // AC-43: seven empty days → nil, exactly 09/11 … 09/05 descending
    @Test func ac43_sevenEmptyDaysIsNil() async throws {
        let homepage = FakeAdjacentHomepage(search: [:], defaultSearch: try Self.emptyPage())
        let entry = try await AdjacentDevotionSearch.findPrevious(before: Self.date(2025, 9, 12), using: homepage)

        #expect(entry == nil)
        #expect(Self.searchValues(await homepage.requested) == [
            "2025/09/11", "2025/09/10", "2025/09/09", "2025/09/08", "2025/09/07", "2025/09/06", "2025/09/05",
        ])
    }

    // AC-43 boundary: window crosses a month start (10/02 → 10/01, 09/30 …)
    @Test func ac43_windowCrossesMonthStart() async throws {
        let homepage = FakeAdjacentHomepage(search: [:], defaultSearch: try Self.emptyPage())
        _ = try await AdjacentDevotionSearch.findPrevious(before: Self.date(2025, 10, 2), using: homepage)
        #expect(Self.searchValues(await homepage.requested) == [
            "2025/10/01", "2025/09/30", "2025/09/29", "2025/09/28", "2025/09/27", "2025/09/26", "2025/09/25",
        ])
    }

    // AC-43 boundary: window crosses a year start (2021/01/01 → 2020/12/31 …)
    @Test func ac43_windowCrossesYearStart() async throws {
        let homepage = FakeAdjacentHomepage(search: [:], defaultSearch: try Self.emptyPage())
        _ = try await AdjacentDevotionSearch.findPrevious(before: Self.date(2021, 1, 1), using: homepage)
        let values = Self.searchValues(await homepage.requested)
        #expect(values.count == 7)
        #expect(values.first == "2020/12/31")
        #expect(values.last == "2020/12/25")
    }

    // AC-43 boundary: leap day — before 2020/03/01 → first request 2020/02/29
    @Test func ac43_windowCrossesLeapDay() async throws {
        let homepage = FakeAdjacentHomepage(search: [:], defaultSearch: try Self.emptyPage())
        _ = try await AdjacentDevotionSearch.findPrevious(before: Self.date(2020, 3, 1), using: homepage)
        let values = Self.searchValues(await homepage.requested)
        #expect(values.prefix(2) == ["2020/02/29", "2020/02/28"])
    }

    // MARK: - AC-44 errors

    // AC-44: error on day 2 (09/10) is rethrown unchanged and stops the loop
    @Test func ac44_fetchErrorStopsLoop() async throws {
        let homepage = FakeAdjacentHomepage(
            search: ["2025/09/10": .failure(URLError(.timedOut))],
            defaultSearch: try Self.emptyPage())
        do {
            _ = try await AdjacentDevotionSearch.findPrevious(before: Self.date(2025, 9, 12), using: homepage)
            Issue.record("expected URLError(.timedOut)")
        } catch let error as URLError {
            #expect(error.code == .timedOut)
        }
        #expect(Self.searchValues(await homepage.requested) == ["2025/09/11", "2025/09/10"])
    }

    // AC-44 boundary: error on day 1 → one request only
    @Test func ac44_fetchErrorOnFirstDay() async throws {
        let homepage = FakeAdjacentHomepage(
            search: ["2025/09/11": .failure(URLError(.notConnectedToInternet))],
            defaultSearch: try Self.emptyPage())
        await #expect(throws: URLError.self) {
            _ = try await AdjacentDevotionSearch.findPrevious(before: Self.date(2025, 9, 12), using: homepage)
        }
        #expect(Self.searchValues(await homepage.requested) == ["2025/09/11"])
    }

    // MARK: - AC-45 move / message / maxDays

    // AC-45: maxDays is 7, same as NextDevotionSearch
    @Test func ac45_maxDays() {
        #expect(AdjacentDevotionSearch.maxDays == 7)
        #expect(AdjacentDevotionSearch.maxDays == NextDevotionSearch.maxDays)
    }

    // AC-45: .next from 09/11 → .moved(09/12 #15157)
    @Test func ac45_moveNextFound() async throws {
        let homepage = FakeAdjacentHomepage(
            search: ["2025/09/12": .html(try FixtureLoader.html("cast-search-date-20250912"))],
            defaultSearch: try Self.emptyPage())
        let outcome = await AdjacentDevotionSearch.move(.next, from: Self.date(2025, 9, 11), using: homepage)

        guard case .moved(let e) = outcome else {
            Issue.record("expected .moved, got \(outcome)")
            return
        }
        #expect(e.date == Self.date(2025, 9, 12))
        #expect(e.articleNo == 15157)
        #expect(e.passageText == "잠언 24:1-10")
        #expect(Self.searchValues(await homepage.requested) == ["2025/09/12"])
    }

    // AC-45: .previous from 09/12 → .moved(09/11 #15155)
    @Test func ac45_movePreviousFound() async throws {
        let homepage = FakeAdjacentHomepage(
            search: ["2025/09/11": .html(try FixtureLoader.html("cast-search-proverbs-23"))],
            defaultSearch: try Self.emptyPage())
        let outcome = await AdjacentDevotionSearch.move(.previous, from: Self.date(2025, 9, 12), using: homepage)

        guard case .moved(let e) = outcome else {
            Issue.record("expected .moved, got \(outcome)")
            return
        }
        #expect(e.date == Self.date(2025, 9, 11))
        #expect(e.articleNo == 15155)
        #expect(Self.searchValues(await homepage.requested) == ["2025/09/11"])
    }

    // AC-45: all empty → .notFound in both directions, 7 requests each
    @Test(arguments: [MoveDirection.previous, .next])
    func ac45_moveNotFound(direction: MoveDirection) async throws {
        let homepage = FakeAdjacentHomepage(search: [:], defaultSearch: try Self.emptyPage())
        let outcome = await AdjacentDevotionSearch.move(direction, from: Self.date(2025, 9, 11), using: homepage)
        #expect(outcome == .notFound)
        #expect(await homepage.requested.count == 7)
    }

    // AC-45: fetch error → .networkError in both directions (never throws)
    @Test(arguments: [MoveDirection.previous, .next])
    func ac45_moveNetworkError(direction: MoveDirection) async throws {
        let homepage = FakeAdjacentHomepage(
            search: [
                "2025/09/10": .failure(URLError(.timedOut)),
                "2025/09/12": .failure(URLError(.timedOut)),
            ],
            defaultSearch: try Self.emptyPage())
        let outcome = await AdjacentDevotionSearch.move(direction, from: Self.date(2025, 9, 11), using: homepage)
        #expect(outcome == .networkError)
        #expect(await homepage.requested.count == 1)
    }

    // AC-45: message per outcome / direction
    @Test func ac45_messages() {
        let e = Self.entry(Self.date(2025, 9, 11), no: 15155)
        #expect(AdjacentDevotionSearch.message(for: .notFound, direction: .previous) == "이전 묵상을 찾지 못했습니다")
        #expect(AdjacentDevotionSearch.message(for: .notFound, direction: .next) == "다음 묵상을 찾지 못했습니다")
        #expect(AdjacentDevotionSearch.message(for: .networkError, direction: .previous) == "인터넷 연결을 확인해 주세요")
        #expect(AdjacentDevotionSearch.message(for: .networkError, direction: .next) == "인터넷 연결을 확인해 주세요")
        #expect(AdjacentDevotionSearch.message(for: .moved(e), direction: .previous) == nil)
        #expect(AdjacentDevotionSearch.message(for: .moved(e), direction: .next) == nil)
    }

    // MARK: - AC-46 same testament window

    // AC-46: old testament 09/11 — every request (both directions) within 09/04 … 09/18, none in 2020
    @Test func ac46_oldTestamentStaysInWindow() async throws {
        let homepage = FakeAdjacentHomepage(search: [:], defaultSearch: try Self.emptyPage())
        _ = await AdjacentDevotionSearch.move(.next, from: Self.date(2025, 9, 11), using: homepage)
        _ = await AdjacentDevotionSearch.move(.previous, from: Self.date(2025, 9, 11), using: homepage)

        let values = Self.searchValues(await homepage.requested)
        #expect(values.count == 14)
        let low = Self.date(2025, 9, 4)
        let high = Self.date(2025, 9, 18)
        for value in values {
            let d = try #require(DevotionDate(storageString: value))
            #expect(d >= low && d <= high, "out of window: \(value)")
        }
        #expect(values.filter { $0.hasPrefix("2020/") }.isEmpty)
        #expect(!values.contains("2025/09/11"))
    }

    // AC-46: new testament 07/13 — no 2025 requests in either direction
    @Test func ac46_newTestamentNeverSearchesOldYear() async throws {
        let homepage = FakeAdjacentHomepage(search: [:], defaultSearch: try Self.emptyPage())
        _ = await AdjacentDevotionSearch.move(.next, from: Self.date(2020, 7, 13), using: homepage)
        _ = await AdjacentDevotionSearch.move(.previous, from: Self.date(2020, 7, 13), using: homepage)

        let values = Self.searchValues(await homepage.requested)
        #expect(values.count == 14)
        #expect(values.filter { $0.hasPrefix("2025/") }.isEmpty)
        #expect(values.allSatisfy { $0.hasPrefix("2020/07/") })
    }
}
