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

    func model(homepage: any DevotionHTMLFetching, youtube: FakeYouTube, apiKey: String? = "k") -> MainScreenModel {
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

    /// 기본 홈페이지 (DESIGN §7): searches 2025/09/11, 2020/07/12 (0건), 2020/07/13, 2025/09/12, 2020/07/14;
    /// articles 15155, 11480, 15157 (→ body-15155 stand-in), 11481 (→ body-11480 stand-in).
    private static func standardHomepage() throws -> FakeHomepage {
        FakeHomepage(
            search: [
                "2025/09/11": .html(try html("cast-search-proverbs-23")),
                "2020/07/12": .html(try emptyPage()),
                "2020/07/13": .html(try html("cast-search-john-5")),
                "2025/09/12": .html(try html("cast-search-date-20250912")),
                "2020/07/14": .html(try html("cast-search-date-20200714")),
            ],
            article: [
                15155: .html(try html("cast-body-15155")),
                11480: .html(try html("cast-body-11480")),
                15157: .html(try html("cast-body-15155")),
                11481: .html(try html("cast-body-11480")),
                15160: .html(try html("cast-body-15155")),
            ],
            defaultSearch: try emptyPage())
    }

    /// Synthetic page0915 (DESIGN §7-1): date-20250912 with 2025/09/12(금) → 2025/09/15(월), no=15157 → no=15160.
    private static func page0915() throws -> String {
        let page = try html("cast-search-date-20250912")
            .replacingOccurrences(of: "2025/09/12(금)", with: "2025/09/15(월)")
            .replacingOccurrences(of: "no=15157", with: "no=15160")
        let entries = DevotionListParser.parseEntries(fromHTML: page)
        try #require(entries.count == 1)
        try #require(entries.first?.date == date(2025, 9, 15))
        try #require(entries.first?.weekday == "월")
        try #require(entries.first?.articleNo == 15160)
        return page
    }

    private static func query(_ url: URL, _ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == name })?.value
    }

    /// "search=<date>" / "no=<n>" in request order.
    private static func describe(_ urls: [URL]) -> [String] {
        urls.map { url in
            if let no = query(url, "no") { return "no=\(no)" }
            return "search=\(query(url, "search") ?? "?")"
        }
    }

    /// "search=<date>" / "no=<n>", sorted (two rows load concurrently, so order is not asserted).
    private static func describeSorted(_ urls: [URL]) -> [String] {
        describe(urls).sorted()
    }

    private static func count(_ urls: [URL], _ item: String) -> Int {
        describeSorted(urls).filter { $0 == item }.count
    }

    /// Requests made after the first `from` requests, in order.
    private static func since(_ homepage: FakeHomepage, _ from: Int) async -> [String] {
        Array(describe(await homepage.requested).dropFirst(from))
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
    private static let newTitle0714 = "2020/07/14(화) 요한복음 6:1-21"
    private static let oldTitle0915 = "2025/09/15(월) 잠언 24:1-10"

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
        #expect(screen.isRead == false)
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
        #expect(screen.isRead == false)
        await screen.load()

        let c = try #require(Self.screenContent(screen.state))
        #expect(c.testament == .oldTestament)
        let expected = try Self.article("cast-body-15155")
        #expect(c.article == expected)
    }

    // MARK: - AC-9 finish → back to main (rewritten for F-4, same expectation as AC-54)

    // AC-9 → AC-54: finish new in the morning; main shows the next new entry (07/14) unread, one more request
    @Test func ac9_finishThenReturnShowsNextEntry() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.standardHomepage()
        let model = env.model(homepage: homepage, youtube: try Self.youtube())
        await model.load()
        let screen = try #require(model.makeScreenModel(for: .newTestament))
        await screen.load()

        screen.markSeen()

        // first slot = old default written by ReadingProgressStore.markSeen's internal load()
        #expect(env.rawSnapshot() == ["2025/09/10", "2020/07/13", nil, nil])
        #expect(env.store.storedProgress().lastSeenOld == Self.date(2025, 9, 10))
        #expect(screen.isFinished == true)

        try env.setTime(2026, 11, 20, 8)
        let before = await homepage.requested.count
        await model.refreshOnReturn()

        let new = try #require(Self.content(model.newRow))
        #expect(new.title == Self.newTitle0714)
        #expect(new.entry.articleNo == 11481)
        #expect(new.isRead == false)
        let old = try #require(Self.content(model.oldRow))
        #expect(old.title == Self.oldTitle0911)
        #expect(old.isRead == false)
        #expect(await Self.since(homepage, before) == ["search=2020/07/14"])
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

    // MARK: - AC-14 unread row (review mode removed in F-4)

    // AC-14 boundary: the unread row (new) shows the finish button even with a legacy finished-day key present
    @Test func ac14_unreadRowStaysNext() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        env.seedOldReadOn20261120()
        let model = env.model(homepage: try Self.standardHomepage(), youtube: try Self.youtube())
        await model.load()

        let screen = try #require(model.makeScreenModel(for: .newTestament))
        #expect(screen.isRead == false)
        #expect(screen.showsFinishButton == true)
    }

    // MARK: - AC-21 / AC-22 / AC-23 row failures

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

    // MARK: - F-4 helpers

    /// Opens `testament`'s row, loads it, presses "다 봤어요", returns to main. Returns the screen model.
    @discardableResult
    private static func finishRow(_ model: MainScreenModel, _ testament: Testament) async throws -> DevotionScreenModel {
        let screen = try #require(model.makeScreenModel(for: testament))
        await screen.load()
        #expect(screen.showsFinishButton == true)
        screen.markSeen()
        #expect(screen.isFinished == true)
        await model.refreshOnReturn()
        return screen
    }

    /// AC-56 setup: lastSeenOld 2025/09/12, 2025/09/15 → page0915, loaded at 2026-11-22 07:00.
    private static func movedSetup() async throws -> (Env, FakeHomepage, MainScreenModel) {
        let env = try Env(2026, 11, 22, 7)
        env.defaults.set("2025/09/12", forKey: "readingProgress.lastSeenOld")
        let homepage = try standardHomepage()
        await homepage.setSearch("2025/09/15", .html(try page0915()))
        let model = env.model(homepage: homepage, youtube: try youtube())
        await model.load()
        return (env, homepage, model)
    }

    // MARK: - AC-52 / AC-53 / AC-54 finish → next entry (US-1)

    // AC-52 (US-1 기준 1·3): finish old 09/11 → old row becomes 09/12 unread; new row untouched, no new-testament search
    @Test func ac52_finishOldShowsNextOldEntry() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let homepage = try Self.standardHomepage()
        let model = env.model(homepage: homepage, youtube: try Self.youtube())
        await model.load()
        let newBefore = model.newRow
        let old0 = try #require(Self.content(model.oldRow))
        #expect(old0.title == Self.oldTitle0911)
        let before = await homepage.requested.count

        try await Self.finishRow(model, .oldTestament)

        let old = try #require(Self.content(model.oldRow))
        #expect(old.title == Self.oldTitle0912)
        #expect(old.entry.articleNo == 15157)
        #expect(old.isRead == false)
        #expect(model.newRow == newBefore)
        let after = await Self.since(homepage, before)
        #expect(after.filter { $0.hasPrefix("search=2020/") }.isEmpty)
        #expect(after == ["no=15155", "search=2025/09/12"])
        #expect(env.rawSnapshot() == ["2025/09/11", "2020/07/11", nil, nil])
    }

    // AC-53 (US-1 기준 2): finish 09/11, then finish 09/12 → lastSeenOld 09/12, next search starts at 09/13
    @Test func ac53_finishTwiceAdvancesAgain() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let homepage = try Self.standardHomepage()
        let model = env.model(homepage: homepage, youtube: try Self.youtube())
        await model.load()
        try await Self.finishRow(model, .oldTestament)
        #expect(Self.content(model.oldRow)?.title == Self.oldTitle0912)

        let before = await homepage.requested.count
        let screen = try #require(model.makeScreenModel(for: .oldTestament))
        #expect(screen.entry.articleNo == 15157)
        await screen.load()
        screen.markSeen()
        await model.refreshOnReturn()

        #expect(env.store.storedProgress().lastSeenOld == Self.date(2025, 9, 12))
        let after = await Self.since(homepage, before)
        #expect(after.first == "no=15157")
        #expect(after.first(where: { $0.hasPrefix("search=2025/") }) == "search=2025/09/13")
        #expect(after.filter { $0.hasPrefix("search=2025/") } == [
            "search=2025/09/13", "search=2025/09/14", "search=2025/09/15", "search=2025/09/16",
            "search=2025/09/17", "search=2025/09/18", "search=2025/09/19",
        ])
        #expect(model.oldRow == .noNextDevotion)

        // With page0915 available, retrying the row lands on 09/15 unread.
        await homepage.setSearch("2025/09/15", .html(try Self.page0915()))
        await model.retry(.oldTestament)
        let old = try #require(Self.content(model.oldRow))
        #expect(old.title == Self.oldTitle0915)
        #expect(old.entry.articleNo == 15160)
        #expect(old.isRead == false)
    }

    // AC-53: page0915 present before the second return → the return itself lands on 09/15
    @Test func ac53_secondFinishLandsOnPage0915() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let homepage = try Self.standardHomepage()
        await homepage.setSearch("2025/09/15", .html(try Self.page0915()))
        let model = env.model(homepage: homepage, youtube: try Self.youtube())
        await model.load()
        try await Self.finishRow(model, .oldTestament)
        try await Self.finishRow(model, .oldTestament)

        let old = try #require(Self.content(model.oldRow))
        #expect(old.entry.date == Self.date(2025, 9, 15))
        #expect(old.entry.articleNo == 15160)
        #expect(old.isRead == false)
        #expect(env.rawSnapshot() == ["2025/09/12", "2020/07/11", nil, nil])
    }

    // AC-54 (US-1 기준 4): afternoon, finish new 07/13 → new row 07/14 #11481 unread, old row untouched
    @Test func ac54_finishNewShowsNextNewEntry() async throws {
        let env = try Env(2026, 11, 22, 13)
        defer { env.cleanup() }
        let homepage = try Self.standardHomepage()
        let model = env.model(homepage: homepage, youtube: try Self.youtube())
        await model.load()
        let oldBefore = model.oldRow
        #expect(Self.content(model.newRow)?.title == Self.newTitle0713)

        try await Self.finishRow(model, .newTestament)

        let new = try #require(Self.content(model.newRow))
        #expect(new.title == Self.newTitle0714)
        #expect(new.entry.articleNo == 11481)
        #expect(new.isRead == false)
        #expect(model.oldRow == oldBefore)
        #expect(env.rawSnapshot() == ["2025/09/10", "2020/07/13", nil, nil])
    }

    // MARK: - AC-55 legacy finished-day key ignored (FR-1)

    // AC-55 (US-1 기준 5): lastSeenOld 09/11 + finishedDayOld today → next entry 09/12 unread, 09/11 never searched
    @Test func ac55_legacyFinishedDayIgnored() async throws {
        let env = try Env(2026, 11, 22, 13)
        defer { env.cleanup() }
        env.defaults.set("2025/09/11", forKey: "readingProgress.lastSeenOld")
        env.defaults.set("2026/11/22", forKey: "readingProgress.finishedDayOld")
        let homepage = try Self.standardHomepage()
        let model = env.model(homepage: homepage, youtube: try Self.youtube())

        await model.load()

        let old = try #require(Self.content(model.oldRow))
        #expect(old.title == Self.oldTitle0912)
        #expect(old.entry.articleNo == 15157)
        #expect(old.isRead == false)
        let requested = await homepage.requested
        #expect(Self.count(requested, "search=2025/09/11") == 0)
        #expect(Self.count(requested, "search=2025/09/12") == 1)
        #expect(env.rawSnapshot() == ["2025/09/11", nil, "2026/11/22", nil])

        // Same-day return keeps it (basis == stored) and still ignores the legacy key.
        let before = requested.count
        await model.refreshOnReturn()
        #expect(Self.content(model.oldRow)?.isRead == false)
        #expect(await homepage.requested.count == before)
    }

    // MARK: - AC-56 … AC-61 main row move (US-4, FR-7·9·10)

    // AC-56 (US-4 기준 1·2·4·5): row 09/15 → "이전" → 09/12 read; only old searches, store untouched
    @Test func ac56_movePreviousOnRow() async throws {
        let (env, homepage, model) = try await Self.movedSetup()
        defer { env.cleanup() }

        let first = try #require(Self.content(model.oldRow))
        #expect(first.title == Self.oldTitle0915)
        #expect(first.entry.articleNo == 15160)
        #expect(first.isRead == false)
        let newBefore = model.newRow
        let snapshot = env.rawSnapshot()
        #expect(snapshot == ["2025/09/12", nil, nil, nil])
        #expect(model.isMoving(.oldTestament) == false)
        #expect(model.notice(for: .oldTestament) == nil)
        let before = await homepage.requested.count

        await model.move(.oldTestament, .previous)

        let old = try #require(Self.content(model.oldRow))
        #expect(old.testament == .oldTestament)
        #expect(old.title == Self.oldTitle0912)
        #expect(old.entry.articleNo == 15157)
        #expect(old.isRead == true)
        #expect(await Self.since(homepage, before) == ["search=2025/09/14", "search=2025/09/13", "search=2025/09/12"])
        #expect(model.newRow == newBefore)
        #expect(env.rawSnapshot() == snapshot)
        #expect(model.isMoving(.oldTestament) == false)
        #expect(model.isMoving(.newTestament) == false)
        #expect(model.notice(for: .oldTestament) == nil)
        #expect(model.notice(for: .newTestament) == nil)
    }

    // AC-57 (US-4 기준 3, US-3 기준 1·3): moved-to read row opens without the finish button; markSeen writes nothing
    @Test func ac57_movedReadRowOpensWithoutFinish() async throws {
        let (env, _, model) = try await Self.movedSetup()
        defer { env.cleanup() }
        await model.move(.oldTestament, .previous)

        let screen = try #require(model.makeScreenModel(for: .oldTestament))
        #expect(screen.entry.date == Self.date(2025, 9, 12))
        #expect(screen.entry.articleNo == 15157)
        #expect(screen.isRead == true)
        #expect(screen.showsFinishButton == false)
        await screen.load()
        let c = try #require(Self.screenContent(screen.state))
        #expect(c.entry.date == Self.date(2025, 9, 12))

        let snapshot = env.rawSnapshot()
        screen.markSeen()
        #expect(env.rawSnapshot() == snapshot)
        #expect(screen.isFinished == false)
        #expect(screen.showsFinishButton == false)
    }

    // AC-58 (US-3 기준 4, US-4): back to 09/15 with "다음" → unread, finish button shown
    @Test func ac58_moveNextBackToUnread() async throws {
        let (env, homepage, model) = try await Self.movedSetup()
        defer { env.cleanup() }
        await model.move(.oldTestament, .previous)
        let before = await homepage.requested.count

        await model.move(.oldTestament, .next)

        let old = try #require(Self.content(model.oldRow))
        #expect(old.entry.date == Self.date(2025, 9, 15))
        #expect(old.entry.articleNo == 15160)
        #expect(old.isRead == false)
        #expect(await Self.since(homepage, before) == ["search=2025/09/13", "search=2025/09/14", "search=2025/09/15"])
        let screen = try #require(model.makeScreenModel(for: .oldTestament))
        #expect(screen.isRead == false)
        #expect(screen.showsFinishButton == true)
        #expect(env.rawSnapshot() == ["2025/09/12", nil, nil, nil])
    }

    // AC-59 (US-5, FR-10 main): failed moves keep the row and set that row's notice; success clears it
    @Test func ac59_failedMoveKeepsRowWithNotice() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let homepage = try Self.standardHomepage()
        await homepage.setSearch("2025/09/12", .html(try Self.emptyPage()))
        let model = env.model(homepage: homepage, youtube: try Self.youtube())
        await model.load()
        let row0911 = model.oldRow
        #expect(Self.content(row0911)?.title == Self.oldTitle0911)
        let newBefore = model.newRow

        // 다음: 09/12 … 09/18 all empty
        var before = await homepage.requested.count
        await model.move(.oldTestament, .next)
        #expect(model.oldRow == row0911)
        #expect(model.notice(for: .oldTestament) == "다음 묵상을 찾지 못했습니다")
        #expect(model.notice(for: .newTestament) == nil)
        #expect(await Self.since(homepage, before) == [
            "search=2025/09/12", "search=2025/09/13", "search=2025/09/14", "search=2025/09/15",
            "search=2025/09/16", "search=2025/09/17", "search=2025/09/18",
        ])
        #expect(model.isMoving(.oldTestament) == false)

        // 이전: 09/10 … 09/04 all empty
        before = await homepage.requested.count
        await model.move(.oldTestament, .previous)
        #expect(model.oldRow == row0911)
        #expect(model.notice(for: .oldTestament) == "이전 묵상을 찾지 못했습니다")
        #expect(await Self.since(homepage, before) == [
            "search=2025/09/10", "search=2025/09/09", "search=2025/09/08", "search=2025/09/07",
            "search=2025/09/06", "search=2025/09/05", "search=2025/09/04",
        ])
        #expect(model.isMoving(.oldTestament) == false)

        // network error on 09/12
        await homepage.setSearch("2025/09/12", .failure(URLError(.notConnectedToInternet)))
        before = await homepage.requested.count
        await model.move(.oldTestament, .next)
        #expect(model.oldRow == row0911)
        #expect(model.notice(for: .oldTestament) == "인터넷 연결을 확인해 주세요")
        #expect(await Self.since(homepage, before) == ["search=2025/09/12"])
        #expect(model.isMoving(.oldTestament) == false)
        #expect(model.newRow == newBefore)
        #expect(model.notice(for: .newTestament) == nil)
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])

        // a successful move clears the notice
        await homepage.setSearch("2025/09/12", .html(try Self.html("cast-search-date-20250912")))
        await model.move(.oldTestament, .next)
        #expect(Self.content(model.oldRow)?.title == Self.oldTitle0912)
        #expect(Self.content(model.oldRow)?.isRead == false)
        #expect(model.notice(for: .oldTestament) == nil)
        #expect(model.isMoving(.oldTestament) == false)
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
    }

    // AC-59 boundary: load() / retry clear a row's notice
    @Test func ac59_loadAndRetryClearNotice() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let homepage = try Self.standardHomepage()
        let model = env.model(homepage: homepage, youtube: try Self.youtube())
        await model.load()

        await model.move(.oldTestament, .previous)   // 09/10 … 09/04 empty
        #expect(model.notice(for: .oldTestament) == "이전 묵상을 찾지 못했습니다")
        await model.retry(.oldTestament)
        #expect(model.notice(for: .oldTestament) == nil)

        await model.move(.newTestament, .previous)   // 07/12 … 07/06 empty
        #expect(model.notice(for: .newTestament) == "이전 묵상을 찾지 못했습니다")
        #expect(model.notice(for: .oldTestament) == nil)
        await model.load()
        #expect(model.notice(for: .newTestament) == nil)

        await model.move(.newTestament, .previous)
        #expect(model.notice(for: .newTestament) == "이전 묵상을 찾지 못했습니다")
        await model.refreshOnReturn()
        #expect(model.notice(for: .newTestament) == nil)
    }

    // AC-60 ([결정] 1): a moved row survives same-day and next-day returns; a fresh model starts from progress again
    @Test func ac60_movedRowSurvivesReturn() async throws {
        let (env, homepage, model) = try await Self.movedSetup()
        defer { env.cleanup() }
        await model.move(.oldTestament, .previous)
        let moved = model.oldRow
        #expect(Self.content(moved)?.entry.date == Self.date(2025, 9, 12))
        let newBefore = model.newRow

        var before = await homepage.requested.count
        await model.refreshOnReturn()
        #expect(model.oldRow == moved)
        #expect(model.newRow == newBefore)
        #expect(await homepage.requested.count == before)

        try env.setTime(2026, 11, 23, 7)
        before = await homepage.requested.count
        await model.refreshOnReturn()
        #expect(model.oldRow == moved)
        #expect(model.newRow == newBefore)
        #expect(await homepage.requested.count == before)

        let fresh = env.model(homepage: homepage, youtube: try Self.youtube())
        await fresh.load()
        let old = try #require(Self.content(fresh.oldRow))
        #expect(old.entry.date == Self.date(2025, 9, 15))
        #expect(old.isRead == false)
    }

    // AC-60 boundary: moved row, then progress changes (finish the moved-to unread 09/15) → that row reloads from progress
    @Test func ac60_progressChangeResetsMovedRow() async throws {
        let (env, homepage, model) = try await Self.movedSetup()
        defer { env.cleanup() }
        await model.move(.oldTestament, .previous)   // 09/12 (read)
        await model.move(.oldTestament, .next)       // 09/15 (unread)
        let newBefore = model.newRow

        let before = await homepage.requested.count
        try await Self.finishRow(model, .oldTestament)

        #expect(env.store.storedProgress().lastSeenOld == Self.date(2025, 9, 15))
        let after = await Self.since(homepage, before)
        #expect(after.first == "no=15160")
        #expect(after.dropFirst().first == "search=2025/09/16")
        #expect(model.oldRow == .noNextDevotion)
        #expect(model.newRow == newBefore)
    }

    // AC-61: move does nothing on a row that is not .ready
    @Test func ac61_moveIgnoredWhenNotReady() async throws {
        // .loading (before load)
        do {
            let env = try Env(2026, 11, 22, 7)
            defer { env.cleanup() }
            let homepage = try Self.standardHomepage()
            let model = env.model(homepage: homepage, youtube: try Self.youtube())
            await model.move(.oldTestament, .next)
            await model.move(.newTestament, .previous)
            #expect(await homepage.requested.count == 0)
            #expect(model.oldRow == .loading)
            #expect(model.newRow == .loading)
            #expect(model.notice(for: .oldTestament) == nil)
            #expect(model.notice(for: .newTestament) == nil)
            #expect(model.isMoving(.oldTestament) == false)
        }
        // .networkError (new row, 2020/07/12 fails)
        do {
            let env = try Env(2026, 11, 22, 7)
            defer { env.cleanup() }
            let homepage = try Self.standardHomepage()
            await homepage.setSearch("2020/07/12", .failure(URLError(.notConnectedToInternet)))
            let model = env.model(homepage: homepage, youtube: try Self.youtube())
            await model.load()
            #expect(model.newRow == .networkError)
            let count = await homepage.requested.count
            await model.move(.newTestament, .previous)
            await model.move(.newTestament, .next)
            #expect(await homepage.requested.count == count)
            #expect(model.newRow == .networkError)
            #expect(model.notice(for: .newTestament) == nil)
            #expect(model.isMoving(.newTestament) == false)
        }
        // .noNextDevotion (old row, 09/11 and 09/12 empty)
        do {
            let env = try Env(2026, 11, 22, 7)
            defer { env.cleanup() }
            let homepage = try Self.standardHomepage()
            await homepage.setSearch("2025/09/11", .html(try Self.emptyPage()))
            await homepage.setSearch("2025/09/12", .html(try Self.emptyPage()))
            let model = env.model(homepage: homepage, youtube: try Self.youtube())
            await model.load()
            #expect(model.oldRow == .noNextDevotion)
            let count = await homepage.requested.count
            await model.move(.oldTestament, .previous)
            await model.move(.oldTestament, .next)
            #expect(await homepage.requested.count == count)
            #expect(model.oldRow == .noNextDevotion)
            #expect(model.notice(for: .oldTestament) == nil)
            #expect(env.rawSnapshot() == [nil, nil, nil, nil])
        }
    }

    // AC-56 / FR-9 boundary: moving one row never changes the other row's state or notice
    @Test func ac56_moveIsPerRow() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let homepage = try Self.standardHomepage()
        let model = env.model(homepage: homepage, youtube: try Self.youtube())
        await model.load()
        let oldBefore = model.oldRow

        await model.move(.newTestament, .next)   // 07/13 → 07/14

        let new = try #require(Self.content(model.newRow))
        #expect(new.testament == .newTestament)
        #expect(new.title == Self.newTitle0714)
        #expect(new.isRead == false)
        #expect(model.oldRow == oldBefore)
        #expect(model.notice(for: .oldTestament) == nil)
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
    }

    // AC-56 / [결정] 4: while a row's move search runs, isMoving is true for that row only and a second move is ignored
    @Test func ac56_moveInFlightBlocksSecondMove() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let gate = GatedHomepage(inner: try Self.standardHomepage())
        let model = env.model(homepage: gate, youtube: try Self.youtube())
        await model.load()
        #expect(Self.content(model.oldRow)?.entry.date == Self.date(2025, 9, 11))
        await gate.close()

        let task = Task { await model.move(.oldTestament, .next) }
        var waiting = 0
        for _ in 0..<10_000 {
            waiting = await gate.waitingCount
            if waiting > 0 { break }
            await Task.yield()
        }
        try #require(waiting == 1)
        #expect(model.isMoving(.oldTestament) == true)
        #expect(model.isMoving(.newTestament) == false)
        let count = await gate.count

        await model.move(.oldTestament, .previous)
        #expect(await gate.count == count)

        await gate.open()
        await task.value
        #expect(model.isMoving(.oldTestament) == false)
        let old = try #require(Self.content(model.oldRow))
        #expect(old.entry.date == Self.date(2025, 9, 12))
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
    }
}

/// Wraps a fetcher; while closed, search requests suspend until `open()`. Article requests pass through.
private actor GatedHomepage: DevotionHTMLFetching {
    private let inner: any DevotionHTMLFetching
    private var closed = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private(set) var count = 0

    init(inner: any DevotionHTMLFetching) { self.inner = inner }

    var waitingCount: Int { waiting.count }

    func close() { closed = true }

    func open() {
        closed = false
        let pending = waiting
        waiting = []
        pending.forEach { $0.resume() }
    }

    private func park(_ c: CheckedContinuation<Void, Never>) { waiting.append(c) }

    func fetchHTML(from url: URL) async throws -> String {
        count += 1
        let isSearch = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.contains(where: { $0.name == "search" }) ?? false
        if closed && isSearch {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                self.park(c)
            }
        }
        return try await inner.fetchHTML(from: url)
    }
}
