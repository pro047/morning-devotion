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

    /// "New instance": fresh UserDefaults and store on the same suite name.
    func reopen() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        store = ReadingProgressStore(defaults: defaults)
    }

    func model(homepage: FakeHomepage, youtube: FakeYouTube, apiKey: String? = "k") -> DevotionScreenModel {
        let clock = self.clock
        return DevotionScreenModel(
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

    private static func searchValues(_ urls: [URL]) -> [String] {
        describe(urls).filter { $0.hasPrefix("search=") }.map { String($0.dropFirst("search=".count)) }
    }

    /// 1번 조건 homepage: search 2025/09/11 → proverbs-23, article 15155 → body-15155.
    private static func homepage1() throws -> FakeHomepage {
        FakeHomepage(
            search: ["2025/09/11": .html(try html("cast-search-proverbs-23"))],
            article: [15155: .html(try html("cast-body-15155"))],
            defaultSearch: try emptyPage())
    }

    /// 2번 조건 homepage: 2020/07/12 → 0 entries, 2020/07/13 → john-5, article 11480 → body-11480.
    private static func homepage2() throws -> FakeHomepage {
        FakeHomepage(
            search: [
                "2020/07/12": .html(try emptyPage()),
                "2020/07/13": .html(try html("cast-search-john-5")),
            ],
            article: [11480: .html(try html("cast-body-11480"))],
            defaultSearch: try emptyPage())
    }

    private static func youtube0713() throws -> FakeYouTube {
        FakeYouTube(.data(try json("yt-search-20200713")))
    }

    /// Expected AC-1 content (old testament 2025/09/11, video from the article embed).
    private static func expectCondition1(_ state: DevotionScreenState, video: VideoSlot = .video(id: "PR9GK_S83NU")) throws {
        let c = try #require(content(state))
        #expect(c.testament == .oldTestament)
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

    /// Expected AC-2 content (new testament 2020/07/13), video slot given.
    private static func expectCondition2(_ state: DevotionScreenState, video: VideoSlot = .video(id: "M5VtIg1WAic")) throws {
        let c = try #require(content(state))
        #expect(c.testament == .newTestament)
        #expect(c.entry.date == date(2020, 7, 13))
        #expect(c.entry.weekday == "월")
        #expect(c.entry.passageText == "요한복음 5:30-47")
        #expect(c.entry.articleNo == 11480)
        let expectedArticle = try article("cast-body-11480")
        #expect(c.article == expectedArticle)
        #expect(c.video == video)
    }

    /// §5-0 "저장값 전부 그대로" on an empty store: all four raw keys absent, API values are defaults / nil.
    private static func expectStoreUntouched(_ env: Env) {
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
        #expect(env.store.storedProgress() == ReadingProgressStore.defaultProgress)
        #expect(env.store.finishedDay(for: .oldTestament) == nil)
        #expect(env.store.finishedDay(for: .newTestament) == nil)
    }

    // MARK: - AC-1 / AC-2 first open

    // AC-1: morning, empty store → old 2025/09/11 with the article's embed video, no YouTube search
    @Test func ac1_morningShowsOldTestamentWithArticleVideo() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.homepage1()
        let youtube = try Self.youtube0713()
        let model = env.model(homepage: homepage, youtube: youtube)

        #expect(model.state == .loading)
        await model.load()

        try Self.expectCondition1(model.state)
        #expect(await youtube.requested.count == 0)
        let requested = await homepage.requested
        #expect(Self.describe(requested) == ["search=2025/09/11", "no=15155"])
        #expect(requested.last == DevotionArticleURL.url(articleNo: 15155))
        #expect(model.state.message == nil)
    }

    // AC-2: afternoon, empty store → new 2020/07/13 via 2 searches, video from one YouTube search
    @Test func ac2_afternoonShowsNewTestamentWithSearchedVideo() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        let homepage = try Self.homepage2()
        let youtube = try Self.youtube0713()
        let model = env.model(homepage: homepage, youtube: youtube)

        await model.load()

        try Self.expectCondition2(model.state)
        let requested = await homepage.requested
        #expect(Self.searchValues(requested) == ["2020/07/12", "2020/07/13"])
        #expect(Self.describe(requested) == ["search=2020/07/12", "search=2020/07/13", "no=11480"])
        #expect(await youtube.requested.count == 1)
    }

    // AC-2 boundary: load() does not write anything on the success path either
    @Test func ac2_loadDoesNotWriteStore() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        let model = env.model(homepage: try Self.homepage2(), youtube: try Self.youtube0713())
        await model.load()
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
    }

    // MARK: - AC-3 / AC-4 / AC-5 / AC-6 "다 봤어요"

    // AC-3: markSeen records the devotion date and today's finished day for that testament only
    @Test func ac3_markSeenRecordsProgressAndFinishedDay() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let model = env.model(homepage: try Self.homepage1(), youtube: try Self.youtube0713())
        await model.load()
        try Self.expectCondition1(model.state)

        model.markSeen()

        #expect(env.defaults.string(forKey: "readingProgress.finishedDayOld") == "2026/11/20")
        #expect(env.defaults.object(forKey: "readingProgress.finishedDayNew") == nil)
        #expect(env.store.finishedDay(for: .oldTestament) == Self.date(2026, 11, 20))
        #expect(env.store.finishedDay(for: .newTestament) == nil)
        #expect(model.state == .finishedToday(.oldTestament))
        #expect(model.state.message == "오늘 구약 묵상을 마쳤습니다")
        #expect(env.store.load().lastSeenOld == Self.date(2025, 9, 11))
        #expect(env.store.load().lastSeenNew == Self.date(2020, 7, 11))
    }

    // AC-3 boundary: testament follows the shown devotion, finished day follows the moment of pressing
    // (opened 11:58 as old testament, pressed at 12:01 → old is finished)
    @Test func ac3_markSeenAcrossNoonKeepsShownTestament() async throws {
        let env = try Env(2026, 11, 20, 11, 58)
        defer { env.cleanup() }
        let model = env.model(homepage: try Self.homepage1(), youtube: try Self.youtube0713())
        await model.load()
        try Self.expectCondition1(model.state)

        try env.setTime(2026, 11, 20, 12, 1)
        model.markSeen()

        #expect(model.state == .finishedToday(.oldTestament))
        #expect(env.store.finishedDay(for: .oldTestament) == Self.date(2026, 11, 20))
        #expect(env.store.finishedDay(for: .newTestament) == nil)
        #expect(env.store.storedProgress().lastSeenOld == Self.date(2025, 9, 11))
        #expect(env.store.storedProgress().lastSeenNew == Self.date(2020, 7, 11))
    }

    // AC-3 boundary: finished day is the press moment's local day (pressed after midnight → next day)
    @Test func ac3_markSeenAfterMidnightUsesPressDay() async throws {
        let env = try Env(2026, 11, 20, 23, 50)
        defer { env.cleanup() }
        // 23:50 is new testament; give it the 2번 조건 responses.
        let model = env.model(homepage: try Self.homepage2(), youtube: try Self.youtube0713())
        await model.load()
        try Self.expectCondition2(model.state)

        try env.setTime(2026, 11, 21, 0, 10)
        model.markSeen()

        #expect(model.state == .finishedToday(.newTestament))
        #expect(env.store.finishedDay(for: .newTestament) == Self.date(2026, 11, 21))
        #expect(env.store.storedProgress().lastSeenNew == Self.date(2020, 7, 13))
    }

    // AC-3 / AC-24 boundary: a second markSeen in .finishedToday changes nothing
    @Test func ac3_secondMarkSeenIsNoOp() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let model = env.model(homepage: try Self.homepage1(), youtube: try Self.youtube0713())
        await model.load()
        model.markSeen()
        let snapshot = env.rawSnapshot()

        try env.setTime(2026, 11, 21, 7)
        model.markSeen()

        #expect(model.state == .finishedToday(.oldTestament))
        #expect(env.rawSnapshot() == snapshot)
        #expect(env.store.finishedDay(for: .oldTestament) == Self.date(2026, 11, 20))
    }

    // AC-4: reopened store, same day 11:59 → finished message without any network request
    @Test func ac4_finishedTodayBlocksSameTestamentSameDay() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let first = env.model(homepage: try Self.homepage1(), youtube: try Self.youtube0713())
        await first.load()
        first.markSeen()

        try env.reopen()
        try env.setTime(2026, 11, 20, 11, 59)
        let homepage = try Self.homepage1()
        let youtube = try Self.youtube0713()
        let model = env.model(homepage: homepage, youtube: youtube)
        await model.load()

        #expect(model.state == .finishedToday(.oldTestament))
        #expect(model.state.message == "오늘 구약 묵상을 마쳤습니다")
        #expect(await homepage.requested.count == 0)
        #expect(await youtube.requested.count == 0)
    }

    // AC-5: old finished today does not block the afternoon new testament
    @Test func ac5_afternoonAfterOldFinishedShowsNew() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let first = env.model(homepage: try Self.homepage1(), youtube: try Self.youtube0713())
        await first.load()
        first.markSeen()

        try env.reopen()
        try env.setTime(2026, 11, 20, 12, 0)
        let model = env.model(homepage: try Self.homepage2(), youtube: try Self.youtube0713())
        await model.load()

        try Self.expectCondition2(model.state)
    }

    // AC-6: next morning → search continues from the recorded 2025/09/11 and requests article 15157
    @Test func ac6_nextMorningShowsFollowingDevotion() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let first = env.model(homepage: try Self.homepage1(), youtube: try Self.youtube0713())
        await first.load()
        first.markSeen()

        try env.reopen()
        try env.setTime(2026, 11, 21, 7)
        let homepage = FakeHomepage(
            search: ["2025/09/12": .html(try Self.html("cast-search-date-20250912"))],
            // No cast-body-15157 fixture exists; 15155 stands in (only the request URL is asserted).
            article: [15157: .html(try Self.html("cast-body-15155"))],
            defaultSearch: try Self.emptyPage())
        let model = env.model(homepage: homepage, youtube: try Self.youtube0713())
        await model.load()

        let c = try #require(Self.content(model.state))
        #expect(c.testament == .oldTestament)
        #expect(c.entry.date == Self.date(2025, 9, 12))
        #expect(c.entry.weekday == "금")
        #expect(c.entry.passageText == "잠언 24:1-10")
        #expect(c.entry.articleNo == 15157)
        let requested = await homepage.requested
        #expect(Self.searchValues(requested) == ["2025/09/12"])
        #expect(requested.last == DevotionArticleURL.url(articleNo: 15157))
        #expect(requested.count == 2)
    }

    // MARK: - AC-7 reopening without "다 봤어요"

    // AC-7: no markSeen → a new instance shows the same devotion again
    @Test func ac7_withoutMarkSeenSameDevotionAgain() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let first = env.model(homepage: try Self.homepage1(), youtube: try Self.youtube0713())
        await first.load()
        let c1 = try #require(Self.content(first.state))

        try env.reopen()
        let model = env.model(homepage: try Self.homepage1(), youtube: try Self.youtube0713())
        await model.load()

        let c2 = try #require(Self.content(model.state))
        #expect(c2 == c1)
        try Self.expectCondition1(model.state)
    }

    // MARK: - AC-8 / AC-9 / AC-19 failure paths

    // AC-8: list fetch network error → whole-screen error, store untouched; retry after recovery shows AC-1
    @Test func ac8_networkErrorThenRetry() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = FakeHomepage(
            search: ["2025/09/11": .failure(URLError(.notConnectedToInternet))],
            article: [15155: .html(try Self.html("cast-body-15155"))],
            defaultSearch: try Self.emptyPage())
        let model = env.model(homepage: homepage, youtube: try Self.youtube0713())

        await model.load()
        #expect(model.state == .networkError)
        #expect(model.state.message == "인터넷 연결을 확인해 주세요")
        Self.expectStoreUntouched(env)

        await homepage.setSearch("2025/09/11", .html(try Self.html("cast-search-proverbs-23")))
        await model.retry()
        try Self.expectCondition1(model.state)
    }

    // AC-8 boundary: a garbage stored lastSeen is not rewritten on the failure path (raw value kept)
    @Test func ac8_networkErrorKeepsGarbageRawValue() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        env.defaults.set("garbage", forKey: "readingProgress.lastSeenOld")
        let before = env.rawSnapshot()
        let homepage = FakeHomepage(
            search: ["2025/09/11": .failure(URLError(.notConnectedToInternet))],
            defaultSearch: try Self.emptyPage())
        let model = env.model(homepage: homepage, youtube: try Self.youtube0713())

        await model.load()

        #expect(model.state == .networkError)
        #expect(env.rawSnapshot() == before)
        #expect(env.defaults.string(forKey: "readingProgress.lastSeenOld") == "garbage")
        // garbage → default 2025/09/10 is used, so the first search is 2025/09/11
        #expect(Self.searchValues(await homepage.requested) == ["2025/09/11"])
    }

    // AC-9: seven empty days → "not found", 7 searches 09/11…09/17, no article request, store untouched
    @Test func ac9_noNextDevotionAfterSevenDays() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = FakeHomepage(defaultSearch: try Self.emptyPage())
        let youtube = try Self.youtube0713()
        let model = env.model(homepage: homepage, youtube: youtube)

        await model.load()

        #expect(model.state == .noNextDevotion)
        #expect(model.state.message == "다음 묵상을 찾지 못했습니다")
        let requested = await homepage.requested
        #expect(Self.searchValues(requested) == [
            "2025/09/11", "2025/09/12", "2025/09/13", "2025/09/14", "2025/09/15", "2025/09/16", "2025/09/17",
        ])
        #expect(requested.count == 7)
        #expect(await youtube.requested.count == 0)
        Self.expectStoreUntouched(env)
    }

    // AC-19: article fetched but unparseable → whole-screen network error, store untouched
    @Test func ac19_unparseableArticleIsNetworkError() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = FakeHomepage(
            search: ["2025/09/11": .html(try Self.html("cast-search-proverbs-23"))],
            article: [15155: .html("<html></html>")],
            defaultSearch: try Self.emptyPage())
        let youtube = try Self.youtube0713()
        let model = env.model(homepage: homepage, youtube: youtube)

        await model.load()

        #expect(model.state == .networkError)
        #expect(await youtube.requested.count == 0)
        Self.expectStoreUntouched(env)
    }

    // AC-19: article fetch throws → whole-screen network error, store untouched
    @Test func ac19_articleFetchErrorIsNetworkError() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = FakeHomepage(
            search: ["2025/09/11": .html(try Self.html("cast-search-proverbs-23"))],
            article: [15155: .failure(URLError(.timedOut))],
            defaultSearch: try Self.emptyPage())
        let model = env.model(homepage: homepage, youtube: try Self.youtube0713())

        await model.load()

        #expect(model.state == .networkError)
        Self.expectStoreUntouched(env)
    }

    // AC-19 boundary: HTTP error on the article (badStatus) is also a whole-screen network error
    @Test func ac19_articleBadStatusIsNetworkError() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = FakeHomepage(
            search: ["2025/09/11": .html(try Self.html("cast-search-proverbs-23"))],
            article: [15155: .failure(DevotionLoadError.badStatus(500))],
            defaultSearch: try Self.emptyPage())
        let model = env.model(homepage: homepage, youtube: try Self.youtube0713())

        await model.load()

        #expect(model.state == .networkError)
        Self.expectStoreUntouched(env)
    }

    // MARK: - AC-10 / AC-12 / AC-13 / AC-20 video slot

    // AC-10: no matching search result → "영상을 찾지 못했습니다" in the video slot only; article still shown
    @Test func ac10_noMatchingVideoIsNotFound() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        let model = env.model(homepage: try Self.homepage2(), youtube: FakeYouTube(.data(try Self.json("yt-search-20200714"))))

        await model.load()

        try Self.expectCondition2(model.state, video: .notFound)
        let c = try #require(Self.content(model.state))
        #expect(c.video.message == "영상을 찾지 못했습니다")
        let expectedSermon = try Self.article("cast-body-11480").sermon
        #expect(c.article.sermon == expectedSermon)
    }

    // AC-12: YouTube network error → video slot shows the connection message; article still shown
    @Test func ac12_youtubeErrorIsVideoSlotNetworkError() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        let youtube = FakeYouTube(.failure(URLError(.notConnectedToInternet)))
        let model = env.model(homepage: try Self.homepage2(), youtube: youtube)

        await model.load()

        try Self.expectCondition2(model.state, video: .networkError)
        let c = try #require(Self.content(model.state))
        #expect(c.video.message == "인터넷 연결을 확인해 주세요")
        let expectedSermon = try Self.article("cast-body-11480").sermon
        #expect(c.article.sermon == expectedSermon)
        #expect(await youtube.requested.count == 1)
    }

    // AC-12 boundary: YouTube HTTP error (badStatus) is the same video-slot error, not a whole-screen error
    @Test func ac12_youtubeBadStatusIsVideoSlotNetworkError() async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        let model = env.model(homepage: try Self.homepage2(), youtube: FakeYouTube(.failure(YouTubeSearchError.badStatus(403))))

        await model.load()

        try Self.expectCondition2(model.state, video: .networkError)
    }

    // AC-13: no API key (nil or "") → YouTube never called, video slot "not found"
    @Test(arguments: [nil, ""] as [String?])
    func ac13_noAPIKeySkipsSearch(apiKey: String?) async throws {
        let env = try Env(2026, 11, 20, 13)
        defer { env.cleanup() }
        let youtube = try Self.youtube0713()
        let model = env.model(homepage: try Self.homepage2(), youtube: youtube, apiKey: apiKey)

        await model.load()

        #expect(await youtube.requested.count == 0)
        try Self.expectCondition2(model.state, video: .notFound)
    }

    // AC-20: no API key even when the article has an embed → "not found" (R-4), article kept
    @Test(arguments: [nil, ""] as [String?])
    func ac20_noAPIKeyIgnoresArticleEmbed(apiKey: String?) async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let youtube = try Self.youtube0713()
        let model = env.model(homepage: try Self.homepage1(), youtube: youtube, apiKey: apiKey)

        await model.load()

        try Self.expectCondition1(model.state, video: .notFound)
        let c = try #require(Self.content(model.state))
        #expect(c.video.message == "영상을 찾지 못했습니다")
        #expect(c.article.hymn == "454장 ‘주와 같이 되기를’")
        #expect(await youtube.requested.count == 0)
    }

    // MARK: - AC-18 midnight boundary

    // AC-18 ①: new finished on 11/20 → at 23:50 the same day, finished message, no requests
    @Test func ac18_beforeMidnightStillFinished() async throws {
        let env = try Env(2026, 11, 20, 23, 50)
        defer { env.cleanup() }
        env.store.markFinished(.newTestament, on: Self.date(2026, 11, 20))
        let homepage = try Self.homepage2()
        let model = env.model(homepage: homepage, youtube: try Self.youtube0713())

        await model.load()

        #expect(model.state == .finishedToday(.newTestament))
        #expect(model.state.message == "오늘 신약 묵상을 마쳤습니다")
        #expect(await homepage.requested.count == 0)
    }

    // AC-18 ②: after midnight (00:10 11/21) it is old testament on a new day → AC-1 content
    @Test func ac18_afterMidnightShowsMorningDevotion() async throws {
        let env = try Env(2026, 11, 20, 23, 50)
        defer { env.cleanup() }
        env.store.markFinished(.newTestament, on: Self.date(2026, 11, 20))
        try env.setTime(2026, 11, 21, 0, 10)
        let model = env.model(homepage: try Self.homepage1(), youtube: try Self.youtube0713())

        await model.load()

        try Self.expectCondition1(model.state)
    }

    // AC-18 boundary: a finished day of yesterday for the same testament does not block today
    @Test func ac18_yesterdayFinishedDoesNotBlock() async throws {
        let env = try Env(2026, 11, 21, 13)
        defer { env.cleanup() }
        env.store.markFinished(.newTestament, on: Self.date(2026, 11, 20))
        let model = env.model(homepage: try Self.homepage2(), youtube: try Self.youtube0713())

        await model.load()

        try Self.expectCondition2(model.state)
    }

    // MARK: - AC-21 refreshIfStale

    // AC-21 ①: same testament and day → state kept, no extra requests
    @Test func ac21_refreshSameSlotIsNoOp() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.homepage1()
        let model = env.model(homepage: homepage, youtube: try Self.youtube0713())
        await model.load()
        let before = model.state
        let count = await homepage.requested.count

        try env.setTime(2026, 11, 20, 8)
        await model.refreshIfStale()

        #expect(model.state == before)
        #expect(await homepage.requested.count == count)
    }

    // AC-21 ②: finished old in the morning, back at 13:00 → loads the new testament
    @Test func ac21_refreshAfterNoonLoadsNewTestament() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.homepage1()
        let model = env.model(homepage: homepage, youtube: try Self.youtube0713())
        await model.load()
        model.markSeen()
        #expect(model.state == .finishedToday(.oldTestament))

        try env.setTime(2026, 11, 20, 13)
        await homepage.setSearch("2020/07/12", .html(try Self.emptyPage()))
        await homepage.setSearch("2020/07/13", .html(try Self.html("cast-search-john-5")))
        await homepage.setArticle(11480, .html(try Self.html("cast-body-11480")))
        await model.refreshIfStale()

        try Self.expectCondition2(model.state)
    }

    // AC-21 ②-boundary: finished old, back later the same morning → stays finished, no requests
    @Test func ac21_refreshFinishedSameMorningIsNoOp() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.homepage1()
        let model = env.model(homepage: homepage, youtube: try Self.youtube0713())
        await model.load()
        model.markSeen()
        let count = await homepage.requested.count

        try env.setTime(2026, 11, 20, 11)
        await model.refreshIfStale()

        #expect(model.state == .finishedToday(.oldTestament))
        #expect(await homepage.requested.count == count)
    }

    // AC-21 ②-boundary: next morning (same testament, new day) → reloads and shows the following devotion
    @Test func ac21_refreshNextMorningReloads() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.homepage1()
        let model = env.model(homepage: homepage, youtube: try Self.youtube0713())
        await model.load()
        model.markSeen()

        try env.setTime(2026, 11, 21, 7)
        await homepage.setSearch("2025/09/12", .html(try Self.html("cast-search-date-20250912")))
        await homepage.setArticle(15157, .html(try Self.html("cast-body-15155")))
        await model.refreshIfStale()

        let c = try #require(Self.content(model.state))
        #expect(c.entry.date == Self.date(2025, 9, 12))
        #expect(c.entry.articleNo == 15157)
    }

    // AC-21 ③: network error state → refresh retries even at the same time
    @Test func ac21_refreshAfterNetworkErrorRetries() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = FakeHomepage(
            search: ["2025/09/11": .failure(URLError(.notConnectedToInternet))],
            article: [15155: .html(try Self.html("cast-body-15155"))],
            defaultSearch: try Self.emptyPage())
        let model = env.model(homepage: homepage, youtube: try Self.youtube0713())
        await model.load()
        #expect(model.state == .networkError)

        await homepage.setSearch("2025/09/11", .html(try Self.html("cast-search-proverbs-23")))
        await model.refreshIfStale()

        try Self.expectCondition1(model.state)
    }

    // AC-21 boundary: refresh while still .loading (never loaded) does nothing
    @Test func ac21_refreshWhileLoadingIsNoOp() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = try Self.homepage1()
        let model = env.model(homepage: homepage, youtube: try Self.youtube0713())

        await model.refreshIfStale()

        #expect(model.state == .loading)
        #expect(await homepage.requested.count == 0)
    }

    // MARK: - AC-22 messages

    // AC-22: screen-state messages
    @Test func ac22_screenStateMessages() {
        #expect(DevotionScreenState.finishedToday(.newTestament).message == "오늘 신약 묵상을 마쳤습니다")
        #expect(DevotionScreenState.finishedToday(.oldTestament).message == "오늘 구약 묵상을 마쳤습니다")
        #expect(DevotionScreenState.networkError.message == "인터넷 연결을 확인해 주세요")
        #expect(DevotionScreenState.noNextDevotion.message == "다음 묵상을 찾지 못했습니다")
        #expect(DevotionScreenState.loading.message == nil)
    }

    // AC-22: .showing has no message
    @Test func ac22_showingHasNoMessage() throws {
        let entry = try #require(DevotionTitleParser.parse("2020/07/13(월) “요한복음 5:30-47” / 작성: 박성호"))
        let content = DevotionScreenContent(
            testament: .newTestament,
            entry: entry,
            article: DevotionArticle(titleEntry: nil, passageText: "요한복음 5:30-47", hymn: nil, sermon: "s"),
            video: .notFound)
        #expect(DevotionScreenState.showing(content).message == nil)
    }

    // AC-22: video-slot messages
    @Test func ac22_videoSlotMessages() {
        #expect(VideoSlot.notFound.message == "영상을 찾지 못했습니다")
        #expect(VideoSlot.networkError.message == "인터넷 연결을 확인해 주세요")
        #expect(VideoSlot.video(id: "x").message == nil)
    }

    // MARK: - AC-24 markSeen outside .showing

    // AC-24: markSeen on a fresh model (.loading) does nothing
    @Test func ac24_markSeenWhileLoadingIsNoOp() throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let model = env.model(homepage: try Self.homepage1(), youtube: try Self.youtube0713())

        model.markSeen()

        #expect(model.state == .loading)
        #expect(env.rawSnapshot() == [nil, nil, nil, nil])
    }

    // AC-24: markSeen in .noNextDevotion does nothing
    @Test func ac24_markSeenWhenNoNextDevotionIsNoOp() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let model = env.model(homepage: FakeHomepage(defaultSearch: try Self.emptyPage()), youtube: try Self.youtube0713())
        await model.load()
        #expect(model.state == .noNextDevotion)

        model.markSeen()

        #expect(model.state == .noNextDevotion)
        Self.expectStoreUntouched(env)
    }

    // AC-24 boundary: markSeen in .networkError does nothing
    @Test func ac24_markSeenWhenNetworkErrorIsNoOp() async throws {
        let env = try Env(2026, 11, 20, 7)
        defer { env.cleanup() }
        let homepage = FakeHomepage(
            search: ["2025/09/11": .failure(URLError(.notConnectedToInternet))],
            defaultSearch: try Self.emptyPage())
        let model = env.model(homepage: homepage, youtube: try Self.youtube0713())
        await model.load()

        model.markSeen()

        #expect(model.state == .networkError)
        Self.expectStoreUntouched(env)
    }
}
