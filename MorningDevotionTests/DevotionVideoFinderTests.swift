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

    /// search.list-shaped JSON with the given (videoId, title) items, in order.
    private static func searchJSON(_ items: [(id: String, title: String)]) throws -> Data {
        let object: [String: Any] = [
            "items": items.map { ["id": ["videoId": $0.id], "snippet": ["title": $0.title]] }
        ]
        return try JSONSerialization.data(withJSONObject: object)
    }

    private static let entry0713 = "2020/07/13(월) “요한복음 5:30-47” / 작성: 박성호"
    private static let entry0913 = "2025/09/13(토) 잠언 24:11-22 / 작성: 윤지은"

    private static let sermon0913 = "[ 설교 | 새벽기도회 | 2025.9.13(토) ] 잠언 24:11-22 | 인도 윤지은"
    private static let live0913 = "[ 생방송 | 새벽기도회 | 2025.9.13(토) ] 잠언 24:11-22 | 인도 윤지은"

    private static let passage0913 = Passage(book: "잠언", chapter: 24, startVerse: 11, endChapter: 24, endVerse: 22)

    // MARK: - FR-2 searchQuery / searchURL

    // AC-81: query is the passage only — no date
    @Test func ac81_searchQueryIsPassageOnly() throws {
        let q2020 = DevotionVideoFinder.searchQuery(for: try Self.entry(Self.entry0713))
        #expect(q2020 == "요한복음 5:30-47")
        let q2025 = DevotionVideoFinder.searchQuery(for: try Self.entry(Self.entry0913))
        #expect(q2025 == "잠언 24:11-22")
        for q in [q2020, q2025] {
            #expect(!q.contains("/"))
            #expect(!q.contains("2020"))
            #expect(!q.contains("2025"))
        }
    }

    // AC-81 boundary: single-digit month/day entry → still just the passage (no zero-padded date)
    @Test func ac81_searchQuerySingleDigitDate() throws {
        let e = try Self.entry("2020/7/3(금) “요한복음 1:1-5” / 작성: 박성호")
        #expect(DevotionVideoFinder.searchQuery(for: e) == "요한복음 1:1-5")
    }

    // AC-81 boundary: unparsed passage → the normalized passageText as is
    @Test func ac81_searchQueryUnparsedPassage() throws {
        let e = try Self.entry("2020/07/13(월) 특별 새벽 묵상 / 작성: 박성호")
        #expect(e.passage == nil)
        #expect(DevotionVideoFinder.searchQuery(for: e) == e.passageText)
        #expect(DevotionVideoFinder.searchQuery(for: e) == "특별 새벽 묵상")
    }

    // AC-82: searchURL endpoint and decoded parameter values, in the designed order
    @Test func ac82_searchURLParameters() throws {
        let url = try #require(DevotionVideoFinder.searchURL(query: "요한복음 5:30-47", apiKey: "FAKE-KEY-123"))
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(comps.scheme == "https")
        #expect(comps.host == "www.googleapis.com")
        #expect(comps.path == "/youtube/v3/search")
        #expect(comps.queryItems?.map(\.name) == ["part", "channelId", "type", "maxResults", "q", "key"])
        #expect(Self.queryValue(url, "part") == "snippet")
        #expect(Self.queryValue(url, "channelId") == "UCSkjujMSzrh6nghHWTSvIJg")
        #expect(Self.queryValue(url, "type") == "video")
        #expect(Self.queryValue(url, "maxResults") == "5")
        #expect(Self.queryValue(url, "q") == "요한복음 5:30-47")
        #expect(Self.queryValue(url, "key") == "FAKE-KEY-123")
        #expect(DevotionVideoFinder.channelID == "UCSkjujMSzrh6nghHWTSvIJg")
    }

    // AC-83: the URL the searcher actually receives through findVideo (2020 and 2025 entries)
    @Test(arguments: [
        ("2020/07/13(월) “요한복음 5:30-47” / 작성: 박성호", "yt-search-20200713", "요한복음 5:30-47"),
        ("2025/09/13(토) 잠언 24:11-22 / 작성: 윤지은", "yt-search-20250913", "잠언 24:11-22"),
    ])
    func ac83_findVideoSendsDesignedURL(title: String, fixture: String, expectedQ: String) async throws {
        let searcher = FakeSearcher(.data(try Self.json(fixture)))
        _ = await DevotionVideoFinder.findVideo(
            for: try Self.entry(title), apiKey: "FAKE-KEY-123", using: searcher)

        let requested = await searcher.requested
        #expect(requested.count == 1)
        let url = try #require(requested.first)
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect("\(comps.scheme ?? "")://\(comps.host ?? "")\(comps.path)" == "https://www.googleapis.com/youtube/v3/search")
        #expect(comps.queryItems?.map(\.name) == ["part", "channelId", "type", "maxResults", "q", "key"])
        #expect(Self.queryValue(url, "channelId") == "UCSkjujMSzrh6nghHWTSvIJg")
        #expect(Self.queryValue(url, "type") == "video")
        #expect(Self.queryValue(url, "part") == "snippet")
        #expect(Self.queryValue(url, "maxResults") == "5")
        #expect(Self.queryValue(url, "q") == expectedQ)
        #expect(Self.queryValue(url, "key") == "FAKE-KEY-123")
    }

    // MARK: - FR-3 videoTitleEntry, 2025 form

    // AC-84: 2025 sermon title → date, weekday, passage
    @Test func ac84_videoTitleEntry2025Sermon() throws {
        let v = try #require(DevotionVideoFinder.videoTitleEntry(Self.sermon0913))
        #expect(v.date == DevotionDate(year: 2025, month: 9, day: 13))
        #expect(v.weekday == "토")
        #expect(v.passageText == "잠언 24:11-22")
        #expect(v.passage == Self.passage0913)
        // same result as the 2020-style title it is rewritten to (DESIGN 4-1 step 6)
        #expect(v == DevotionTitleParser.parse("2025/9/13(토) 잠언 24:11-22"))
    }

    // AC-85 (a): zero-padded date "2025.09.13" is the same date
    @Test func ac85a_zeroPaddedDate() throws {
        let v = try #require(DevotionVideoFinder.videoTitleEntry("[ 설교 | 새벽기도회 | 2025.09.13(토) ] 잠언 24:11-22 | 인도 윤지은"))
        #expect(v.date == DevotionDate(year: 2025, month: 9, day: 13))
        #expect(v.weekday == "토")
        #expect(v.passage == Self.passage0913)
    }

    // AC-85 (b): no "|" in the tail → whole tail is the passage
    @Test func ac85b_tailWithoutPipe() throws {
        let v = try #require(DevotionVideoFinder.videoTitleEntry("[ 설교 | 새벽기도회 | 2025.9.11(목) ] 잠언 23:24-35"))
        #expect(v.date == DevotionDate(year: 2025, month: 9, day: 11))
        #expect(v.weekday == "목")
        #expect(v.passageText == "잠언 23:24-35")
        #expect(v.passage == Passage(book: "잠언", chapter: 23, startVerse: 24, endChapter: 23, endVerse: 35))
    }

    // AC-85 (c): cross-chapter passage
    @Test func ac85c_crossChapter() throws {
        let v = try #require(DevotionVideoFinder.videoTitleEntry("[ 설교 | 새벽기도회 | 2025.9.20(토) ] 사도행전 26:24-27:26 | 인도 X"))
        #expect(v.date == DevotionDate(year: 2025, month: 9, day: 20))
        #expect(v.passage == Passage(book: "사도행전", chapter: 26, startVerse: 24, endChapter: 27, endVerse: 26))
    }

    // AC-85 (d): no spaces inside the brackets → same as AC-84
    @Test func ac85d_noSpacesInBrackets() throws {
        let tight = try #require(DevotionVideoFinder.videoTitleEntry("[설교|새벽기도회|2025.9.13(토)] 잠언 24:11-22"))
        let spaced = try #require(DevotionVideoFinder.videoTitleEntry(Self.sermon0913))
        #expect(tight == spaced)
        #expect(tight.date == DevotionDate(year: 2025, month: 9, day: 13))
        #expect(tight.weekday == "토")
        #expect(tight.passage == Self.passage0913)
    }

    // AC-85 (e): &quot; entities around the passage are decoded and stripped
    @Test func ac85e_entityQuotes() throws {
        let v = try #require(DevotionVideoFinder.videoTitleEntry("[ 설교 | 새벽기도회 | 2025.9.13(토) ] &quot;잠언 24:11-22&quot; | 인도 윤지은"))
        #expect(v.date == DevotionDate(year: 2025, month: 9, day: 13))
        #expect(v.passageText == "잠언 24:11-22")
        #expect(v.passage == Self.passage0913)
    }

    // AC-85 boundary: weekday is optional in the date cell → weekday nil, date/passage read
    @Test func ac85_dateWithoutWeekday() throws {
        let v = try #require(DevotionVideoFinder.videoTitleEntry("[ 설교 | 새벽기도회 | 2025.9.13 ] 잠언 24:11-22 | 인도 윤지은"))
        #expect(v.date == DevotionDate(year: 2025, month: 9, day: 13))
        #expect(v.weekday == nil)
        #expect(v.passage == Self.passage0913)
    }

    // AC-85 boundary: only the first "|" of the tail ends the passage
    @Test func ac85_tailWithSeveralPipes() throws {
        let v = try #require(DevotionVideoFinder.videoTitleEntry("[ 설교 | 새벽기도회 | 2025.9.13(토) ] 잠언 24:11-22 | 인도 윤지은 | 100주년기념교회"))
        #expect(v.passageText == "잠언 24:11-22")
        #expect(v.passage == Self.passage0913)
    }

    // AC-85 boundary: two cells (no middle cell) is enough; leading spaces before "[" are trimmed
    @Test func ac85_twoCellsAndLeadingSpaces() throws {
        let two = try #require(DevotionVideoFinder.videoTitleEntry("[ 설교 | 2025.9.13(토) ] 잠언 24:11-22 | 인도 윤지은"))
        #expect(two.date == DevotionDate(year: 2025, month: 9, day: 13))
        #expect(two.passage == Self.passage0913)

        let padded = try #require(DevotionVideoFinder.videoTitleEntry("   " + Self.sermon0913 + "  "))
        #expect(padded.date == DevotionDate(year: 2025, month: 9, day: 13))
        #expect(padded.passage == Self.passage0913)
    }

    // AC-85 boundary: the middle cell is not checked
    @Test func ac85_middleCellIgnored() throws {
        let v = try #require(DevotionVideoFinder.videoTitleEntry("[ 설교 | 주일예배 | 2025.9.13(토) ] 잠언 24:11-22 | 인도 윤지은"))
        #expect(v.date == DevotionDate(year: 2025, month: 9, day: 13))
        #expect(v.passage == Self.passage0913)
    }

    // AC-86: titles that are not sermon candidates → nil
    @Test(arguments: [
        "[ 생방송 | 새벽기도회 | 2025.9.13(토) ] 잠언 24:11-22 | 인도 윤지은",
        "[ 찬양 | 새벽기도회 | 2025.9.13(토) ] 잠언 24:11-22 | 인도 윤지은",
        "[ 설교 | 새벽기도회 | 2025.9.13(토) 잠언 24:11-22",
        "[ 설교 | 새벽기도회 ] 잠언 24:11-22",
        "[ 설교 | 새벽기도회 | 2025/9/13(토) ] 잠언 24:11-22 | 인도 윤지은",
    ])
    func ac86_notCandidateIsNil(title: String) {
        #expect(DevotionVideoFinder.videoTitleEntry(title) == nil)
    }

    // AC-86 boundary: first cell must be exactly "설교"; one cell only; impossible date → nil
    @Test(arguments: [
        "[ 설교영상 | 새벽기도회 | 2025.9.13(토) ] 잠언 24:11-22 | 인도 윤지은",
        "[ 설교 ] 잠언 24:11-22",
        "[ 2025.9.13(토) ] 잠언 24:11-22",
        "[ 설교 | 새벽기도회 | 2025.13.40(토) ] 잠언 24:11-22 | 인도 윤지은",
        "[ 설교 | 새벽기도회 | 2025.9.13(토) 기도회 ] 잠언 24:11-22",
        "[]",
        "[",
    ])
    func ac86_boundaryNotCandidateIsNil(title: String) {
        #expect(DevotionVideoFinder.videoTitleEntry(title) == nil)
    }

    // MARK: - FR-3 videoTitleEntry, 2020 form (unchanged)

    // AC-87: 2020-form titles still read as before
    @Test func ac87_videoTitleEntry2020Regression() throws {
        let a = try #require(DevotionVideoFinder.videoTitleEntry("2020/07/13(월) “요한복음 5:30-47” / 박성호"))
        #expect(a.date == DevotionDate(year: 2020, month: 7, day: 13))
        #expect(a.passage == Passage(book: "요한복음", chapter: 5, startVerse: 30, endChapter: 5, endVerse: 47))

        let b = try #require(DevotionVideoFinder.videoTitleEntry("2022/01/31(월) &quot;창세기 32:1-20&quot; / 김남빈"))
        #expect(b.date == DevotionDate(year: 2022, month: 1, day: 31))
        #expect(b.passage == Passage(book: "창세기", chapter: 32, startVerse: 1, endChapter: 32, endVerse: 20))
    }

    // AC-87 / AC-14 (a): curly quotes + "/ <author>" without "작성:" → date and passage parsed
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

    // MARK: - FR-4 pickVideoID

    // AC-88: 2025 fixture → same date & passage picks kH2QadelWio; other date or passage → nil
    @Test func ac88_pickVideoID2025Fixture() throws {
        let fixture = try Self.json("yt-search-20250913")
        #expect(try DevotionVideoFinder.pickVideoID(for: try Self.entry(Self.entry0913), searchResponse: fixture) == "kH2QadelWio")

        let otherDate = try Self.entry("2025/09/12(금) 잠언 24:11-22 / 작성: 윤지은")
        #expect(try DevotionVideoFinder.pickVideoID(for: otherDate, searchResponse: fixture) == nil)

        let otherPassage = try Self.entry("2025/09/13(토) 잠언 24:1-10 / 작성: 윤지은")
        #expect(try DevotionVideoFinder.pickVideoID(for: otherPassage, searchResponse: fixture) == nil)
    }

    // AC-88 boundary: passage-only search mixes years — the same passage from another year is skipped
    @Test func ac88_otherYearSamePassageSkipped() throws {
        let data = try Self.searchJSON([
            ("OLDYEAR", "[ 설교 | 새벽기도회 | 2024.9.13(금) ] 잠언 24:11-22 | 인도 X"),
            ("OLD2020", "2020/09/13(일) “잠언 24:11-22” / 박성호"),
            ("RIGHT", Self.sermon0913),
        ])
        #expect(try DevotionVideoFinder.pickVideoID(for: try Self.entry(Self.entry0913), searchResponse: data) == "RIGHT")
    }

    // AC-88 boundary: 2020 and 2025 forms in one response — each entry finds its own video
    @Test func ac88_mixedFormsInOneResponse() throws {
        let data = try Self.searchJSON([
            ("SERMON2025", Self.sermon0913),
            ("SERMON2020", "2020/07/13(월) “요한복음 5:30-47” / 박성호"),
        ])
        #expect(try DevotionVideoFinder.pickVideoID(for: try Self.entry(Self.entry0913), searchResponse: data) == "SERMON2025")
        #expect(try DevotionVideoFinder.pickVideoID(for: try Self.entry(Self.entry0713), searchResponse: data) == "SERMON2020")
    }

    // AC-88 boundary: sermon title with an empty tail never matches a real devotion
    @Test func ac88_emptyTailDoesNotMatch() throws {
        let data = try Self.searchJSON([("EMPTY", "[ 설교 | 새벽기도회 | 2025.9.13(토) ]")])
        #expect(try DevotionVideoFinder.pickVideoID(for: try Self.entry(Self.entry0913), searchResponse: data) == nil)
    }

    // AC-88 boundary: two matching sermon items → the first in response order
    @Test func ac88_firstSermonMatchWins() throws {
        let data = try Self.searchJSON([
            ("FIRST", Self.sermon0913),
            ("SECOND", "[설교|새벽기도회|2025.09.13(토)] 잠언 24:11-22"),
        ])
        #expect(try DevotionVideoFinder.pickVideoID(for: try Self.entry(Self.entry0913), searchResponse: data) == "FIRST")
    }

    // AC-89: a live-stream item is skipped even when it comes first and matches date & passage
    @Test func ac89_liveStreamIsSkipped() throws {
        let e = try Self.entry(Self.entry0913)
        let both = try Self.searchJSON([("LIVE", Self.live0913), ("SERMON", Self.sermon0913)])
        #expect(try DevotionVideoFinder.pickVideoID(for: e, searchResponse: both) == "SERMON")

        let liveOnly = try Self.searchJSON([("LIVE", Self.live0913)])
        #expect(try DevotionVideoFinder.pickVideoID(for: e, searchResponse: liveOnly) == nil)
    }

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

    // MARK: - FR-1 / FR-5 findVideo (always searches)

    // AC-90: findVideo results for the 2025 and 2020 fixtures, one request each
    @Test(arguments: [
        ("2025/09/13(토) 잠언 24:11-22 / 작성: 윤지은", "yt-search-20250913", "kH2QadelWio"),
        ("2020/07/13(월) “요한복음 5:30-47” / 작성: 박성호", "yt-search-20200713", "M5VtIg1WAic"),
        ("2020/07/14(화) “요한복음 6:1-21” / 작성: 최현준", "yt-search-20200714", "qQf9Zh5ErEg"),
    ])
    func ac90_findVideoFound(title: String, fixture: String, expectedID: String) async throws {
        let searcher = FakeSearcher(.data(try Self.json(fixture)))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(title), apiKey: "k", using: searcher)
        #expect(result == .found(videoID: expectedID))
        #expect(await searcher.requested.count == 1)
    }

    // AC-90 / AC-91: a response with only a live stream → notFound (not searchFailed), one request
    @Test func ac90_findVideoLiveOnlyIsNotFound() async throws {
        let searcher = FakeSearcher(.data(try Self.searchJSON([("LIVE", Self.live0913)])))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0913), apiKey: "k", using: searcher)
        #expect(result == .notFound)
        #expect(result != .searchFailed)
        #expect(result != .found(videoID: "LIVE"))
        #expect(await searcher.requested.count == 1)
    }

    // AC-91: URLError on the 2025 entry → searchFailed (≠ notFound)
    @Test func ac91_urlErrorIsSearchFailed() async throws {
        let searcher = FakeSearcher(.failure(URLError(.timedOut)))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0913), apiKey: "k", using: searcher)
        #expect(result == .searchFailed)
        #expect(result != .notFound)
        #expect(await searcher.requested.count == 1)
    }

    // AC-6: same passage, different date → notFound
    @Test func ac6_findVideoDateMismatchIsNotFound() async throws {
        let searcher = FakeSearcher(.data(try Self.json("yt-search-20200714")))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry("2020/07/15(수) “요한복음 6:1-21” / 작성: 최현준"),
            apiKey: "k", using: searcher)
        #expect(result == .notFound)
    }

    // AC-7: title with &quot; entities matches after decoding (2nd item, not the 1st)
    @Test func ac7_findVideoMatchesEntityTitle() async throws {
        let searcher = FakeSearcher(.data(try Self.json("yt-search-20200713")))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry("2020/04/14(화) “누가복음 5:1-16” / 작성: 박성호"),
            apiKey: "k", using: searcher)
        #expect(result == .found(videoID: "umexnm87HjA"))
    }

    // AC-8: date-only match (Wednesday Bible study) is not picked
    @Test func ac8_findVideoIgnoresDateOnlyMatch() async throws {
        let searcher = FakeSearcher(.data(try Self.json("yt-search-20200713")))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry("2020/04/29(수) “민수기 1:2-10” / 작성: 박성호"),
            apiKey: "k", using: searcher)
        #expect(result == .notFound)
    }

    // AC-91 / AC-10 (a)(e): network error → searchFailed (≠ notFound)
    @Test func ac10a_networkErrorIsSearchFailed() async throws {
        let searcher = FakeSearcher(.failure(URLError(.notConnectedToInternet)))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0713), apiKey: "k", using: searcher)
        #expect(result == .searchFailed)
        #expect(result != .notFound)
        #expect(await searcher.requested.count == 1)
    }

    // AC-91 / AC-10 (b)(e): HTTP error from the fetcher → searchFailed
    @Test func ac10b_badStatusIsSearchFailed() async throws {
        let searcher = FakeSearcher(.failure(YouTubeSearchError.badStatus(403)))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0713), apiKey: "k", using: searcher)
        #expect(result == .searchFailed)
        #expect(result != .notFound)
    }

    // AC-91 / AC-10 (c)(e): non-JSON body → searchFailed
    @Test func ac10c_notJSONIsSearchFailed() async throws {
        let searcher = FakeSearcher(.data(Data("not json".utf8)))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0713), apiKey: "k", using: searcher)
        #expect(result == .searchFailed)
        #expect(result != .notFound)
    }

    // AC-91 / AC-10 (d)(e): JSON without items → searchFailed
    @Test func ac10d_missingItemsIsSearchFailed() async throws {
        let searcher = FakeSearcher(.data(Data(#"{"kind":"x"}"#.utf8)))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0713), apiKey: "k", using: searcher)
        #expect(result == .searchFailed)
        #expect(result != .notFound)
    }

    // AC-91 / AC-10 boundary: empty items list is a valid "no match" → notFound, not searchFailed
    @Test func ac10_emptyItemsIsNotFound() async throws {
        let searcher = FakeSearcher(.data(Data(#"{"items":[]}"#.utf8)))
        let result = await DevotionVideoFinder.findVideo(
            for: try Self.entry(Self.entry0713), apiKey: "k", using: searcher)
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
