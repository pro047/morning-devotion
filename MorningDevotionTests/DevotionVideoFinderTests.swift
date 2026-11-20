//
//  DevotionVideoFinderTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

/// Fake YouTube searcher: records requested URLs, returns fixed Data or throws a fixed error. No network.
private actor FakeSearcher: YouTubeSearchFetching {
    enum Reply: Sendable {
        case data(Data)
        case failure(any Error)
    }

    private let reply: Reply
    private(set) var requested: [URL] = []

    init(_ reply: Reply) {
        self.reply = reply
    }

    func fetchSearchResponse(from url: URL) async throws -> Data {
        requested.append(url)
        switch reply {
        case .data(let data): return data
        case .failure(let error): throw error
        }
    }
}

@MainActor
struct DevotionVideoFinderTests {

    // MARK: - Helpers

    private static func entry(_ title: String) throws -> DevotionEntry {
        try #require(DevotionTitleParser.parse(title))
    }

    private static func json(_ name: String) throws -> Data {
        try FixtureLoader.data(name, ext: "json")
    }

    private static func queryValue(_ url: URL?, _ name: String) -> String? {
        guard let url, let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        return comps.queryItems?.first(where: { $0.name == name })?.value
    }

    private static let entry0713 = "2020/07/13(월) “요한복음 5:30-47” / 작성: 박성호"

    // MARK: - R-1 videoID(inArticleHTML:)

    // AC-1: iframe embed that sits before the body div is found (whole-document search)
    @Test func ac1_videoIDFromIframe15155() throws {
        let html = try FixtureLoader.html("cast-body-15155")
        #expect(DevotionVideoFinder.videoID(inArticleHTML: html) == "PR9GK_S83NU")
    }

    // AC-2: <a href=".../embed/<id>"> link is found
    @Test func ac2_videoIDFromLink12602() throws {
        let html = try FixtureLoader.html("cast-body-12602")
        #expect(DevotionVideoFinder.videoID(inArticleHTML: html) == "UsCVP4y7snI")
    }

    // AC-3: article without any youtube embed → nil
    @Test func ac3_noVideoIn11480() throws {
        let html = try FixtureLoader.html("cast-body-11480")
        #expect(DevotionVideoFinder.videoID(inArticleHTML: html) == nil)
    }

    // AC-12: id charset includes '-' and '_'; '?' and '"' end the id
    @Test func ac12_videoIDCharset() {
        let withQuery = ##"<iframe src="https://www.youtube.com/embed/-rD7ZDYCysw?autoplay=1">"##
        #expect(DevotionVideoFinder.videoID(inArticleHTML: withQuery) == "-rD7ZDYCysw")

        let endsWithQuote = ##"<a href="https://www.youtube.com/embed/_2LlTBb4aDQ""##
        #expect(DevotionVideoFinder.videoID(inArticleHTML: endsWithQuote) == "_2LlTBb4aDQ")
    }

    // AC-12 boundary: empty document, empty id after "embed/", other youtube URL forms → nil
    @Test func ac12_videoIDBoundaries() {
        #expect(DevotionVideoFinder.videoID(inArticleHTML: "") == nil)
        #expect(DevotionVideoFinder.videoID(inArticleHTML: ##"<iframe src="https://www.youtube.com/embed/">"##) == nil)
        #expect(DevotionVideoFinder.videoID(inArticleHTML: ##"<a href="https://www.youtube.com/watch?v=abcDEF12345">"##) == nil)
    }

    // AC-12 boundary: two embeds → the first one in document order; '/' and '&' also end the id
    @Test func ac12_videoIDFirstMatchWins() {
        let html = ##"<a href="https://www.youtube.com/embed/FIRST_id-1/x">a</a><iframe src="https://www.youtube.com/embed/SECOND&x=1">"##
        #expect(DevotionVideoFinder.videoID(inArticleHTML: html) == "FIRST_id-1")

        let amp = ##"<iframe src="https://www.youtube.com/embed/AbC123&amp;rel=0">"##
        #expect(DevotionVideoFinder.videoID(inArticleHTML: amp) == "AbC123")
    }

    // MARK: - R-2 searchQuery / searchURL

