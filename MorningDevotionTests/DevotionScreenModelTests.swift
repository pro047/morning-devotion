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
        homepage: any DevotionHTMLFetching,
        youtube: FakeYouTube,
        apiKey: String? = "k"
    ) -> DevotionScreenModel {
        DevotionScreenModel(
            testament: testament,
            entry: entry,
            store: store,
            fetcher: homepage,
            searcher: youtube,
            apiKey: apiKey
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

    private static func oldModel(_ env: Env,
                                 homepage: FakeHomepage, youtube: FakeYouTube, apiKey: String? = "k") throws -> DevotionScreenModel {
        env.model(testament: .oldTestament, entry: try oldEntry(),
                  homepage: homepage, youtube: youtube, apiKey: apiKey)
    }

    private static func newModel(_ env: Env,
                                 homepage: FakeHomepage, youtube: FakeYouTube, apiKey: String? = "k") throws -> DevotionScreenModel {
        env.model(testament: .newTestament, entry: try newEntry(),
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

    /// "저장값 전부 그대로" on an empty store: all four raw keys absent, progress is the default.
    private static func expectStoreUntouched(_ env: Env) {
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
        #expect(env.store.storedProgress() == ReadingProgressStore.defaultProgress)
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
        #expect(model.isRead == false)
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

    // AC-15 / AC-65 (FR-4): markSeen records progress only (no finished day), stays .showing, isFinished
    @Test func ac15_markSeenRecordsAndFinishes() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let model = try Self.oldModel(env, homepage: try Self.oldHomepage(), youtube: try Self.youtube0713())
        await model.load()
        try Self.expectOld(model.state)
        let shown = model.state
        #expect(model.showsFinishButton == true)

        model.markSeen()

        // second slot = new default written by ReadingProgressStore.markSeen's internal load()
        #expect(env.rawSnapshot() == ["2025/09/11", "2020/07/11", nil, nil])
        #expect(env.store.storedProgress().lastSeenNew == Self.date(2020, 7, 11))
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

        #expect(env.defaults.object(forKey: "readingProgress.finishedDayOld") == nil)
        #expect(env.defaults.object(forKey: "readingProgress.finishedDayNew") == nil)
        #expect(env.store.storedProgress().lastSeenOld == Self.date(2025, 9, 11))
        #expect(env.store.storedProgress().lastSeenNew == Self.date(2020, 7, 11))
        #expect(model.isFinished == true)
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


    // MARK: - F-4 helpers (move)

    /// Synthetic page0915 (DESIGN §7-1): date-20250912 with 2025/09/12(금) → 2025/09/15(월), no=15157 → no=15160.
    private static func page0915() throws -> String {
        let page = try html("cast-search-date-20250912")
            .replacingOccurrences(of: "2025/09/12(금)", with: "2025/09/15(월)")
            .replacingOccurrences(of: "no=15157", with: "no=15160")
        let entries = DevotionListParser.parseEntries(fromHTML: page)
        try #require(entries.count == 1)
        try #require(entries.first?.date == date(2025, 9, 15))
        try #require(entries.first?.articleNo == 15160)
        return page
    }

    /// Old 2025/09/12 #15157 (from cast-search-date-20250912).
    private static func old0912() throws -> DevotionEntry {
        let e = try listEntry("cast-search-date-20250912", date(2025, 9, 12))
        #expect(e.articleNo == 15157)
        return e
    }

    /// Old 2025/09/15 #15160 (from page0915).
    private static func old0915() throws -> DevotionEntry {
        let entries = DevotionListParser.parseEntries(fromHTML: try page0915())
        return try #require(entries.first)
    }

    /// Searches 2025/09/11 → proverbs-23, 2025/09/12 → date-20250912, 2020/07/14 → date-20200714 (others 0건);
    /// articles 15155, 15157/15160 (→ body-15155), 11480, 11481 (→ body-11480).
    private static func moveHomepage() throws -> FakeHomepage {
        FakeHomepage(
            search: [
                "2025/09/11": .html(try html("cast-search-proverbs-23")),
                "2025/09/12": .html(try html("cast-search-date-20250912")),
                "2020/07/14": .html(try html("cast-search-date-20200714")),
            ],
            article: [
                15155: .html(try html("cast-body-15155")),
                15157: .html(try html("cast-body-15155")),
                15160: .html(try html("cast-body-15155")),
                11480: .html(try html("cast-body-11480")),
                11481: .html(try html("cast-body-11480")),
            ],
            defaultSearch: try emptyPage())
    }

    private static func since(_ homepage: FakeHomepage, _ from: Int) async -> [String] {
        Array(describe(await homepage.requested).dropFirst(from))
    }

    // MARK: - AC-62 … AC-68 move on the screen (US-2, US-3, US-5)

    // AC-62 (US-2 기준 1·2·5): 09/12 → "이전" → 09/11 shown in place → "다음" → 09/12 again; store untouched
    @Test func ac62_movePreviousThenNextInPlace() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let homepage = try Self.moveHomepage()
        let model = env.model(testament: .oldTestament, entry: try Self.old0912(),
                              homepage: homepage, youtube: try Self.youtube0713())
        #expect(model.isMoving == false)
        #expect(model.notice == nil)
        await model.load()
        #expect(Self.content(model.state)?.entry.date == Self.date(2025, 9, 12))

        await model.move(.previous)

        #expect(model.entry.date == Self.date(2025, 9, 11))
        #expect(model.entry.articleNo == 15155)
        let c = try #require(Self.content(model.state))
        #expect(c.entry.date == Self.date(2025, 9, 11))
        #expect(c.entry.articleNo == 15155)
        #expect(c.testament == .oldTestament)
        let expectedArticle = try Self.article("cast-body-15155")
        #expect(c.article == expectedArticle)
        #expect(model.isMoving == false)
        #expect(model.notice == nil)

        await model.move(.next)

        #expect(model.entry.date == Self.date(2025, 9, 12))
        #expect(model.entry.articleNo == 15157)
        let c2 = try #require(Self.content(model.state))
        #expect(c2.entry.date == Self.date(2025, 9, 12))
        #expect(c2.headerTitle == "2025/09/12(금) 잠언 24:1-10")
        #expect(Self.describe(await homepage.requested)
            == ["no=15157", "search=2025/09/11", "no=15155", "search=2025/09/12", "no=15157"])
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
        #expect(model.isFinished == false)
    }

    // AC-63 (US-2 기준 3, [결정] 2): skipped (unread, two ahead) entries still show the finish button
    @Test func ac63_moveNextToSkippedEntryShowsFinish() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let homepage = try Self.moveHomepage()
        await homepage.setSearch("2025/09/15", .html(try Self.page0915()))
        let model = env.model(testament: .oldTestament, entry: try Self.old0912(),
                              homepage: homepage, youtube: try Self.youtube0713())
        #expect(model.isRead == false)            // lastSeenOld default 09/10
        #expect(model.showsFinishButton == true)
        await model.load()
        let before = await homepage.requested.count

        await model.move(.next)

        #expect(model.entry.date == Self.date(2025, 9, 15))
        #expect(model.entry.articleNo == 15160)
        #expect(model.isRead == false)
        #expect(model.showsFinishButton == true)
        #expect(Self.content(model.state)?.entry.articleNo == 15160)
        #expect(await Self.since(homepage, before)
            == ["search=2025/09/13", "search=2025/09/14", "search=2025/09/15", "no=15160"])
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
    }

    // AC-64 (US-3 기준 1·2): read ⇔ date <= lastSeen; read screens have no button and markSeen writes nothing
    @Test func ac64_readFollowsProgress() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        env.defaults.set("2025/09/12", forKey: "readingProgress.lastSeenOld")
        let snapshot = env.rawSnapshot()
        #expect(snapshot == ["2025/09/12", nil, nil, nil])

        for entry in [try Self.oldEntry(), try Self.old0912()] {
            let model = env.model(testament: .oldTestament, entry: entry,
                                  homepage: try Self.moveHomepage(), youtube: try Self.youtube0713())
            #expect(model.isRead == true)
            #expect(model.showsFinishButton == false)
            await model.load()
            #expect(Self.content(model.state) != nil)
            model.markSeen()
            #expect(env.rawSnapshot() == snapshot)
            #expect(model.isFinished == false)
            #expect(model.showsFinishButton == false)
        }

        let unread = env.model(testament: .oldTestament, entry: try Self.old0915(),
                               homepage: try Self.moveHomepage(), youtube: try Self.youtube0713())
        #expect(unread.isRead == false)
        #expect(unread.showsFinishButton == true)

        // moving from read 09/12 to unread 09/15 flips both flags
        let homepage = try Self.moveHomepage()
        await homepage.setSearch("2025/09/15", .html(try Self.page0915()))
        let model = env.model(testament: .oldTestament, entry: try Self.old0912(),
                              homepage: homepage, youtube: try Self.youtube0713())
        await model.load()
        #expect(model.isRead == true)
        #expect(model.showsFinishButton == false)
        await model.move(.next)
        #expect(model.entry.date == Self.date(2025, 9, 15))
        #expect(model.isRead == false)
        #expect(model.showsFinishButton == true)
        #expect(env.rawSnapshot() == snapshot)
    }

    // AC-64 boundary: isRead is read from the store on every access (changes when progress changes elsewhere)
    @Test func ac64_isReadTracksStoreChanges() throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let model = env.model(testament: .oldTestament, entry: try Self.old0912(),
                              homepage: try Self.moveHomepage(), youtube: try Self.youtube0713())
        #expect(model.isRead == false)
        env.defaults.set("2025/09/12", forKey: "readingProgress.lastSeenOld")
        #expect(model.isRead == true)
        #expect(model.showsFinishButton == false)
        // the other testament's progress does not count
        env.defaults.set("2025/09/11", forKey: "readingProgress.lastSeenOld")
        env.defaults.set("2030/01/01", forKey: "readingProgress.lastSeenNew")
        #expect(model.isRead == false)
    }

    // AC-65 (FR-4): pressing on a skipped entry records that entry's date; new testament records only lastSeenNew
    @Test func ac65_markSeenRecordsShownEntryDate() async throws {
        do {
            let env = try Env(2026, 11, 22, 7)
            defer { env.cleanup() }
            let model = env.model(testament: .oldTestament, entry: try Self.old0912(),
                                  homepage: try Self.moveHomepage(), youtube: try Self.youtube0713())
            await model.load()
            model.markSeen()
            #expect(env.store.storedProgress().lastSeenOld == Self.date(2025, 9, 12))
            #expect(env.rawSnapshot() == ["2025/09/12", "2020/07/11", nil, nil])
            #expect(model.isFinished == true)
            #expect(model.showsFinishButton == false)
            let snapshot = env.rawSnapshot()
            model.markSeen()
            #expect(env.rawSnapshot() == snapshot)
        }
        do {
            let env = try Env(2026, 11, 22, 13)
            defer { env.cleanup() }
            let model = try Self.newModel(env, homepage: try Self.newHomepage(), youtube: try Self.youtube0713())
            await model.load()
            model.markSeen()
            #expect(env.defaults.string(forKey: "readingProgress.lastSeenNew") == "2020/07/13")
            #expect(env.defaults.object(forKey: "readingProgress.finishedDayNew") == nil)
            #expect(env.defaults.object(forKey: "readingProgress.finishedDayOld") == nil)
            #expect(env.rawSnapshot() == ["2025/09/10", "2020/07/13", nil, nil])
        }
    }

    // AC-65 boundary: markSeen after a move records the moved-to entry, not the opened one
    @Test func ac65_markSeenAfterMoveRecordsCurrentEntry() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let model = env.model(testament: .oldTestament, entry: try Self.oldEntry(),
                              homepage: try Self.moveHomepage(), youtube: try Self.youtube0713())
        await model.load()
        await model.move(.next)   // 09/11 → 09/12
        #expect(model.entry.date == Self.date(2025, 9, 12))
        model.markSeen()
        #expect(env.defaults.string(forKey: "readingProgress.lastSeenOld") == "2025/09/12")
        #expect(model.isFinished == true)
    }

    // AC-66 (US-5, FR-10 screen): failed moves keep entry and state, set notice; success clears it
    @Test func ac66_failedMoveKeepsScreenWithNotice() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let homepage = try Self.oldHomepage()   // every search is the 0-entry page
        let model = try Self.oldModel(env, homepage: homepage, youtube: try Self.youtube0713())
        await model.load()
        let entry = model.entry
        let shown = model.state
        try Self.expectOld(shown)

        var before = await homepage.requested.count
        await model.move(.next)
        #expect(model.notice == "다음 묵상을 찾지 못했습니다")
        #expect(model.entry == entry)
        #expect(model.state == shown)
        let nextRequests = await Self.since(homepage, before)
        #expect(nextRequests == [
            "search=2025/09/12", "search=2025/09/13", "search=2025/09/14", "search=2025/09/15",
            "search=2025/09/16", "search=2025/09/17", "search=2025/09/18",
        ])
        #expect(nextRequests.filter { $0.hasPrefix("no=") }.isEmpty)
        #expect(model.isMoving == false)

        before = await homepage.requested.count
        await model.move(.previous)
        #expect(model.notice == "이전 묵상을 찾지 못했습니다")
        #expect(model.entry == entry)
        #expect(model.state == shown)
        #expect(await Self.since(homepage, before) == [
            "search=2025/09/10", "search=2025/09/09", "search=2025/09/08", "search=2025/09/07",
            "search=2025/09/06", "search=2025/09/05", "search=2025/09/04",
        ])
        #expect(model.isMoving == false)

        await homepage.setSearch("2025/09/12", .failure(URLError(.notConnectedToInternet)))
        before = await homepage.requested.count
        await model.move(.next)
        #expect(model.notice == "인터넷 연결을 확인해 주세요")
        #expect(model.entry == entry)
        #expect(model.state == shown)
        #expect(await Self.since(homepage, before) == ["search=2025/09/12"])
        #expect(model.isMoving == false)
        Self.expectStoreUntouched(env)

        await homepage.setSearch("2025/09/12", .html(try Self.html("cast-search-date-20250912")))
        await homepage.setArticle(15157, .html(try Self.html("cast-body-15155")))
        await model.move(.next)
        #expect(model.notice == nil)
        #expect(model.entry.date == Self.date(2025, 9, 12))
        #expect(Self.content(model.state)?.entry.articleNo == 15157)
        #expect(model.isMoving == false)
        Self.expectStoreUntouched(env)
    }

    // AC-67: moving re-finds the video (YouTube searched again for the new entry)
    @Test func ac67_moveReloadsVideo() async throws {
        let env = try Env(2026, 11, 22, 13)
        defer { env.cleanup() }
        let homepage = try Self.moveHomepage()
        let youtube = try Self.youtube0713()
        let model = try Self.newModel(env, homepage: homepage, youtube: youtube)
        await model.load()
        try Self.expectNew(model.state)
        #expect(await youtube.requested.count == 1)

        await model.move(.next)

        #expect(model.entry.date == Self.date(2020, 7, 14))
        #expect(model.entry.articleNo == 11481)
        let c = try #require(Self.content(model.state))
        #expect(c.entry.date == Self.date(2020, 7, 14))
        #expect(c.testament == .newTestament)
        #expect(c.headerTitle == "2020/07/14(화) 요한복음 6:1-21")
        #expect(await youtube.requested.count == 2)
        #expect(Self.describe(await homepage.requested) == ["no=11480", "search=2020/07/14", "no=11481"])
    }

    // AC-68: move is ignored while .loading and after finishing
    @Test func ac68_moveIgnoredWhileLoadingOrFinished() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let homepage = try Self.moveHomepage()
        let model = env.model(testament: .oldTestament, entry: try Self.old0912(),
                              homepage: homepage, youtube: try Self.youtube0713())

        await model.move(.previous)
        await model.move(.next)
        #expect(await homepage.requested.count == 0)
        #expect(model.state == .loading)
        #expect(model.entry.date == Self.date(2025, 9, 12))
        #expect(model.notice == nil)
        #expect(model.isMoving == false)

        await model.load()
        model.markSeen()
        #expect(model.isFinished == true)
        let count = await homepage.requested.count
        let state = model.state
        await model.move(.previous)
        await model.move(.next)
        #expect(await homepage.requested.count == count)
        #expect(model.entry.date == Self.date(2025, 9, 12))
        #expect(model.state == state)
        #expect(model.notice == nil)
    }

    // AC-68: in .networkError (article failed) move still works and loads the found entry
    @Test func ac68_moveWorksFromNetworkError() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let homepage = try Self.moveHomepage()
        await homepage.setArticle(15157, .failure(URLError(.notConnectedToInternet)))
        let model = env.model(testament: .oldTestament, entry: try Self.old0912(),
                              homepage: homepage, youtube: try Self.youtube0713())
        await model.load()
        #expect(model.state == .networkError)

        await model.move(.previous)

        #expect(model.entry.date == Self.date(2025, 9, 11))
        #expect(Self.content(model.state)?.entry.articleNo == 15155)
        #expect(Self.describe(await homepage.requested) == ["no=15157", "search=2025/09/11", "no=15155"])
        #expect(model.notice == nil)
        #expect(model.isMoving == false)
        Self.expectStoreUntouched(env)
    }

    // AC-68 / [결정] 4: while a move search is running, isMoving is true and a second move / markSeen are ignored
    @Test func ac68_moveInFlightBlocksSecondMove() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let gate = GatedHomepage(inner: try Self.moveHomepage())
        let model = env.model(testament: .oldTestament, entry: try Self.old0912(),
                              homepage: gate, youtube: try Self.youtube0713())
        await model.load()
        #expect(model.showsFinishButton == true)
        await gate.close()

        let task = Task { await model.move(.previous) }
        var waiting = 0
        for _ in 0..<10_000 {
            waiting = await gate.waitingCount
            if waiting > 0 { break }
            await Task.yield()
        }
        try #require(waiting == 1)
        #expect(model.isMoving == true)
        let count = await gate.count

        await model.move(.next)
        model.markSeen()
        #expect(await gate.count == count)
        #expect(model.isFinished == false)
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])

        await gate.open()
        await task.value
        #expect(model.isMoving == false)
        #expect(model.entry.date == Self.date(2025, 9, 11))
    }

    // MARK: - AC-79 / AC-80 feedback and swap-after-build (F-5 US-4, FR-8)

    // AC-79 (FR-8): feedback is nil until an attempt finishes; success / failure; serial increments; ignored moves leave it
    @Test func ac79_feedbackPerAttempt() async throws {
        // success
        do {
            let env = try Env(2026, 11, 22, 7)
            defer { env.cleanup() }
            let model = env.model(testament: .oldTestament, entry: try Self.old0912(),
                                  homepage: try Self.moveHomepage(), youtube: try Self.youtube0713())
            #expect(model.feedback == nil)
            await model.move(.previous)   // ignored while .loading
            #expect(model.feedback == nil)
            await model.load()
            #expect(model.feedback == nil)

            await model.move(.previous)   // 09/12 → 09/11
            #expect(model.entry.date == Self.date(2025, 9, 11))
            #expect(model.feedback == MoveFeedback(serial: 1, direction: .previous, succeeded: true))

            await model.move(.next)       // 09/11 → 09/12
            #expect(model.entry.date == Self.date(2025, 9, 12))
            #expect(model.feedback == MoveFeedback(serial: 2, direction: .next, succeeded: true))
        }
        // failure, then serial 2, then finished → unchanged
        do {
            let env = try Env(2026, 11, 22, 7)
            defer { env.cleanup() }
            let model = try Self.oldModel(env, homepage: try Self.oldHomepage(), youtube: try Self.youtube0713())
            await model.load()
            #expect(model.feedback == nil)

            await model.move(.next)
            #expect(model.notice == "다음 묵상을 찾지 못했습니다")
            #expect(model.feedback == MoveFeedback(serial: 1, direction: .next, succeeded: false))

            await model.move(.previous)
            #expect(model.notice == "이전 묵상을 찾지 못했습니다")
            #expect(model.feedback == MoveFeedback(serial: 2, direction: .previous, succeeded: false))

            model.markSeen()
            #expect(model.isFinished == true)
            await model.move(.next)
            await model.move(.previous)
            #expect(model.feedback == MoveFeedback(serial: 2, direction: .previous, succeeded: false))
        }
    }

    // AC-79: network error on the search is a failed attempt
    @Test func ac79_feedbackOnSearchNetworkError() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let homepage = try Self.oldHomepage()
        await homepage.setSearch("2025/09/12", .failure(URLError(.notConnectedToInternet)))
        let model = try Self.oldModel(env, homepage: homepage, youtube: try Self.youtube0713())
        await model.load()
        await model.move(.next)
        #expect(model.notice == "인터넷 연결을 확인해 주세요")
        #expect(model.feedback == MoveFeedback(serial: 1, direction: .next, succeeded: false))
    }

    // AC-80 ([결정] 4): while the found entry's article loads, the current entry, state and locks stay
    @Test func ac80_swapsOnlyAfterNewContentIsBuilt() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let gate = ArticleGatedHomepage(inner: try Self.moveHomepage())
        let model = env.model(testament: .oldTestament, entry: try Self.old0912(),
                              homepage: gate, youtube: try Self.youtube0713())
        await model.load()
        let shown = model.state
        #expect(Self.content(shown)?.entry.date == Self.date(2025, 9, 12))
        let finishBefore = model.showsFinishButton
        #expect(finishBefore == true)
        await gate.close()

        let task = Task { await model.move(.previous) }
        var waiting = 0
        for _ in 0..<10_000 {
            waiting = await gate.waitingCount
            if waiting > 0 { break }
            await Task.yield()
        }
        try #require(waiting == 1)   // search 09/11 done, article 15155 parked

        #expect(model.entry.date == Self.date(2025, 9, 12))
        #expect(model.state == shown)
        #expect(model.isMoving == true)
        #expect(model.showsFinishButton == finishBefore)
        #expect(model.notice == nil)
        #expect(model.feedback == nil)

        // locks: markSeen and a second move are ignored while the article loads
        let count = await gate.count
        model.markSeen()
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
        #expect(model.isFinished == false)
        await model.move(.next)
        await model.move(.previous)
        #expect(await gate.count == count)

        await gate.open()
        await task.value

        #expect(model.entry.date == Self.date(2025, 9, 11))
        let c = try #require(Self.content(model.state))
        #expect(c.entry.articleNo == 15155)
        #expect(c.entry.date == Self.date(2025, 9, 11))
        #expect(model.isMoving == false)
        #expect(model.notice == nil)
        #expect(model.feedback == MoveFeedback(serial: 1, direction: .previous, succeeded: true))
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
    }

    // AC-80 failure path: found entry, article fails → entry is the found one, state .networkError, failed feedback
    @Test func ac80_articleFailureAfterFoundEntry() async throws {
        let env = try Env(2026, 11, 22, 7)
        defer { env.cleanup() }
        let homepage = try Self.moveHomepage()
        await homepage.setArticle(15155, .failure(URLError(.notConnectedToInternet)))
        let model = env.model(testament: .oldTestament, entry: try Self.old0912(),
                              homepage: homepage, youtube: try Self.youtube0713())
        await model.load()
        #expect(Self.content(model.state)?.entry.date == Self.date(2025, 9, 12))

        await model.move(.previous)

        #expect(model.entry.date == Self.date(2025, 9, 11))
        #expect(model.state == .networkError)
        #expect(model.isMoving == false)
        #expect(model.feedback?.succeeded == false)
        #expect(model.feedback == MoveFeedback(serial: 1, direction: .previous, succeeded: false))
        #expect(Self.describe(await homepage.requested) == ["no=15157", "search=2025/09/11", "no=15155"])
        Self.expectStoreUntouched(env)

        // from .networkError the screen can still move (F-4 AC-68) and recover
        await homepage.setArticle(15155, .html(try Self.html("cast-body-15155")))
        await model.move(.next)   // 09/11 → 09/12
        #expect(model.entry.date == Self.date(2025, 9, 12))
        #expect(Self.content(model.state)?.entry.articleNo == 15157)
        #expect(model.feedback == MoveFeedback(serial: 2, direction: .next, succeeded: true))
    }
}

/// Wraps a fetcher; while closed, article (`no=`) requests suspend until `open()`. Search requests pass through.
private actor ArticleGatedHomepage: DevotionHTMLFetching {
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
        let isArticle = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.contains(where: { $0.name == "no" }) ?? false
        if closed && isArticle {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                self.park(c)
            }
        }
        return try await inner.fetchHTML(from: url)
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
