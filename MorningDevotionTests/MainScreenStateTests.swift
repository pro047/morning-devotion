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

    // AC-50 (rewrites AC-5): entry date <= lastSeen → read; entry kept
    @Test func ac50_refreshedMarksReadWhenDateAtOrBeforeLastSeen() {
        let equal = MainRowRules.refreshed(Self.readyRow(isRead: false), lastSeen: Self.date(2025, 9, 11))
        #expect(equal == Self.readyRow(isRead: true))
        let after = MainRowRules.refreshed(Self.readyRow(isRead: false), lastSeen: Self.date(2025, 9, 12))
        #expect(after == Self.readyRow(isRead: true))
        // Far ahead (other year) is still "<=".
        let farAhead = MainRowRules.refreshed(Self.readyRow(isRead: false), lastSeen: Self.date(2026, 1, 1))
        #expect(farAhead == Self.readyRow(isRead: true))
    }

    // AC-50 / AC-5: lastSeen before the row's entry → not read
    @Test func ac5_refreshedLastSeenMismatch() {
        let result = MainRowRules.refreshed(Self.readyRow(isRead: false), lastSeen: Self.date(2025, 9, 10))
        #expect(result == Self.readyRow(isRead: false))
    }

    // AC-50 boundary: isRead is recomputed, not sticky (read row + lastSeen 09/10 → not read)
    @Test func ac5_refreshedClearsStaleRead() {
        let result = MainRowRules.refreshed(Self.readyRow(isRead: true), lastSeen: Self.date(2025, 9, 10))
        #expect(result == Self.readyRow(isRead: false))
        // Month boundary: lastSeen 08/31 < 09/11 → not read; 09/30 → read
        #expect(MainRowRules.refreshed(Self.readyRow(isRead: true), lastSeen: Self.date(2025, 8, 31))
            == Self.readyRow(isRead: false))
        #expect(MainRowRules.refreshed(Self.readyRow(isRead: false), lastSeen: Self.date(2025, 9, 30))
            == Self.readyRow(isRead: true))
    }

    // AC-50 / AC-5: non-ready states are returned unchanged
    @Test(arguments: [MainRowState.networkError, .noNextDevotion, .loading])
    func ac5_refreshedKeepsOtherStates(row: MainRowState) {
        let result = MainRowRules.refreshed(row, lastSeen: Self.date(2025, 9, 11))
        #expect(result == row)
    }

    // MARK: - AC-51 returnAction

    // AC-51: .ready + basis != lastSeen → reload
    @Test func ac51_returnActionReloadsWhenBasisChanged() {
        let action = MainRowRules.returnAction(
            Self.readyRow(isRead: false), basis: Self.date(2025, 9, 10), lastSeen: Self.date(2025, 9, 11))
        #expect(action == .reload)
        // basis moved backwards relative to lastSeen also differs → reload
        let back = MainRowRules.returnAction(
            Self.readyRow(isRead: false), basis: Self.date(2025, 9, 12), lastSeen: Self.date(2025, 9, 11))
        #expect(back == .reload)
    }

    // AC-51: .ready + basis == lastSeen → keep(refreshed)
    @Test func ac51_returnActionKeepsRefreshedWhenBasisSame() {
        let action = MainRowRules.returnAction(
            Self.readyRow(isRead: false), basis: Self.date(2025, 9, 11), lastSeen: Self.date(2025, 9, 11))
        #expect(action == .keep(Self.readyRow(isRead: true)))
        // Stale read flag is recomputed too: row 09/11 read, basis = lastSeen = 09/10 → not read
        let stale = MainRowRules.returnAction(
            Self.readyRow(isRead: true), basis: Self.date(2025, 9, 10), lastSeen: Self.date(2025, 9, 10))
        #expect(stale == .keep(Self.readyRow(isRead: false)))
    }

    // AC-51: .ready + basis nil → reload
    @Test func ac51_returnActionNilBasisReloads() {
        let action = MainRowRules.returnAction(
            Self.readyRow(isRead: false), basis: nil, lastSeen: Self.date(2025, 9, 11))
        #expect(action == .reload)
    }

    // AC-51: non-ready rows are kept as is, basis ignored (differs / nil)
    @Test(arguments: [MainRowState.networkError, .noNextDevotion, .loading])
    func ac51_returnActionKeepsOtherStates(row: MainRowState) {
        #expect(MainRowRules.returnAction(row, basis: Self.date(2025, 9, 10), lastSeen: Self.date(2025, 9, 11))
            == .keep(row))
        #expect(MainRowRules.returnAction(row, basis: nil, lastSeen: Self.date(2025, 9, 11)) == .keep(row))
        #expect(MainRowRules.returnAction(row, basis: Self.date(2025, 9, 11), lastSeen: Self.date(2025, 9, 11))
            == .keep(row))
    }

    // AC-5: row messages
    @Test func ac5_rowMessages() {
        #expect(MainRowState.networkError.message == "인터넷 연결을 확인해 주세요")
        #expect(MainRowState.noNextDevotion.message == "다음 묵상을 찾지 못했습니다")
        #expect(MainRowState.loading.message == nil)
        #expect(Self.readyRow(isRead: false).message == nil)
    }

    // MARK: - MainRowLoader (always next after lastSeen; backs AC-49 / AC-21 / AC-22)

    // AC-49: lastSeen 09/11 → next is 09/12 #15157, unread; no re-search of 09/11
    @Test func ac49_loaderAlwaysSearchesNextAfterLastSeen() async throws {
        let homepage = FakeRowHomepage(
            search: [
                "2025/09/11": .html(try FixtureLoader.html("cast-search-proverbs-23")),
                "2025/09/12": .html(try FixtureLoader.html("cast-search-date-20250912")),
            ],
            defaultSearch: try Self.emptyPage())

        let row = await MainRowLoader.load(.oldTestament, lastSeen: Self.date(2025, 9, 11), using: homepage)

        let c = try #require(Self.content(row))
        #expect(c.testament == .oldTestament)
        #expect(c.isRead == false)
        #expect(c.title == "2025/09/12(금) 잠언 24:1-10")
        #expect(c.entry.articleNo == 15157)
        #expect(Self.searchValues(await homepage.requested) == ["2025/09/12"])
    }

    // AC-49 / AC-6 (loader): lastSeen 09/10 → next-devotion search after lastSeen, unread row
    @Test func ac6_loaderNextBranchFindsNext() async throws {
        let homepage = FakeRowHomepage(
            search: ["2025/09/11": .html(try FixtureLoader.html("cast-search-proverbs-23"))],
            defaultSearch: try Self.emptyPage())

        let row = await MainRowLoader.load(.oldTestament, lastSeen: Self.date(2025, 9, 10), using: homepage)

        let c = try #require(Self.content(row))
        #expect(c.testament == .oldTestament)
        #expect(c.isRead == false)
        #expect(c.title == "2025/09/11(목) 잠언 23:24-35")
        #expect(c.entry.articleNo == 15155)
        #expect(Self.searchValues(await homepage.requested) == ["2025/09/11"])
    }

    // AC-49: new testament row carries its testament
    @Test func ac49_loaderNewTestamentRow() async throws {
        let homepage = FakeRowHomepage(
            search: ["2020/07/12": .html(try FixtureLoader.html("cast-search-john-5"))],
            defaultSearch: try Self.emptyPage())

        let row = await MainRowLoader.load(.newTestament, lastSeen: Self.date(2020, 7, 11), using: homepage)

        let c = try #require(Self.content(row))
        #expect(c.testament == .newTestament)
        #expect(c.isRead == false)
        #expect(c.entry.date == Self.date(2020, 7, 13))
        #expect(c.entry.articleNo == 11480)
    }

    // AC-49 / AC-21 (loader): any thrown fetch error → networkError
    @Test func ac21_loaderFetchErrorIsNetworkError() async throws {
        let failing = FakeRowHomepage(
            search: ["2025/09/11": .failure(URLError(.notConnectedToInternet))],
            defaultSearch: try Self.emptyPage())

        let next = await MainRowLoader.load(.oldTestament, lastSeen: Self.date(2025, 9, 10), using: failing)

        #expect(next == .networkError)
        #expect(Self.searchValues(await failing.requested) == ["2025/09/11"])
    }

    // AC-49 / AC-22 (loader): seven empty days → noNextDevotion, seven requests
    @Test func ac22_loaderNoNextDevotion() async throws {
        let homepage = FakeRowHomepage(search: [:], defaultSearch: try Self.emptyPage())

        let row = await MainRowLoader.load(.oldTestament, lastSeen: Self.date(2025, 9, 10), using: homepage)

        #expect(row == .noNextDevotion)
        #expect(Self.searchValues(await homepage.requested) == [
            "2025/09/11", "2025/09/12", "2025/09/13", "2025/09/14", "2025/09/15", "2025/09/16", "2025/09/17",
        ])
    }

    // MARK: - AC-70 arrows per row (US-1, US-5, FR-10)

    // AC-70: .ready → both, .noNextDevotion → previous only, .loading / .networkError → none
    @Test func ac70_arrowsPerRow() {
        #expect(MainRowRules.arrows(for: Self.readyRow(isRead: false)) == .both)
        #expect(MainRowRules.arrows(for: Self.readyRow(isRead: true)) == .both)
        #expect(MainRowRules.arrows(for: .noNextDevotion) == .previousOnly)
        #expect(MainRowRules.arrows(for: .loading) == NavArrows.none)
        #expect(MainRowRules.arrows(for: .networkError) == NavArrows.none)
    }

    // AC-70: NavArrows constants and allows(_:)
    @Test func ac70_navArrowsAllows() {
        #expect(NavArrows.previousOnly.allows(.previous) == true)
        #expect(NavArrows.previousOnly.allows(.next) == false)
        #expect(NavArrows.none.allows(.previous) == false)
        #expect(NavArrows.none.allows(.next) == false)
        #expect(NavArrows.both.allows(.previous) == true)
        #expect(NavArrows.both.allows(.next) == true)

        #expect(NavArrows.none == NavArrows(previous: false, next: false))
        #expect(NavArrows.both == NavArrows(previous: true, next: true))
        #expect(NavArrows.previousOnly == NavArrows(previous: true, next: false))
        #expect(NavArrows.previousOnly != NavArrows.both)
        #expect(NavArrows(previous: false, next: true).allows(.next) == true)
        #expect(NavArrows(previous: false, next: true).allows(.previous) == false)
    }
}