    // AC-11: query is "<YYYY/MM/DD> <passageText>"
    @Test func ac11_searchQuery() throws {
        let e = try Self.entry(Self.entry0713)
        #expect(DevotionVideoFinder.searchQuery(for: e) == "2020/07/13 요한복음 5:30-47")
    }

    // AC-11 boundary: single-digit month/day are zero-padded (DevotionDate.description)
    @Test func ac11_searchQueryZeroPads() throws {
        let e = try Self.entry("2020/7/3(금) “요한복음 1:1-5” / 작성: 박성호")
        #expect(DevotionVideoFinder.searchQuery(for: e) == "2020/07/03 요한복음 1:1-5")
    }

    // AC-11: searchURL endpoint and decoded parameter values, in the designed order
    @Test func ac11_searchURLParameters() throws {
        let url = try #require(DevotionVideoFinder.searchURL(query: "2020/07/13 요한복음 5:30-47", apiKey: "FAKE-KEY-123"))
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(comps.scheme == "https")
        #expect(comps.host == "www.googleapis.com")
        #expect(comps.path == "/youtube/v3/search")
        #expect(comps.queryItems?.map(\.name) == ["part", "channelId", "type", "maxResults", "q", "key"])
        #expect(Self.queryValue(url, "part") == "snippet")
        #expect(Self.queryValue(url, "channelId") == "UCSkjujMSzrh6nghHWTSvIJg")
        #expect(Self.queryValue(url, "type") == "video")
        #expect(Self.queryValue(url, "maxResults") == "5")
        #expect(Self.queryValue(url, "q") == "2020/07/13 요한복음 5:30-47")
        #expect(Self.queryValue(url, "key") == "FAKE-KEY-123")
        #expect(DevotionVideoFinder.channelID == "UCSkjujMSzrh6nghHWTSvIJg")
    }

