//
//  NextDevotionSearchTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

/// Fake homepage for the date-search loop: search value → reply; unknown dates → 0-entry page. No network.
private actor FakeSearchHomepage: DevotionHTMLFetching {
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
struct NextDevotionSearchTests {

    // MARK: - Helpers

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> DevotionDate {
        DevotionDate(year: y, month: m, day: d)
    }

    private static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private static func instant(_ calendar: Calendar, _ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)))
    }

    private static func searchValues(_ urls: [URL]) -> [String?] {
        urls.map { url in
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "search" })?.value
        }
    }

    private static func emptyPage() throws -> String {
        try FixtureLoader.html("cast-search-date-20250914")
    }

    // MARK: - AC-14 search URL

    // AC-14: exact search URL string, slashes not percent-encoded
    @Test func ac14_searchURLString() {
        #expect(DevotionSearchURL.string(date: Self.date(2025, 9, 11))
            == "https://100church.org/home/board.php?board=cast&config=6&category=6&search=2025/09/11&shwhere=subject")
    }

    // AC-14 boundary: single-digit month/day are zero-padded
    @Test func ac14_searchURLZeroPads() {
        #expect(DevotionSearchURL.string(date: Self.date(2020, 7, 3))
            == "https://100church.org/home/board.php?board=cast&config=6&category=6&search=2020/07/03&shwhere=subject")
    }

    // AC-14: url(date:) carries the decoded search / shwhere values and matches string(date:)
    @Test func ac14_searchURLQueryItems() throws {
        let url = try #require(DevotionSearchURL.url(date: Self.date(2025, 9, 11)))
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(comps.queryItems?.first(where: { $0.name == "search" })?.value == "2025/09/11")
        #expect(comps.queryItems?.first(where: { $0.name == "shwhere" })?.value == "subject")
        #expect(comps.queryItems?.first(where: { $0.name == "board" })?.value == "cast")
        #expect(url.absoluteString == DevotionSearchURL.string(date: Self.date(2025, 9, 11)))
    }

    // MARK: - AC-15 date arithmetic

    // AC-15: addingDays(1) across month / year / leap-day boundaries
    @Test(arguments: [
        ((2025, 9, 10), (2025, 9, 11)),
        ((2025, 9, 30), (2025, 10, 1)),
        ((2020, 12, 31), (2021, 1, 1)),
        ((2020, 2, 28), (2020, 2, 29)),
        ((2021, 2, 28), (2021, 3, 1)),
    ])
    func ac15_addingOneDay(from: (Int, Int, Int), to: (Int, Int, Int)) {
        #expect(Self.date(from.0, from.1, from.2).addingDays(1) == Self.date(to.0, to.1, to.2))
    }

    // AC-15: addingDays(7) and addingDays(0)
    @Test func ac15_addingSevenAndZeroDays() {
        #expect(Self.date(2025, 9, 10).addingDays(7) == Self.date(2025, 9, 17))
        #expect(Self.date(2025, 9, 10).addingDays(0) == Self.date(2025, 9, 10))
        #expect(Self.date(2020, 2, 29).addingDays(0) == Self.date(2020, 2, 29))
    }

    // AC-15 boundary: leap-day itself rolls into March
    @Test func ac15_leapDayRollsOver() {
        #expect(Self.date(2020, 2, 29).addingDays(1) == Self.date(2020, 3, 1))
    }

    // AC-15: local calendar day follows the calendar's time zone (KST midnight boundary)
    @Test func ac15_localDayOfKST() throws {
        let kst = Self.calendar("Asia/Seoul")
        let before = try Self.instant(kst, 2026, 11, 20, 23, 50)
        let after = try Self.instant(kst, 2026, 11, 21, 0, 10)
        #expect(DevotionDate(localDayOf: before, calendar: kst) == Self.date(2026, 11, 20))
        #expect(DevotionDate(localDayOf: after, calendar: kst) == Self.date(2026, 11, 21))
    }

    // AC-15: the same instant (KST 2026-11-21 00:10 = UTC 2026-11-20 15:10) seen in a UTC calendar is 11/20
    @Test func ac15_localDayOfUsesCalendarTimeZone() throws {
        let kst = Self.calendar("Asia/Seoul")
        let utc = Self.calendar("UTC")
        let instant = try Self.instant(utc, 2026, 11, 20, 15, 10)
        let sameInKST = try Self.instant(kst, 2026, 11, 21, 0, 10)
        #expect(instant == sameInKST)
        #expect(DevotionDate(localDayOf: instant, calendar: utc) == Self.date(2026, 11, 20))
        #expect(DevotionDate(localDayOf: instant, calendar: kst) == Self.date(2026, 11, 21))
    }

    // MARK: - AC-16 search loop

    // AC-16: maxDays is 7
    @Test func ac16_maxDays() {
        #expect(NextDevotionSearch.maxDays == 7)
    }

    // AC-16 ①: first day has a result → that entry, one request
    @Test func ac16_firstDayHit() async throws {
        let homepage = FakeSearchHomepage(
            search: ["2025/09/11": .html(try FixtureLoader.html("cast-search-proverbs-23"))],
            defaultSearch: try Self.emptyPage())
        let entry = try await NextDevotionSearch.findNext(after: Self.date(2025, 9, 10), using: homepage)

        let e = try #require(entry)
        #expect(e.date == Self.date(2025, 9, 11))
        #expect(e.articleNo == 15155)
        #expect(e.passageText == "잠언 23:24-35")
        let requested = await homepage.requested
        #expect(Self.searchValues(requested) == ["2025/09/11"])
        #expect(requested.first?.absoluteString == DevotionSearchURL.string(date: Self.date(2025, 9, 11)))
    }

    // AC-16 ②: empty first day, hit on the second → 07/13 entry, two requests in order
    @Test func ac16_secondDayHit() async throws {
        let homepage = FakeSearchHomepage(
            search: [
                "2020/07/12": .html(try Self.emptyPage()),
                "2020/07/13": .html(try FixtureLoader.html("cast-search-john-5")),
            ],
            defaultSearch: try Self.emptyPage())
        let entry = try await NextDevotionSearch.findNext(after: Self.date(2020, 7, 11), using: homepage)

        let e = try #require(entry)
        #expect(e.date == Self.date(2020, 7, 13))
        #expect(e.articleNo == 11480)
        #expect(e.passageText == "요한복음 5:30-47")
        #expect(Self.searchValues(await homepage.requested) == ["2020/07/12", "2020/07/13"])
    }

    // AC-16 ③: seven empty days → nil, exactly seven requests (09/11 … 09/17)
    @Test func ac16_sevenEmptyDaysIsNil() async throws {
        let homepage = FakeSearchHomepage(search: [:], defaultSearch: try Self.emptyPage())
        let entry = try await NextDevotionSearch.findNext(after: Self.date(2025, 9, 10), using: homepage)

        #expect(entry == nil)
        #expect(Self.searchValues(await homepage.requested) == [
            "2025/09/11", "2025/09/12", "2025/09/13", "2025/09/14", "2025/09/15", "2025/09/16", "2025/09/17",
        ])
    }

    // AC-16 ④: error on day 2 is rethrown unchanged and stops the loop (no day-3 request)
    @Test func ac16_fetchErrorStopsLoop() async throws {
        let homepage = FakeSearchHomepage(
            search: ["2025/09/12": .failure(URLError(.timedOut))],
            defaultSearch: try Self.emptyPage())
        do {
            _ = try await NextDevotionSearch.findNext(after: Self.date(2025, 9, 10), using: homepage)
            Issue.record("expected URLError(.timedOut)")
        } catch let error as URLError {
            #expect(error.code == .timedOut)
        }
        #expect(Self.searchValues(await homepage.requested) == ["2025/09/11", "2025/09/12"])
    }

    // AC-16 ④ boundary: error on day 1 → one request only
    @Test func ac16_fetchErrorOnFirstDay() async throws {
        let homepage = FakeSearchHomepage(
            search: ["2025/09/11": .failure(URLError(.notConnectedToInternet))],
            defaultSearch: try Self.emptyPage())
        await #expect(throws: URLError.self) {
            _ = try await NextDevotionSearch.findNext(after: Self.date(2025, 9, 10), using: homepage)
        }
        #expect(await homepage.requested.count == 1)
    }

    // AC-16 ⑤: a page whose entries are all <= lastSeen counts as "no result" → next day is requested
    @Test func ac16_onlyOlderEntriesCountsAsEmpty() async throws {
        let homepage = FakeSearchHomepage(
            search: ["2025/09/12": .html(try FixtureLoader.html("cast-search-proverbs-23"))],
            defaultSearch: try Self.emptyPage())
        let entry = try await NextDevotionSearch.findNext(after: Self.date(2025, 9, 11), using: homepage)

        #expect(entry == nil)
        let values = Self.searchValues(await homepage.requested)
        #expect(values.count == 7)
        #expect(values.prefix(2) == ["2025/09/12", "2025/09/13"])
        #expect(values.last == "2025/09/18")
    }

    // AC-16 boundary: search window crosses a month end (09/30 → 10/01 …)
    @Test func ac16_windowCrossesMonthEnd() async throws {
        let homepage = FakeSearchHomepage(search: [:], defaultSearch: try Self.emptyPage())
        _ = try await NextDevotionSearch.findNext(after: Self.date(2025, 9, 29), using: homepage)
        #expect(Self.searchValues(await homepage.requested) == [
            "2025/09/30", "2025/10/01", "2025/10/02", "2025/10/03", "2025/10/04", "2025/10/05", "2025/10/06",
        ])
    }

    // AC-16 boundary: picker inside the loop picks the earliest date > lastSeen from a multi-entry page
    @Test func ac16_picksEarliestNewerEntryOnPage() async throws {
        // Day 1 (2020/07/11) returns the john-5 page (07/13, 07/11, 07/10, …): with lastSeen 07/10 the answer is 07/11.
        let homepage = FakeSearchHomepage(
            search: ["2020/07/11": .html(try FixtureLoader.html("cast-search-john-5"))],
            defaultSearch: try Self.emptyPage())
        let entry = try await NextDevotionSearch.findNext(after: Self.date(2020, 7, 10), using: homepage)
        let e = try #require(entry)
        #expect(e.date == Self.date(2020, 7, 11))
        #expect(e.articleNo == 11477)
        #expect(await homepage.requested.count == 1)
    }
}
