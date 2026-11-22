//
//  MainScreenModelTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

/// Fake homepage. Search URL → `search` table by `search=` value (unknown → 0-entry page).
/// Article URL → `article` table by `no=` value (unknown → URLError(.fileDoesNotExist)). No network.
private actor FakeHomepage: DevotionHTMLFetching {
    enum Reply: Sendable {
        case html(String)
        case failure(any Error)
    }

    private var search: [String: Reply]
    private var article: [Int: Reply]
    private let defaultSearch: String
    private(set) var requested: [URL] = []

    init(search: [String: Reply] = [:], article: [Int: Reply] = [:], defaultSearch: String) {
        self.search = search
        self.article = article
        self.defaultSearch = defaultSearch
    }

    func setSearch(_ date: String, _ reply: Reply) { search[date] = reply }
    func setArticle(_ no: Int, _ reply: Reply) { article[no] = reply }

    func fetchHTML(from url: URL) async throws -> String {
        requested.append(url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let reply: Reply
        if let noText = items.first(where: { $0.name == "no" })?.value, let no = Int(noText) {
            guard let r = article[no] else { throw URLError(.fileDoesNotExist) }
            reply = r
        } else if let date = items.first(where: { $0.name == "search" })?.value {
            reply = search[date] ?? .html(defaultSearch)
        } else {
            throw URLError(.badURL)
        }
        switch reply {
        case .html(let html): return html
        case .failure(let error): throw error
        }
    }
}

/// Fake YouTube searcher: one fixed reply, records requests. No network.
private actor FakeYouTube: YouTubeSearchFetching {
    private let data: Data
    private(set) var requested: [URL] = []

    init(_ data: Data) { self.data = data }

    func fetchSearchResponse(from url: URL) async throws -> Data {
        requested.append(url)
        return data
    }
}

@MainActor
private final class TestClock {
    var now: Date
    init(_ now: Date) { self.now = now }
}

/// One isolated UserDefaults suite + clock + KST calendar per test.
@MainActor
private final class Env {
    static let rawKeys = [
        "readingProgress.lastSeenOld",
        "readingProgress.lastSeenNew",
        "readingProgress.finishedDayOld",
        "readingProgress.finishedDayNew",
    ]

    let suiteName = "test.\(UUID().uuidString)"
    let defaults: UserDefaults
    let store: ReadingProgressStore
    let calendar: Calendar
    let clock: TestClock

    init(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        store = ReadingProgressStore(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        self.calendar = calendar
        clock = TestClock(try #require(calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))))
    }

    func setTime(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) throws {
        clock.now = try #require(calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)))
    }

    func model(homepage: FakeHomepage, youtube: FakeYouTube, apiKey: String? = "k") -> MainScreenModel {
        let clock = self.clock
        return MainScreenModel(
            store: store,
            fetcher: homepage,
            searcher: youtube,
            apiKey: apiKey,
            calendar: calendar,
            now: { clock.now }
        )
    }

    /// AC-10 store: old read 2025/09/11, finished 2026/11/20 (raw values written directly).
    func seedOldReadOn20261120() {
        defaults.set("2025/09/11", forKey: "readingProgress.lastSeenOld")
        defaults.set("2026/11/20", forKey: "readingProgress.finishedDayOld")
    }

    /// Raw stored values of the four readingProgress.* keys (nil = absent).
    func rawSnapshot() -> [String?] {
        Self.rawKeys.map { key in defaults.object(forKey: key).map { "\($0)" } }
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
struct MainScreenModelTests {

    // MARK: - Helpers

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> DevotionDate {
        DevotionDate(year: y, month: m, day: d)
    }

    private static func html(_ name: String) throws -> String {
        try FixtureLoader.html(name)
    }

    private static func emptyPage() throws -> String {
        try html("cast-search-date-20250914")
    }

    private static func article(_ name: String) throws -> DevotionArticle {
        try #require(DevotionArticleParser.parse(html: try html(name)))
    }

    private static func youtube() throws -> FakeYouTube {
        FakeYouTube(try FixtureLoader.data("yt-search-20200713", ext: "json"))
    }

    /// 기본 홈페이지 (DESIGN §7): searches 2025/09/11, 2020/07/12 (0건), 2020/07/13, 2025/09/12;
    /// articles 15155, 11480, 15157 (→ body-15155 stand-in).
    private static func standardHomepage() throws -> FakeHomepage {
        FakeHomepage(
            search: [
                "2025/09/11": .html(try html("cast-search-proverbs-23")),
                "2020/07/12": .html(try emptyPage()),
                "2020/07/13": .html(try html("cast-search-john-5")),
                "2025/09/12": .html(try html("cast-search-date-20250912")),
            ],
            article: [
                15155: .html(try html("cast-body-15155")),
                11480: .html(try html("cast-body-11480")),
                15157: .html(try html("cast-body-15155")),
            ],
            defaultSearch: try emptyPage())
    }

    private static func query(_ url: URL, _ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == name })?.value
    }

    /// "search=<date>" / "no=<n>", sorted (two rows load concurrently, so order is not asserted).
    private static func describeSorted(_ urls: [URL]) -> [String] {
        urls.map { url in
            if let no = query(url, "no") { return "no=\(no)" }
            return "search=\(query(url, "search") ?? "?")"
        }.sorted()
    }

    private static func count(_ urls: [URL], _ item: String) -> Int {
        describeSorted(urls).filter { $0 == item }.count
    }

    private static func content(_ row: MainRowState) -> MainRowContent? {
        if case .ready(let c) = row { return c }
        return nil
    }

    private static func screenContent(_ state: DevotionScreenState) -> DevotionScreenContent? {
        if case .showing(let c) = state { return c }
        return nil
    }

    private static let oldTitle0911 = "2025/09/11(목) 잠언 23:24-35"
    private static let newTitle0713 = "2020/07/13(월) 요한복음 5:30-47"
    private static let oldTitle0912 = "2025/09/12(금) 잠언 24:1-10"

    // MARK: - AC-6 first load

    // AC-6 (US-1 기준 2·4): empty store 07:00 → both rows ready/unread, only list searches, no writes
    @Test func ac6_loadShowsBothRows() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.standardHomepage()
        let youtube = try Self.youtube()
        let model = env.model(homepage: homepage, youtube: youtube)

        #expect(model.oldRow == .loading)
        #expect(model.newRow == .loading)
        await model.load()

        let old = try #require(Self.content(model.oldRow))
        #expect(old.testament == .oldTestament)
        #expect(old.title == Self.oldTitle0911)
        #expect(old.entry.articleNo == 15155)
        #expect(old.isRead == false)
        let new = try #require(Self.content(model.newRow))
        #expect(new.testament == .newTestament)
        #expect(new.title == Self.newTitle0713)
        #expect(new.entry.articleNo == 11480)
        #expect(new.isRead == false)
        #expect(model.row(for: .oldTestament) == model.oldRow)
        #expect(model.row(for: .newTestament) == model.newRow)

        let requested = await homepage.requested
        #expect(Self.describeSorted(requested) == ["search=2020/07/12", "search=2020/07/13", "search=2025/09/11"])
        #expect(await youtube.requested.count == 0)
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
    }

    // MARK: - AC-7 "지금"

    // AC-7 (FR-4): exactly one row is "now"; flips at 12:00
    @Test func ac7_isNowExactlyOne() throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let model = env.model(homepage: try Self.standardHomepage(), youtube: try Self.youtube())

        #expect(model.isNow(.oldTestament) == true)
        #expect(model.isNow(.newTestament) == false)
        try env.setTime(2026, 11, 20, 11, 59)
        #expect(model.isNow(.oldTestament) == true)
        #expect(model.isNow(.newTestament) == false)
        try env.setTime(2026, 11, 20, 12, 0)
        #expect(model.isNow(.oldTestament) == false)
        #expect(model.isNow(.newTestament) == true)
        try env.setTime(2026, 11, 20, 23, 59)
        #expect(model.isNow(.oldTestament) == false)
        #expect(model.isNow(.newTestament) == true)
    }

    // MARK: - AC-8 opening a row

    // AC-8 (US-2 기준 1·2, FR-5): the new row opens its own entry regardless of the clock (07:00)
    @Test func ac8_openNewRowInMorning() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let model = env.model(homepage: try Self.standardHomepage(), youtube: try Self.youtube())
        await model.load()

        let screen = try #require(model.makeScreenModel(for: .newTestament))
        #expect(screen.testament == .newTestament)
        #expect(screen.entry.date == Self.date(2020, 7, 13))
        #expect(screen.entry.articleNo == 11480)
        #expect(screen.mode == .next)
        await screen.load()

        let c = try #require(Self.screenContent(screen.state))
        #expect(c.testament == .newTestament)
        let expected = try Self.article("cast-body-11480")
        #expect(c.article == expected)
    }

    // AC-8: the old row opens its own entry in the afternoon (13:00)
    @Test func ac8_openOldRowInAfternoon() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        let model = env.model(homepage: try Self.standardHomepage(), youtube: try Self.youtube())
        await model.load()

        let screen = try #require(model.makeScreenModel(for: .oldTestament))
        #expect(screen.testament == .oldTestament)
        #expect(screen.entry.date == Self.date(2025, 9, 11))
        #expect(screen.mode == .next)
        await screen.load()

        let c = try #require(Self.screenContent(screen.state))
        #expect(c.testament == .oldTestament)
        let expected = try Self.article("cast-body-15155")
        #expect(c.article == expected)
    }

    // MARK: - AC-9 finish → back to main

    // AC-9 (US-2 기준 3·4, US-3 기준 1·2, FR-7·9): finish new in the morning, main shows "읽음" without fetching
    @Test func ac9_finishThenReturnShowsRead() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.standardHomepage()
        let model = env.model(homepage: homepage, youtube: try Self.youtube())
        await model.load()
        let screen = try #require(model.makeScreenModel(for: .newTestament))
        await screen.load()

        screen.markSeen()

        // first slot = old default written by ReadingProgressStore.markSeen's internal load()
        #expect(env.rawSnapshot() == ["2025/09/10", "2020/07/13", nil, "2026/11/20"])
        #expect(env.store.storedProgress().lastSeenOld == Self.date(2025, 9, 10))
        #expect(env.store.finishedDay(for: .oldTestament) == nil)
        #expect(screen.isFinished == true)

        try env.setTime(2026, 11, 20, 8)
        let before = await homepage.requested.count
        await model.refreshOnReturn()

        let new = try #require(Self.content(model.newRow))
        #expect(new.title == Self.newTitle0713)
        #expect(new.isRead == true)
        let old = try #require(Self.content(model.oldRow))
        #expect(old.title == Self.oldTitle0911)
        #expect(old.isRead == false)
        #expect(await homepage.requested.count == before)
    }

    // MARK: - AC-10 / AC-11 read row

    // AC-10 (FR-2 읽음 분기): old finished today → read row on lastSeen, one search, no next-day search
    @Test func ac10_readRowSearchesLastSeenOnly() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        env.seedOldReadOn20261120()
        let homepage = try Self.standardHomepage()
        let model = env.model(homepage: homepage, youtube: try Self.youtube())

        await model.load()

        let old = try #require(Self.content(model.oldRow))
        #expect(old.title == Self.oldTitle0911)
        #expect(old.isRead == true)
        let requested = await homepage.requested
        #expect(Self.count(requested, "search=2025/09/11") == 1)
        #expect(Self.count(requested, "search=2025/09/12") == 0)
        #expect(Self.describeSorted(requested) == ["search=2020/07/12", "search=2020/07/13", "search=2025/09/11"])
        #expect(env.rawSnapshot() == ["2025/09/11", nil, "2026/11/20", nil])
    }

    // AC-11 (US-3 기준 3, FR-7): date changes while on main → reload shows the next devotion unread
    @Test func ac11_dayChangeReloadsNextDevotion() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        env.seedOldReadOn20261120()
        let homepage = try Self.standardHomepage()
        let model = env.model(homepage: homepage, youtube: try Self.youtube())
        await model.load()
        #expect(Self.count(await homepage.requested, "search=2025/09/12") == 0)

        try env.setTime(2026, 11, 21, 0, 0)
        await model.refreshOnReturn()

        let old = try #require(Self.content(model.oldRow))
        #expect(old.title == Self.oldTitle0912)
        #expect(old.entry.articleNo == 15157)
        #expect(old.isRead == false)
        #expect(Self.count(await homepage.requested, "search=2025/09/12") == 1)

        // a fresh model on the same store at 07:00 the next day decides the same old row
        try env.setTime(2026, 11, 21, 7)
        let fresh = env.model(homepage: try Self.standardHomepage(), youtube: try Self.youtube())
        await fresh.load()
        #expect(fresh.oldRow == model.oldRow)
    }

    // MARK: - AC-12 garbage stored value

    // AC-12: garbage lastSeenOld → default 2025/09/10 is used for the search, raw value not rewritten
    @Test func ac12_garbageLastSeenUsesDefaultAndKeepsRaw() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        env.defaults.set("garbage", forKey: "readingProgress.lastSeenOld")
        let homepage = try Self.standardHomepage()
        let model = env.model(homepage: homepage, youtube: try Self.youtube())

        await model.load()

        #expect(Self.count(await homepage.requested, "search=2025/09/11") == 1)
        let old = try #require(Self.content(model.oldRow))
        #expect(old.entry.date == Self.date(2025, 9, 11))
        #expect(env.defaults.string(forKey: "readingProgress.lastSeenOld") == "garbage")
        #expect(env.rawSnapshot() == ["garbage", nil, nil, nil])
    }

    // MARK: - AC-14 review mode

    // AC-14 (US-4, FR-6·10): read row opens in review mode; no button, markSeen writes nothing
    @Test func ac14_readRowOpensReview() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        env.seedOldReadOn20261120()
        let model = env.model(homepage: try Self.standardHomepage(), youtube: try Self.youtube())
        await model.load()

        let screen = try #require(model.makeScreenModel(for: .oldTestament))
        #expect(screen.mode == .review)
        #expect(screen.showsFinishButton == false)
        await screen.load()
        let c = try #require(Self.screenContent(screen.state))
        #expect(c.entry.date == Self.date(2025, 9, 11))
        let expected = try Self.article("cast-body-15155")
        #expect(c.article == expected)

        let snapshot = env.rawSnapshot()
        screen.markSeen()

        #expect(env.rawSnapshot() == snapshot)
        #expect(snapshot == ["2025/09/11", nil, "2026/11/20", nil])
        #expect(screen.isFinished == false)
        #expect(screen.showsFinishButton == false)
    }

    // AC-14 boundary: the unread row (new) on the same main stays in .next mode
    @Test func ac14_unreadRowStaysNext() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        env.seedOldReadOn20261120()
        let model = env.model(homepage: try Self.standardHomepage(), youtube: try Self.youtube())
        await model.load()

        let screen = try #require(model.makeScreenModel(for: .newTestament))
        #expect(screen.mode == .next)
        #expect(screen.showsFinishButton == true)
    }

    // MARK: - AC-21 / AC-22 / AC-23 / AC-25 row failures

    // AC-21 (US-5 기준 1·2, FR-8): one row's network error does not affect the other; retry reloads only that row
    @Test func ac21_networkErrorIsPerRowAndRetry() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.standardHomepage()
        await homepage.setSearch("2020/07/12", .failure(URLError(.notConnectedToInternet)))
        let model = env.model(homepage: homepage, youtube: try Self.youtube())

        await model.load()

        #expect(model.newRow == .networkError)
        #expect(model.newRow.message == "인터넷 연결을 확인해 주세요")
        let old = try #require(Self.content(model.oldRow))
        #expect(old.entry.date == Self.date(2025, 9, 11))
        let newScreenIsNil = model.makeScreenModel(for: .newTestament) == nil
        let oldScreenIsNil = model.makeScreenModel(for: .oldTestament) == nil
        #expect(newScreenIsNil)
        #expect(!oldScreenIsNil)

        await homepage.setSearch("2020/07/12", .html(try Self.emptyPage()))
        await model.retry(.newTestament)

        let new = try #require(Self.content(model.newRow))
        #expect(new.title == Self.newTitle0713)
        #expect(Self.content(model.oldRow) == old)
        #expect(Self.count(await homepage.requested, "search=2025/09/11") == 1)
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
    }

    // AC-22 (US-5 기준 3·4): seven empty days for old → noNextDevotion, new still ready
    @Test func ac22_noNextDevotionRow() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.standardHomepage()
        await homepage.setSearch("2025/09/11", .html(try Self.emptyPage()))
        await homepage.setSearch("2025/09/12", .html(try Self.emptyPage()))
        let model = env.model(homepage: homepage, youtube: try Self.youtube())

        await model.load()

        #expect(model.oldRow == .noNextDevotion)
        #expect(model.oldRow.message == "다음 묵상을 찾지 못했습니다")
        let oldSearches = Self.describeSorted(await homepage.requested).filter { $0.hasPrefix("search=2025/") }
        #expect(oldSearches == [
            "search=2025/09/11", "search=2025/09/12", "search=2025/09/13", "search=2025/09/14",
            "search=2025/09/15", "search=2025/09/16", "search=2025/09/17",
        ])
        let new = try #require(Self.content(model.newRow))
        #expect(new.title == Self.newTitle0713)
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
        let oldScreenIsNil = model.makeScreenModel(for: .oldTestament) == nil
        #expect(oldScreenIsNil)
    }

    // AC-23 (FR-7 같은 날): same-day return leaves an error row alone and fetches nothing
    @Test func ac23_sameDayReturnKeepsErrorRow() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.standardHomepage()
        await homepage.setSearch("2020/07/12", .failure(URLError(.notConnectedToInternet)))
        let model = env.model(homepage: homepage, youtube: try Self.youtube())
        await model.load()
        #expect(model.newRow == .networkError)
        let oldBefore = model.oldRow
        let count = await homepage.requested.count

        try env.setTime(2026, 11, 20, 9)
        await model.refreshOnReturn()

        #expect(model.newRow == .networkError)
        #expect(model.oldRow == oldBefore)
        #expect(await homepage.requested.count == count)
    }

    // AC-23: refreshOnReturn before load does nothing
    @Test func ac23_returnBeforeLoadIsNoOp() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.standardHomepage()
        let model = env.model(homepage: homepage, youtube: try Self.youtube())

        await model.refreshOnReturn()

        #expect(await homepage.requested.count == 0)
        #expect(model.oldRow == .loading)
        #expect(model.newRow == .loading)
    }

    // AC-25 ([결정] 1 기본값): read row whose lastSeen date is missing from the list → networkError; retry searches again
    @Test func ac25_readRowMissingEntryIsNetworkError() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        env.seedOldReadOn20261120()
        let homepage = try Self.standardHomepage()
        await homepage.setSearch("2025/09/11", .html(try Self.emptyPage()))
        let model = env.model(homepage: homepage, youtube: try Self.youtube())

        await model.load()

        #expect(model.oldRow == .networkError)
        #expect(Self.count(await homepage.requested, "search=2025/09/11") == 1)
        #expect(Self.count(await homepage.requested, "search=2025/09/12") == 0)

        await model.retry(.oldTestament)

        #expect(Self.count(await homepage.requested, "search=2025/09/11") == 2)
        #expect(model.oldRow == .networkError)
    }

    // MARK: - AC-27 title match

    // AC-27 ①②: main row title == opened screen headerTitle, old and new
    @Test func ac27_titleMatchesScreenHeader() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let model = env.model(homepage: try Self.standardHomepage(), youtube: try Self.youtube())
        await model.load()

        let oldRow = try #require(Self.content(model.oldRow))
        let oldScreen = try #require(model.makeScreenModel(for: .oldTestament))
        await oldScreen.load()
        let oldHeader = try #require(Self.screenContent(oldScreen.state))
        #expect(oldRow.title == Self.oldTitle0911)
        #expect(oldHeader.headerTitle == oldRow.title)

        let newRow = try #require(Self.content(model.newRow))
        let newScreen = try #require(model.makeScreenModel(for: .newTestament))
        await newScreen.load()
        let newHeader = try #require(Self.screenContent(newScreen.state))
        #expect(newRow.title == Self.newTitle0713)
        #expect(newHeader.headerTitle == newRow.title)
    }

    // AC-27 ③ (판정 #28): stand-in article (15157 → body-15155) — header follows the entry, not the article
    @Test func ac27_headerFollowsEntryNotArticle() async throws {
        let env = try Env(2026, 11, 21, 7)
        defer { env.cleanup() }
        env.seedOldReadOn20261120()
        let model = env.model(homepage: try Self.standardHomepage(), youtube: try Self.youtube())
        await model.load()

        let row = try #require(Self.content(model.oldRow))
        #expect(row.title == Self.oldTitle0912)
        let screen = try #require(model.makeScreenModel(for: .oldTestament))
        await screen.load()
        let c = try #require(Self.screenContent(screen.state))

        #expect(c.headerTitle == row.title)
        #expect(c.headerTitle == Self.oldTitle0912)
        #expect(c.headerDate == "2025/09/12(금)")
        #expect(c.headerPassage == "잠언 24:1-10")
        #expect(c.article.passageText == "잠언 23:24-35")
    }
}
