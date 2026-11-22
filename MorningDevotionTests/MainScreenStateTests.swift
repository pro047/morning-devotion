//
//  MainScreenStateTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

/// Fake homepage for MainRowLoader: search value → reply; unknown dates → 0-entry page. No network.
private actor FakeRowHomepage: DevotionHTMLFetching {
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
struct MainScreenStateTests {

    // MARK: - Helpers

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> DevotionDate {
        DevotionDate(year: y, month: m, day: d)
    }

    private static func kst() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private static func instant(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) throws -> Date {
        try #require(kst().date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)))
    }

    private static func emptyPage() throws -> String {
        try FixtureLoader.html("cast-search-date-20250914")
    }

    private static func searchValues(_ urls: [URL]) -> [String?] {
        urls.map { url in
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "search" })?.value
        }
    }

    /// 2025/09/11(목) 잠언 23:24-35, no=15155.
    private static func entry0911(weekday: String? = "목") -> DevotionEntry {
        DevotionEntry(date: date(2025, 9, 11), weekday: weekday, passageText: "잠언 23:24-35",
                      passage: nil, author: nil, articleNo: 15155)
    }

    private static func content(_ row: MainRowState) -> MainRowContent? {
        if case .ready(let c) = row { return c }
        return nil
    }

    private static func readyRow(isRead: Bool) -> MainRowState {
        .ready(MainRowContent(testament: .oldTestament, entry: entry0911(), isRead: isRead))
    }

    // MARK: - AC-3 title format

    // AC-3: displayDate / displayTitle with and without weekday
    @Test func ac3_displayTitleFormat() {
        #expect(Self.entry0911().displayDate == "2025/09/11(목)")
        #expect(Self.entry0911().displayTitle == "2025/09/11(목) 잠언 23:24-35")
        #expect(Self.entry0911(weekday: nil).displayDate == "2025/09/11")
        #expect(Self.entry0911(weekday: nil).displayTitle == "2025/09/11 잠언 23:24-35")
    }

    // AC-3 boundary: single-digit month/day stay zero-padded in the title
    @Test func ac3_displayTitleZeroPads() {
        let e = DevotionEntry(date: Self.date(2020, 7, 3), weekday: "금", passageText: "요한복음 4:1-10",
                              passage: nil, author: nil)
        #expect(e.displayTitle == "2020/07/03(금) 요한복음 4:1-10")
    }

    // AC-3: MainRowContent.title is the entry's displayTitle; testament display names
    @Test func ac3_rowTitleAndTestamentNames() {
        let c = MainRowContent(testament: .newTestament, entry: Self.entry0911(), isRead: false)
        #expect(c.title == Self.entry0911().displayTitle)
        #expect(c.title == "2025/09/11(목) 잠언 23:24-35")
        #expect(Testament.oldTestament.displayName == "구약")
        #expect(Testament.newTestament.displayName == "신약")
    }

    // MARK: - AC-4 "지금"

    // AC-4: KST 00:00 / 11:59 → old, 12:00 / 23:59 → new
    @Test func ac4_nowTestamentBoundaries() throws {
        let cal = Self.kst()
        #expect(MainRowRules.nowTestament(at: try Self.instant(2026, 11, 20, 0, 0), calendar: cal) == .oldTestament)
        #expect(MainRowRules.nowTestament(at: try Self.instant(2026, 11, 20, 11, 59), calendar: cal) == .oldTestament)
        #expect(MainRowRules.nowTestament(at: try Self.instant(2026, 11, 20, 12, 0), calendar: cal) == .newTestament)
        #expect(MainRowRules.nowTestament(at: try Self.instant(2026, 11, 20, 23, 59), calendar: cal) == .newTestament)
    }

    // MARK: - AC-5 refreshed / messages

    // AC-5: finished today and entry is lastSeen → read; entry kept
    @Test func ac5_refreshedMarksRead() {
        let result = MainRowRules.refreshed(
            Self.readyRow(isRead: false),
            lastSeen: Self.date(2025, 9, 11), finishedDay: Self.date(2026, 11, 20), today: Self.date(2026, 11, 20))
        #expect(result == Self.readyRow(isRead: true))
    }

    // AC-5: finished nil / yesterday → not read
    @Test func ac5_refreshedNotFinishedToday() {
        let nilFinished = MainRowRules.refreshed(
            Self.readyRow(isRead: false),
            lastSeen: Self.date(2025, 9, 11), finishedDay: nil, today: Self.date(2026, 11, 20))
        #expect(nilFinished == Self.readyRow(isRead: false))
        let yesterday = MainRowRules.refreshed(
            Self.readyRow(isRead: false),
            lastSeen: Self.date(2025, 9, 11), finishedDay: Self.date(2026, 11, 19), today: Self.date(2026, 11, 20))
        #expect(yesterday == Self.readyRow(isRead: false))
    }

    // AC-5: lastSeen differs from the row's entry → not read
    @Test func ac5_refreshedLastSeenMismatch() {
        let result = MainRowRules.refreshed(
            Self.readyRow(isRead: false),
            lastSeen: Self.date(2025, 9, 10), finishedDay: Self.date(2026, 11, 20), today: Self.date(2026, 11, 20))
        #expect(result == Self.readyRow(isRead: false))
    }

    // AC-5 boundary: isRead is recomputed, not sticky (read row → not read when finishedDay is gone)
    @Test func ac5_refreshedClearsStaleRead() {
        let result = MainRowRules.refreshed(
            Self.readyRow(isRead: true),
            lastSeen: Self.date(2025, 9, 11), finishedDay: nil, today: Self.date(2026, 11, 20))
        #expect(result == Self.readyRow(isRead: false))
    }

    // AC-5: non-ready states are returned unchanged
    @Test(arguments: [MainRowState.networkError, .noNextDevotion, .loading])
    func ac5_refreshedKeepsOtherStates(row: MainRowState) {
        let result = MainRowRules.refreshed(
            row, lastSeen: Self.date(2025, 9, 11), finishedDay: Self.date(2026, 11, 20), today: Self.date(2026, 11, 20))
        #expect(result == row)
    }

    // AC-5: row messages
    @Test func ac5_rowMessages() {
        #expect(MainRowState.networkError.message == "인터넷 연결을 확인해 주세요")
        #expect(MainRowState.noNextDevotion.message == "다음 묵상을 찾지 못했습니다")
        #expect(MainRowState.loading.message == nil)
        #expect(Self.readyRow(isRead: false).message == nil)
    }

    // MARK: - MainRowLoader (FR-2 branches; backs AC-10 / AC-25 / AC-21 / AC-22)

    // AC-10 (loader): finished today → one search on lastSeen, read row
    @Test func ac10_loaderReadBranchSearchesLastSeenOnce() async throws {
        let homepage = FakeRowHomepage(
            search: ["2025/09/11": .html(try FixtureLoader.html("cast-search-proverbs-23"))],
            defaultSearch: try Self.emptyPage())

        let row = await MainRowLoader.load(
            .oldTestament, lastSeen: Self.date(2025, 9, 11), finishedDay: Self.date(2026, 11, 20),
            today: Self.date(2026, 11, 20), using: homepage)

        let c = try #require(Self.content(row))
        #expect(c.testament == .oldTestament)
        #expect(c.isRead == true)
        #expect(c.title == "2025/09/11(목) 잠언 23:24-35")
        #expect(c.entry.articleNo == 15155)
        #expect(Self.searchValues(await homepage.requested) == ["2025/09/11"])
    }

    // AC-6 (loader): not finished today → next-devotion search after lastSeen, unread row
    @Test func ac6_loaderNextBranchFindsNext() async throws {
        let homepage = FakeRowHomepage(
            search: ["2025/09/11": .html(try FixtureLoader.html("cast-search-proverbs-23"))],
            defaultSearch: try Self.emptyPage())

        let row = await MainRowLoader.load(
            .oldTestament, lastSeen: Self.date(2025, 9, 10), finishedDay: Self.date(2026, 11, 19),
            today: Self.date(2026, 11, 20), using: homepage)

        let c = try #require(Self.content(row))
        #expect(c.testament == .oldTestament)
        #expect(c.isRead == false)
        #expect(c.title == "2025/09/11(목) 잠언 23:24-35")
        #expect(c.entry.articleNo == 15155)
        #expect(Self.searchValues(await homepage.requested) == ["2025/09/11"])
    }

    // AC-25 (loader): read branch with no entry on lastSeen → networkError (design default)
    @Test func ac25_loaderReadBranchMissingEntryIsNetworkError() async throws {
        let homepage = FakeRowHomepage(search: [:], defaultSearch: try Self.emptyPage())

        let row = await MainRowLoader.load(
            .oldTestament, lastSeen: Self.date(2025, 9, 11), finishedDay: Self.date(2026, 11, 20),
            today: Self.date(2026, 11, 20), using: homepage)

        #expect(row == .networkError)
        #expect(Self.searchValues(await homepage.requested) == ["2025/09/11"])
    }

    // AC-21 (loader): any thrown fetch error → networkError (both branches)
    @Test func ac21_loaderFetchErrorIsNetworkError() async throws {
        let failing = FakeRowHomepage(
            search: ["2025/09/11": .failure(URLError(.notConnectedToInternet))],
            defaultSearch: try Self.emptyPage())

        let next = await MainRowLoader.load(
            .oldTestament, lastSeen: Self.date(2025, 9, 10), finishedDay: nil,
            today: Self.date(2026, 11, 20), using: failing)
        let read = await MainRowLoader.load(
            .oldTestament, lastSeen: Self.date(2025, 9, 11), finishedDay: Self.date(2026, 11, 20),
            today: Self.date(2026, 11, 20), using: failing)

        #expect(next == .networkError)
        #expect(read == .networkError)
    }

    // AC-22 (loader): seven empty days → noNextDevotion
    @Test func ac22_loaderNoNextDevotion() async throws {
        let homepage = FakeRowHomepage(search: [:], defaultSearch: try Self.emptyPage())

        let row = await MainRowLoader.load(
            .oldTestament, lastSeen: Self.date(2025, 9, 10), finishedDay: nil,
            today: Self.date(2026, 11, 20), using: homepage)

        #expect(row == .noNextDevotion)
        #expect(await homepage.requested.count == 7)
    }
}
