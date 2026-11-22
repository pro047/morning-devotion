//
//  DevotionScreenModelTests.swift
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
    enum Reply: Sendable {
        case data(Data)
        case failure(any Error)
    }

    private let reply: Reply
    private(set) var requested: [URL] = []

    init(_ reply: Reply) { self.reply = reply }

    func fetchSearchResponse(from url: URL) async throws -> Data {
        requested.append(url)
        switch reply {
        case .data(let data): return data
        case .failure(let error): throw error
        }
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
    private(set) var defaults: UserDefaults
    private(set) var store: ReadingProgressStore
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

    func model(
        testament: Testament,
        entry: DevotionEntry,
        mode: DevotionScreenMode = .next,
        homepage: FakeHomepage,
        youtube: FakeYouTube,
        apiKey: String? = "k"
    ) -> DevotionScreenModel {
        let clock = self.clock
        return DevotionScreenModel(
            testament: testament,
            entry: entry,
            mode: mode,
            store: store,
            fetcher: homepage,
            searcher: youtube,
            apiKey: apiKey,
            calendar: calendar,
            now: { clock.now }
        )
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
struct DevotionScreenModelTests {

    // MARK: - Helpers

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> DevotionDate {
        DevotionDate(year: y, month: m, day: d)
    }

    private static func html(_ name: String) throws -> String {
        try FixtureLoader.html(name)
    }

    private static func json(_ name: String) throws -> Data {
        try FixtureLoader.data(name, ext: "json")
    }

    private static func emptyPage() throws -> String {
        try html("cast-search-date-20250914")
    }

    private static func article(_ name: String) throws -> DevotionArticle {
        try #require(DevotionArticleParser.parse(html: try html(name)))
    }

    private static func content(_ state: DevotionScreenState) -> DevotionScreenContent? {
        if case .showing(let c) = state { return c }
        return nil
    }

    private static func query(_ url: URL, _ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == name })?.value
    }

    /// "search=<date>" for search requests, "no=<n>" for article requests.
    private static func describe(_ urls: [URL]) -> [String] {
        urls.map { url in
            if let no = query(url, "no") { return "no=\(no)" }
            return "search=\(query(url, "search") ?? "?")"
        }
    }

    /// First entry on `date` in the parsed list fixture `name`.
    private static func listEntry(_ name: String, _ date: DevotionDate) throws -> DevotionEntry {
        let entries = DevotionListParser.parseEntries(fromHTML: try html(name))
        return try #require(entries.first(where: { $0.date == date }))
    }

    /// Old 2025/09/11 #15155 (from cast-search-proverbs-23).
    private static func oldEntry() throws -> DevotionEntry {
        let e = try listEntry("cast-search-proverbs-23", date(2025, 9, 11))
        #expect(e.articleNo == 15155)
        return e
    }

    /// New 2020/07/13 #11480 (from cast-search-john-5).
    private static func newEntry() throws -> DevotionEntry {
        let e = try listEntry("cast-search-john-5", date(2020, 7, 13))
        #expect(e.articleNo == 11480)
        return e
    }

    /// Article 15155 → body-15155 only. Any `search=` request would hit the 0-entry page.
    private static func oldHomepage() throws -> FakeHomepage {
        FakeHomepage(article: [15155: .html(try html("cast-body-15155"))], defaultSearch: try emptyPage())
    }

    /// Article 11480 → body-11480 only.
    private static func newHomepage() throws -> FakeHomepage {
        FakeHomepage(article: [11480: .html(try html("cast-body-11480"))], defaultSearch: try emptyPage())
    }

    private static func youtube0713() throws -> FakeYouTube {
        FakeYouTube(.data(try json("yt-search-20200713")))
    }

    private static func oldModel(_ env: Env, mode: DevotionScreenMode = .next,
                                 homepage: FakeHomepage, youtube: FakeYouTube, apiKey: String? = "k") throws -> DevotionScreenModel {
        env.model(testament: .oldTestament, entry: try oldEntry(), mode: mode,
                  homepage: homepage, youtube: youtube, apiKey: apiKey)
    }

    private static func newModel(_ env: Env, mode: DevotionScreenMode = .next,
                                 homepage: FakeHomepage, youtube: FakeYouTube, apiKey: String? = "k") throws -> DevotionScreenModel {
        env.model(testament: .newTestament, entry: try newEntry(), mode: mode,
                  homepage: homepage, youtube: youtube, apiKey: apiKey)
    }

    /// Expected old content (2025/09/11, video from the article embed).
    private static func expectOld(_ state: DevotionScreenState, video: VideoSlot = .video(id: "PR9GK_S83NU")) throws {
        let c = try #require(content(state))
        #expect(c.testament == .oldTestament)
        let expectedEntry = try oldEntry()
        #expect(c.entry == expectedEntry)
        #expect(c.entry.date == date(2025, 9, 11))
        #expect(c.entry.weekday == "목")
        #expect(c.entry.passageText == "잠언 23:24-35")
        #expect(c.entry.articleNo == 15155)
        #expect(c.article.hymn == "454장 ‘주와 같이 되기를’")
        #expect(!c.article.sermon.isEmpty)
        let expectedArticle = try article("cast-body-15155")
        #expect(c.article == expectedArticle)
        #expect(c.video == video)
    }

    /// Expected new content (2020/07/13), video slot given.
    private static func expectNew(_ state: DevotionScreenState, video: VideoSlot = .video(id: "M5VtIg1WAic")) throws {
        let c = try #require(content(state))
        #expect(c.testament == .newTestament)
        let expectedEntry = try newEntry()
        #expect(c.entry == expectedEntry)
        #expect(c.entry.date == date(2020, 7, 13))
        #expect(c.entry.weekday == "월")
        #expect(c.entry.passageText == "요한복음 5:30-47")
        #expect(c.entry.articleNo == 11480)
        let expectedArticle = try article("cast-body-11480")
        #expect(c.article == expectedArticle)
        #expect(c.video == video)
    }

    /// "저장값 전부 그대로" on an empty store: all four raw keys absent, API values are defaults / nil.
    private static func expectStoreUntouched(_ env: Env) {
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
        #expect(env.store.storedProgress() == ReadingProgressStore.defaultProgress)
        #expect(env.store.finishedDay(for: .oldTestament) == nil)
        #expect(env.store.finishedDay(for: .newTestament) == nil)
    }

    // MARK: - AC-13 load from the given entry (M4 AC-1 / AC-2 rewritten)

    // AC-13 (결정 1, M4 AC-1): old entry → article only (no list search), embed video, no YouTube
    @Test func ac13_oldEntryLoadsArticleOnly() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.oldHomepage()
        let youtube = try Self.youtube0713()
        let model = try Self.oldModel(env, homepage: homepage, youtube: youtube)

        #expect(model.state == .loading)
        #expect(model.testament == .oldTestament)
        #expect(model.mode == .next)
        await model.load()

        try Self.expectOld(model.state)
        #expect(model.state.message == nil)
        #expect(await youtube.requested.count == 0)
        let requested = await homepage.requested
        #expect(Self.describe(requested) == ["no=15155"])
        #expect(requested.last == DevotionArticleURL.url(articleNo: 15155))
        Self.expectStoreUntouched(env)
    }

    // AC-13 (M4 AC-2): new entry → article 11480 + one YouTube search
    @Test func ac13_newEntryLoadsArticleAndSearchesVideo() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        let homepage = try Self.newHomepage()
        let youtube = try Self.youtube0713()
        let model = try Self.newModel(env, homepage: homepage, youtube: youtube)

        await model.load()

        try Self.expectNew(model.state)
        #expect(Self.describe(await homepage.requested) == ["no=11480"])
        #expect(await youtube.requested.count == 1)
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
    }

    // AC-13 boundary: the testament comes from init, not the clock (old entry opened at 13:00)
    @Test func ac13_testamentIgnoresClock() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        let homepage = try Self.oldHomepage()
        let model = try Self.oldModel(env, homepage: homepage, youtube: try Self.youtube0713())

        await model.load()

        try Self.expectOld(model.state)
        #expect(Self.describe(await homepage.requested) == ["no=15155"])
    }

    // AC-13 (M4 ac2_loadDoesNotWriteStore): load() does not write anything on the success path
    @Test func ac13_loadDoesNotWriteStore() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        let model = try Self.newModel(env, homepage: try Self.newHomepage(), youtube: try Self.youtube0713())
        await model.load()
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
    }

    // MARK: - AC-15 / AC-16 / AC-17 "다 봤어요"

    // AC-15 (FR-9, M4 AC-3): markSeen records progress + finished day, stays .showing, isFinished
    @Test func ac15_markSeenRecordsAndFinishes() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let model = try Self.oldModel(env, homepage: try Self.oldHomepage(), youtube: try Self.youtube0713())
        await model.load()
        try Self.expectOld(model.state)
        let shown = model.state

        model.markSeen()

        // second slot = new default written by ReadingProgressStore.markSeen's internal load()
        #expect(env.rawSnapshot() == ["2025/09/11", "2020/07/11", "2026/11/20", nil])
        #expect(env.store.storedProgress().lastSeenNew == Self.date(2020, 7, 11))
        #expect(env.store.finishedDay(for: .oldTestament) == Self.date(2026, 11, 20))
        #expect(env.store.finishedDay(for: .newTestament) == nil)
        #expect(model.isFinished == true)
        #expect(model.state == shown)
        #expect(model.state.message == nil)
        #expect(model.showsFinishButton == false)
    }

    // AC-16 (M4 AC-3 boundary): opened 11:58 as old, pressed at 12:01 → old is finished, new untouched
    @Test func ac16_markSeenAcrossNoonKeepsShownTestament() async throws {
        let env = try Env(2026, 11, 20, 11, 58)
        defer { env.cleanup() }
        let model = try Self.oldModel(env, homepage: try Self.oldHomepage(), youtube: try Self.youtube0713())
        await model.load()
        try Self.expectOld(model.state)

        try env.setTime(2026, 11, 20, 12, 1)
        model.markSeen()

        #expect(env.defaults.string(forKey: "readingProgress.finishedDayOld") == "2026/11/20")
        #expect(env.defaults.object(forKey: "readingProgress.finishedDayNew") == nil)
        #expect(env.store.storedProgress().lastSeenOld == Self.date(2025, 9, 11))
        #expect(env.store.storedProgress().lastSeenNew == Self.date(2020, 7, 11))
        #expect(model.isFinished == true)
    }

    // AC-16 (M4 AC-3 boundary): finished day is the press moment's local day (after midnight → next day)
    @Test func ac16_markSeenAfterMidnightUsesPressDay() async throws {
        let env = try Env(2026, 11, 20, 23, 50)
        defer { env.cleanup() }
        let model = try Self.newModel(env, homepage: try Self.newHomepage(), youtube: try Self.youtube0713())
        await model.load()
        try Self.expectNew(model.state)

        try env.setTime(2026, 11, 21, 0, 10)
        model.markSeen()

        #expect(env.defaults.string(forKey: "readingProgress.finishedDayNew") == "2026/11/21")
        #expect(env.defaults.string(forKey: "readingProgress.lastSeenNew") == "2020/07/13")
        #expect(env.defaults.object(forKey: "readingProgress.finishedDayOld") == nil)
        #expect(env.store.finishedDay(for: .newTestament) == Self.date(2026, 11, 21))
        #expect(env.store.storedProgress().lastSeenNew == Self.date(2020, 7, 13))
    }

    // AC-17 (M4 AC-3 / AC-24): a second markSeen (next day's clock) changes nothing
    @Test func ac17_secondMarkSeenIsNoOp() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let model = try Self.oldModel(env, homepage: try Self.oldHomepage(), youtube: try Self.youtube0713())
        await model.load()
        model.markSeen()
        let snapshot = env.rawSnapshot()
        let state = model.state

        try env.setTime(2026, 11, 21, 7)
        model.markSeen()

        #expect(env.rawSnapshot() == snapshot)
        #expect(env.store.finishedDay(for: .oldTestament) == Self.date(2026, 11, 20))
        #expect(model.isFinished == true)
        #expect(model.state == state)
    }

    // AC-17 (M4 AC-24): markSeen while .loading does nothing
    @Test func ac17_markSeenWhileLoadingIsNoOp() throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let model = try Self.oldModel(env, homepage: try Self.oldHomepage(), youtube: try Self.youtube0713())

        model.markSeen()

        #expect(model.state == .loading)
        #expect(model.isFinished == false)
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
    }

    // AC-17 (M4 AC-24 boundary): markSeen in .networkError does nothing
    @Test func ac17_markSeenWhenNetworkErrorIsNoOp() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = FakeHomepage(article: [15155: .failure(URLError(.notConnectedToInternet))],
                                    defaultSearch: try Self.emptyPage())
        let model = try Self.oldModel(env, homepage: homepage, youtube: try Self.youtube0713())
        await model.load()
        #expect(model.state == .networkError)

        model.markSeen()

        #expect(model.state == .networkError)
        #expect(model.isFinished == false)
        Self.expectStoreUntouched(env)
    }

    // MARK: - AC-18 refreshIfStale

    // AC-18 (PRD :34, M4 AC-21 ①): crossing noon does not switch or reload the open screen
    @Test func ac18_refreshAcrossNoonIsNoOp() async throws {
        let env = try Env(2026, 11, 20, 11, 58)
        defer { env.cleanup() }
        let homepage = try Self.oldHomepage()
        let youtube = try Self.youtube0713()
        let model = try Self.oldModel(env, homepage: homepage, youtube: youtube)
        await model.load()
        let before = model.state
        let count = await homepage.requested.count

        try env.setTime(2026, 11, 20, 12, 1)
        await model.refreshIfStale()

        #expect(model.state == before)
        #expect(model.testament == .oldTestament)
        #expect(Self.content(model.state)?.testament == .oldTestament)
        #expect(await homepage.requested.count == count)

        try env.setTime(2026, 11, 21, 7)
        await model.refreshIfStale()

        #expect(model.state == before)
        #expect(await homepage.requested.count == count)
        #expect(await youtube.requested.count == 0)
    }

    // AC-18 boundary: refresh after "다 봤어요" (same / next day) does nothing either
    @Test func ac18_refreshAfterFinishIsNoOp() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.oldHomepage()
        let model = try Self.oldModel(env, homepage: homepage, youtube: try Self.youtube0713())
        await model.load()
        model.markSeen()
        let state = model.state
        let count = await homepage.requested.count

        try env.setTime(2026, 11, 21, 7)
        await model.refreshIfStale()

        #expect(model.state == state)
        #expect(model.isFinished == true)
        #expect(await homepage.requested.count == count)
    }

    // AC-18 (M4 AC-21 boundary): refresh while still .loading (never loaded) does nothing
    @Test func ac18_refreshWhileLoadingIsNoOp() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.oldHomepage()
        let model = try Self.oldModel(env, homepage: homepage, youtube: try Self.youtube0713())

        await model.refreshIfStale()

        #expect(model.state == .loading)
        #expect(await homepage.requested.count == 0)
    }

    // AC-18 (M4 AC-21 ③): network error → refresh retries
    @Test func ac18_refreshAfterNetworkErrorRetries() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = FakeHomepage(article: [15155: .failure(URLError(.notConnectedToInternet))],
                                    defaultSearch: try Self.emptyPage())
        let model = try Self.oldModel(env, homepage: homepage, youtube: try Self.youtube0713())
        await model.load()
        #expect(model.state == .networkError)

        await homepage.setArticle(15155, .html(try Self.html("cast-body-15155")))
        await model.refreshIfStale()

        try Self.expectOld(model.state)
    }

    // MARK: - AC-19 article failures

    // AC-19 (M4 AC-19): unparseable article → network error, no YouTube, store untouched; retry recovers
    @Test func ac19_unparseableArticleIsNetworkError() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = FakeHomepage(article: [15155: .html("<html></html>")], defaultSearch: try Self.emptyPage())
        let youtube = try Self.youtube0713()
        let model = try Self.oldModel(env, homepage: homepage, youtube: youtube)

        await model.load()

        #expect(model.state == .networkError)
        #expect(model.state.message == "인터넷 연결을 확인해 주세요")
        #expect(await youtube.requested.count == 0)
        Self.expectStoreUntouched(env)

        await homepage.setArticle(15155, .html(try Self.html("cast-body-15155")))
        await model.retry()
        try Self.expectOld(model.state)
    }

    // AC-19 (M4 AC-8 / AC-19): article fetch throws → network error; retry recovers
    @Test func ac19_articleFetchErrorIsNetworkError() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = FakeHomepage(article: [15155: .failure(URLError(.timedOut))], defaultSearch: try Self.emptyPage())
        let youtube = try Self.youtube0713()
        let model = try Self.oldModel(env, homepage: homepage, youtube: youtube)

        await model.load()

        #expect(model.state == .networkError)
        #expect(await youtube.requested.count == 0)
        Self.expectStoreUntouched(env)

        await homepage.setArticle(15155, .html(try Self.html("cast-body-15155")))
        await model.retry()
        try Self.expectOld(model.state)
        #expect(Self.describe(await homepage.requested) == ["no=15155", "no=15155"])
    }

    // AC-19 boundary: HTTP error (badStatus) on the article is also a network error; retry recovers
    @Test func ac19_articleBadStatusIsNetworkError() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = FakeHomepage(article: [15155: .failure(DevotionLoadError.badStatus(500))],
                                    defaultSearch: try Self.emptyPage())
        let youtube = try Self.youtube0713()
        let model = try Self.oldModel(env, homepage: homepage, youtube: youtube)

        await model.load()

        #expect(model.state == .networkError)
        #expect(await youtube.requested.count == 0)
        Self.expectStoreUntouched(env)

        await homepage.setArticle(15155, .html(try Self.html("cast-body-15155")))
        await model.retry()
        try Self.expectOld(model.state)
    }

    // AC-19: entry without an article number → network error, nothing fetched, store untouched
    @Test func ac19_missingArticleNumberIsNetworkError() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.oldHomepage()
        let youtube = try Self.youtube0713()
        let noNumber = DevotionEntry(date: Self.date(2025, 9, 11), weekday: "목", passageText: "잠언 23:24-35",
                                     passage: nil, author: nil, articleNo: nil)
        let model = env.model(testament: .oldTestament, entry: noNumber, homepage: homepage, youtube: youtube)

        await model.load()

        #expect(model.state == .networkError)
        #expect(await homepage.requested.count == 0)
        #expect(await youtube.requested.count == 0)
        Self.expectStoreUntouched(env)
    }

    // MARK: - AC-20 video slot (M4 AC-10 / AC-12 / AC-13 / AC-20)

    // AC-20 (M4 AC-10): no matching search result → video slot "not found"; article still shown
    @Test func ac20_noMatchingVideoIsNotFound() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        let model = try Self.newModel(env, homepage: try Self.newHomepage(),
                                      youtube: FakeYouTube(.data(try Self.json("yt-search-20200714"))))

        await model.load()

        try Self.expectNew(model.state, video: .notFound)
        let c = try #require(Self.content(model.state))
        #expect(c.video.message == "영상을 찾지 못했습니다")
        let expectedSermon = try Self.article("cast-body-11480").sermon
        #expect(c.article.sermon == expectedSermon)
    }

    // AC-20 (M4 AC-12): YouTube network error → video slot error only; screen stays .showing
    @Test func ac20_youtubeErrorIsVideoSlotNetworkError() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        let youtube = FakeYouTube(.failure(URLError(.notConnectedToInternet)))
        let model = try Self.newModel(env, homepage: try Self.newHomepage(), youtube: youtube)

        await model.load()

        try Self.expectNew(model.state, video: .networkError)
        let c = try #require(Self.content(model.state))
        #expect(c.video.message == "인터넷 연결을 확인해 주세요")
        #expect(await youtube.requested.count == 1)
    }

    // AC-20 (M4 AC-12 boundary): YouTube HTTP error (badStatus) is the same video-slot error
    @Test func ac20_youtubeBadStatusIsVideoSlotNetworkError() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        let model = try Self.newModel(env, homepage: try Self.newHomepage(),
                                      youtube: FakeYouTube(.failure(YouTubeSearchError.badStatus(403))))

        await model.load()

        try Self.expectNew(model.state, video: .networkError)
    }

    // AC-20 (M4 AC-13): no API key (nil or "") → YouTube never called, video slot "not found"
    @Test(arguments: [nil, ""] as [String?])
    func ac20_noAPIKeySkipsSearch(apiKey: String?) async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        let youtube = try Self.youtube0713()
        let model = try Self.newModel(env, homepage: try Self.newHomepage(), youtube: youtube, apiKey: apiKey)

        await model.load()

        #expect(await youtube.requested.count == 0)
        try Self.expectNew(model.state, video: .notFound)
    }

    // AC-20 (M4 AC-20): no API key even when the article has an embed → "not found", article kept
    @Test(arguments: [nil, ""] as [String?])
    func ac20_noAPIKeyIgnoresArticleEmbed(apiKey: String?) async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let youtube = try Self.youtube0713()
        let model = try Self.oldModel(env, homepage: try Self.oldHomepage(), youtube: youtube, apiKey: apiKey)

        await model.load()

        try Self.expectOld(model.state, video: .notFound)
        let c = try #require(Self.content(model.state))
        #expect(c.video.message == "영상을 찾지 못했습니다")
        #expect(c.article.hymn == "454장 ‘주와 같이 되기를’")
        #expect(await youtube.requested.count == 0)
    }

    // MARK: - AC-24 messages and header

    // AC-24 (M4 AC-22): remaining screen-state messages
    @Test func ac24_screenStateMessages() {
        #expect(DevotionScreenState.networkError.message == "인터넷 연결을 확인해 주세요")
        #expect(DevotionScreenState.loading.message == nil)
    }

    // AC-24 (M4 AC-22): .showing has no message
    @Test func ac24_showingHasNoMessage() throws {
        let entry = try #require(DevotionTitleParser.parse("2020/07/13(월) “요한복음 5:30-47” / 작성: 박성호"))
        let content = DevotionScreenContent(
            testament: .newTestament,
            entry: entry,
            article: DevotionArticle(titleEntry: nil, passageText: "요한복음 5:30-47", hymn: nil, sermon: "s"),
            video: .notFound)
        #expect(DevotionScreenState.showing(content).message == nil)
    }

    // AC-24 (M4 AC-22): video-slot messages
    @Test func ac24_videoSlotMessages() {
        #expect(VideoSlot.notFound.message == "영상을 찾지 못했습니다")
        #expect(VideoSlot.networkError.message == "인터넷 연결을 확인해 주세요")
        #expect(VideoSlot.video(id: "x").message == nil)
    }

    // AC-24: header comes from the entry, not article.passageText
    @Test func ac24_headerComesFromEntry() {
        let entry = DevotionEntry(date: Self.date(2020, 7, 13), weekday: "월", passageText: "요한복음 5:30-47",
                                  passage: nil, author: nil)
        let content = DevotionScreenContent(
            testament: .newTestament,
            entry: entry,
            article: DevotionArticle(titleEntry: nil, passageText: "다른 값", hymn: nil, sermon: "s"),
            video: .notFound)
        #expect(content.headerDate == "2020/07/13(월)")
        #expect(content.headerPassage == "요한복음 5:30-47")
        #expect(content.headerTitle == "2020/07/13(월) 요한복음 5:30-47")
        #expect(content.headerTitle == entry.displayTitle)
    }

    // AC-24 boundary: header without weekday
    @Test func ac24_headerWithoutWeekday() {
        let entry = DevotionEntry(date: Self.date(2020, 7, 13), weekday: nil, passageText: "요한복음 5:30-47",
                                  passage: nil, author: nil)
        let content = DevotionScreenContent(
            testament: .newTestament,
            entry: entry,
            article: DevotionArticle(titleEntry: nil, passageText: "다른 값", hymn: nil, sermon: "s"),
            video: .notFound)
        #expect(content.headerDate == "2020/07/13")
        #expect(content.headerTitle == "2020/07/13 요한복음 5:30-47")
    }

    // MARK: - AC-26 finish button

    // AC-26: .next shows the button until markSeen
    @Test func ac26_nextModeButtonUntilFinished() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let model = try Self.oldModel(env, homepage: try Self.oldHomepage(), youtube: try Self.youtube0713())

        #expect(model.showsFinishButton == true)
        await model.load()
        #expect(model.showsFinishButton == true)
        model.markSeen()
        #expect(model.showsFinishButton == false)
    }

    // AC-26 / AC-14: .review never shows the button, and markSeen writes nothing
    @Test func ac26_reviewModeNeverShowsButton() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let model = try Self.oldModel(env, mode: .review, homepage: try Self.oldHomepage(), youtube: try Self.youtube0713())

        #expect(model.mode == .review)
        #expect(model.showsFinishButton == false)
        await model.load()
        try Self.expectOld(model.state)
        #expect(model.showsFinishButton == false)

        model.markSeen()

        #expect(model.showsFinishButton == false)
        #expect(model.isFinished == false)
        Self.expectStoreUntouched(env)
    }
}