    // AC-11: the URL the searcher actually receives through findVideo
    @Test func ac11_findVideoSendsDesignedURL() async throws {
        let searcher = FakeSearcher(.data(try Self.json("yt-search-20200713")))
        _ = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0713), articleHTML: nil, apiKey: "FAKE-KEY-123", using: searcher)

        let requested = await searcher.requested
        #expect(requested.count == 1)
        let url = try #require(requested.first)
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect("\(comps.scheme ?? "")://\(comps.host ?? "")\(comps.path)" == "https://www.googleapis.com/youtube/v3/search")
        #expect(Self.queryValue(url, "channelId") == "UCSkjujMSzrh6nghHWTSvIJg")
        #expect(Self.queryValue(url, "type") == "video")
        #expect(Self.queryValue(url, "part") == "snippet")
        #expect(Self.queryValue(url, "maxResults") == "5")
        #expect(Self.queryValue(url, "q") == "2020/07/13 요한복음 5:30-47")
        #expect(Self.queryValue(url, "key") == "FAKE-KEY-123")
    }

    // MARK: - R-3 videoTitleEntry

    // AC-14 (a): curly quotes + "/ <author>" without "작성:" → date and passage parsed
    @Test func ac14a_videoTitleEntryCurlyQuotes() throws {
        let v = try #require(DevotionVideoFinder.videoTitleEntry("2020/07/13(월) “요한복음 5:30-47” / 박성호"))
        #expect(v.date == DevotionDate(year: 2020, month: 7, day: 13))
        #expect(v.passage == Passage(book: "요한복음", chapter: 5, startVerse: 30, endChapter: 5, endVerse: 47))
    }

    // AC-14 (b): &quot; entities are decoded before parsing
    @Test func ac14b_videoTitleEntryEntities() throws {
        let v = try #require(DevotionVideoFinder.videoTitleEntry("2020/04/14(화) &quot;누가복음 5:1-16&quot; / 박성호"))
        #expect(v.date == DevotionDate(year: 2020, month: 4, day: 14))
        #expect(v.passage == Passage(book: "누가복음", chapter: 5, startVerse: 1, endChapter: 5, endVerse: 16))
    }

    // AC-14 (c): no leading date → nil
    @Test func ac14c_videoTitleEntryNoDate() {
        #expect(DevotionVideoFinder.videoTitleEntry("수요성경공부") == nil)
        #expect(DevotionVideoFinder.videoTitleEntry("") == nil)
    }

    // AC-14 boundary: no "/" in the tail → tail kept as is (title without author still parses)
    @Test func ac14_videoTitleEntryWithoutAuthor() throws {
        let v = try #require(DevotionVideoFinder.videoTitleEntry("2020/07/14(화) “요한복음 6:1-21”"))
        #expect(v.date == DevotionDate(year: 2020, month: 7, day: 14))
        #expect(v.passage == Passage(book: "요한복음", chapter: 6, startVerse: 1, endChapter: 6, endVerse: 21))
    }

    // AC-14 boundary: Wednesday Bible-study title (no "/") → date read, passage nil
    @Test func ac14_videoTitleEntryBibleStudy() throws {
        let v = try #require(DevotionVideoFinder.videoTitleEntry("2020/04/29,  수요성경공부 민수기 1:1-54  &quot;민수기&quot; (설교: 박성호)"))
        #expect(v.date == DevotionDate(year: 2020, month: 4, day: 29))
        #expect(v.passage == nil)
    }

    // AC-14 boundary: cross-chapter passage in a video title
    @Test func ac14_videoTitleEntryCrossChapter() throws {
        let v = try #require(DevotionVideoFinder.videoTitleEntry("2020/11/10(화) “사도행전 26:24-27:26” / 박성호"))
        #expect(v.passage == Passage(book: "사도행전", chapter: 26, startVerse: 24, endChapter: 27, endVerse: 26))
    }

    // MARK: - R-3 pickVideoID

    // AC-13: straight quotes, '~', and a space before "(월)" still match
    @Test func ac13_pickVideoIDNotationDifferences() throws {
        let data = Data(#"{"items":[{"id":{"videoId":"AAA"},"snippet":{"title":"2020/07/13 (월) \"요한복음 5:30~47\" / 박성호"}}]}"#.utf8)
        let e = try Self.entry(Self.entry0713)
        #expect(try DevotionVideoFinder.pickVideoID(for: e, searchResponse: data) == "AAA")
    }

    // AC-15: items without id.videoId are skipped; empty items → nil (not a throw)
    @Test func ac15_pickVideoIDSkipsNonVideoItems() throws {
        let e = try Self.entry(Self.entry0713)
        let data = Data(#"{"items":[{"id":{"kind":"youtube#channel"},"snippet":{"title":"2020/07/13(월) “요한복음 5:30-47” / 박성호"}},{"id":{"videoId":"BBB"},"snippet":{"title":"2020/07/13(월) “요한복음 5:30-47” / 박성호"}}]}"#.utf8)
        #expect(try DevotionVideoFinder.pickVideoID(for: e, searchResponse: data) == "BBB")

        #expect(try DevotionVideoFinder.pickVideoID(for: e, searchResponse: Data(#"{"items":[]}"#.utf8)) == nil)
    }

    // AC-15 boundary: items without snippet or without title are skipped, not thrown
    @Test func ac15_pickVideoIDSkipsItemsWithoutTitle() throws {
        let e = try Self.entry(Self.entry0713)
        let data = Data(#"{"items":[{"id":{"videoId":"NOSNIP"}},{"id":{"videoId":"NOTITLE"},"snippet":{}},{"id":{"videoId":"CCC"},"snippet":{"title":"2020/07/13(월) “요한복음 5:30-47” / 박성호"}}]}"#.utf8)
        #expect(try DevotionVideoFinder.pickVideoID(for: e, searchResponse: data) == "CCC")
    }

    // AC-15 boundary: two matching items → the first in response order
    @Test func ac15_pickVideoIDFirstMatchWins() throws {
        let e = try Self.entry(Self.entry0713)
        let data = Data(#"{"items":[{"id":{"videoId":"FIRST"},"snippet":{"title":"2020/07/13(월) “요한복음 5:30-47” / 박성호"}},{"id":{"videoId":"SECOND"},"snippet":{"title":"2020/07/13(월) “요한복음 5:30-47” / 최현준"}}]}"#.utf8)
        #expect(try DevotionVideoFinder.pickVideoID(for: e, searchResponse: data) == "FIRST")
    }

    // AC-10 (pure part): malformed responses throw from pickVideoID
    @Test func ac10_pickVideoIDThrowsOnMalformed() throws {
        let e = try Self.entry(Self.entry0713)
        #expect(throws: (any Error).self) {
            try DevotionVideoFinder.pickVideoID(for: e, searchResponse: Data("not json".utf8))
        }
        #expect(throws: (any Error).self) {
            try DevotionVideoFinder.pickVideoID(for: e, searchResponse: Data(#"{"kind":"x"}"#.utf8))
        }
        #expect(throws: (any Error).self) {
            try DevotionVideoFinder.pickVideoID(for: e, searchResponse: Data())
        }
    }

    // AC-6 / AC-8 boundary (pure part): same date but different passage → nil; same passage, other date → nil
    @Test func ac8_pickVideoIDRequiresDateAndPassage() throws {
        let fixture = try Self.json("yt-search-20200713")
        let otherPassage = try Self.entry("2020/07/13(월) “요한복음 5:1-29” / 작성: 박성호")
        #expect(try DevotionVideoFinder.pickVideoID(for: otherPassage, searchResponse: fixture) == nil)

        let otherDate = try Self.entry("2021/07/13(화) “요한복음 5:30-47” / 작성: 박성호")
        #expect(try DevotionVideoFinder.pickVideoID(for: otherDate, searchResponse: fixture) == nil)
    }

    // AC-8 boundary: devotion whose passage could not be parsed does not match a video with a different text
    // (holds under either answer to the design's [결정] 1)
    @Test func ac8_unparsedPassageDoesNotMatchDifferentText() throws {
        let e = try Self.entry("2020/07/13(월) 특별 새벽 묵상 / 작성: 박성호")
        #expect(e.passage == nil)
        let fixture = try Self.json("yt-search-20200713")
        #expect(try DevotionVideoFinder.pickVideoID(for: e, searchResponse: fixture) == nil)
    }

    // MARK: - R-4 / R-5 findVideo

    // AC-4: article without video → search → same date & passage item (first of 5)
    @Test func ac4_findVideoSearchesWhenArticleHasNoVideo() async throws {
        let searcher = FakeSearcher(.data(try Self.json("yt-search-20200713")))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0713),
            articleHTML: try FixtureLoader.html("cast-body-11480"),
            apiKey: "k",
            using: searcher)
        #expect(result == .found(videoID: "M5VtIg1WAic"))
        #expect(await searcher.requested.count == 1)
    }

    // AC-5: articleHTML nil → search
    @Test func ac5_findVideoSearchesWhenArticleHTMLIsNil() async throws {
        let searcher = FakeSearcher(.data(try Self.json("yt-search-20200714")))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry("2020/07/14(화) “요한복음 6:1-21” / 작성: 최현준"),
            articleHTML: nil, apiKey: "k", using: searcher)
        #expect(result == .found(videoID: "qQf9Zh5ErEg"))
        #expect(await searcher.requested.count == 1)
    }

    // AC-6: same passage, different date → notFound
    @Test func ac6_findVideoDateMismatchIsNotFound() async throws {
        let searcher = FakeSearcher(.data(try Self.json("yt-search-20200714")))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry("2020/07/15(수) “요한복음 6:1-21” / 작성: 최현준"),
            articleHTML: nil, apiKey: "k", using: searcher)
        #expect(result == .notFound)
    }

    // AC-7: title with &quot; entities matches after decoding (2nd item, not the 1st)
    @Test func ac7_findVideoMatchesEntityTitle() async throws {
        let searcher = FakeSearcher(.data(try Self.json("yt-search-20200713")))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry("2020/04/14(화) “누가복음 5:1-16” / 작성: 박성호"),
            articleHTML: nil, apiKey: "k", using: searcher)
        #expect(result == .found(videoID: "umexnm87HjA"))
    }

    // AC-8: date-only match (Wednesday Bible study) is not picked
    @Test func ac8_findVideoIgnoresDateOnlyMatch() async throws {
        let searcher = FakeSearcher(.data(try Self.json("yt-search-20200713")))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry("2020/04/29(수) “민수기 1:2-10” / 작성: 박성호"),
            articleHTML: nil, apiKey: "k", using: searcher)
        #expect(result == .notFound)
    }

    // AC-9: article video wins and the searcher is never called (even when search would also match)
    @Test func ac9_findVideoPrefersArticleVideoWithoutSearching() async throws {
        let searcher = FakeSearcher(.data(try Self.json("yt-search-20200714")))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry("2020/07/14(화) “요한복음 6:1-21” / 작성: 최현준"),
            articleHTML: try FixtureLoader.html("cast-body-15155"),
            apiKey: "k",
            using: searcher)
        #expect(result == .found(videoID: "PR9GK_S83NU"))
        #expect(await searcher.requested.count == 0)
    }

    // AC-9 boundary: empty article HTML behaves like "no video" → search once
    @Test func ac9_emptyArticleHTMLFallsBackToSearch() async throws {
        let searcher = FakeSearcher(.data(try Self.json("yt-search-20200713")))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0713), articleHTML: "", apiKey: "k", using: searcher)
        #expect(result == .found(videoID: "M5VtIg1WAic"))
        #expect(await searcher.requested.count == 1)
    }

    // AC-10 (a)(e): network error → searchFailed (≠ notFound)
    @Test func ac10a_networkErrorIsSearchFailed() async throws {
        let searcher = FakeSearcher(.failure(URLError(.notConnectedToInternet)))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0713), articleHTML: nil, apiKey: "k", using: searcher)
        #expect(result == .searchFailed)
        #expect(result != .notFound)
        #expect(await searcher.requested.count == 1)
    }

    // AC-10 (b)(e): HTTP error from the fetcher → searchFailed
    @Test func ac10b_badStatusIsSearchFailed() async throws {
        let searcher = FakeSearcher(.failure(YouTubeSearchError.badStatus(403)))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0713), articleHTML: nil, apiKey: "k", using: searcher)
        #expect(result == .searchFailed)
        #expect(result != .notFound)
    }

    // AC-10 (c)(e): non-JSON body → searchFailed
    @Test func ac10c_notJSONIsSearchFailed() async throws {
        let searcher = FakeSearcher(.data(Data("not json".utf8)))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0713), articleHTML: nil, apiKey: "k", using: searcher)
        #expect(result == .searchFailed)
        #expect(result != .notFound)
    }

    // AC-10 (d)(e): JSON without items → searchFailed
    @Test func ac10d_missingItemsIsSearchFailed() async throws {
        let searcher = FakeSearcher(.data(Data(#"{"kind":"x"}"#.utf8)))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0713), articleHTML: nil, apiKey: "k", using: searcher)
        #expect(result == .searchFailed)
        #expect(result != .notFound)
    }

    // AC-10 boundary: empty items list is a valid "no match" → notFound, not searchFailed
    @Test func ac10_emptyItemsIsNotFound() async throws {
        let searcher = FakeSearcher(.data(Data(#"{"items":[]}"#.utf8)))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0713), articleHTML: nil, apiKey: "k", using: searcher)
        #expect(result == .notFound)
    }

    // MARK: - FixtureLoader

    // AC-16: html(_:) unchanged; data(_:ext:) reads JSON; missing name throws FixtureNotFound
    @Test func ac16_fixtureLoaderReadsHTMLAndJSON() throws {
        let html = try FixtureLoader.html("cast-body-15155")
        #expect(html.contains("youtube.com/embed/PR9GK_S83NU"))

        let data = try FixtureLoader.data("yt-search-20200713", ext: "json")
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let items = try #require(object["items"] as? [[String: Any]])
        #expect(items.count == 5)

        let text = try FixtureLoader.text("yt-search-20200714", ext: "json")
        #expect(text.contains("qQf9Zh5ErEg"))

        do {
            _ = try FixtureLoader.data("no-such-fixture", ext: "json")
            Issue.record("expected FixtureNotFound")
        } catch let error as FixtureNotFound {
            #expect(error.name == "no-such-fixture")
            #expect(error.ext == "json")
            #expect(error.description.contains("'no-such-fixture.json'"))
        }
    }
}
