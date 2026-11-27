//
//  BiblePassageLoaderTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

/// Fake bskorea site: reply chosen by `chap=` query, every request URL recorded. No network.
private actor FakeBible: DevotionHTMLFetching {
    enum Reply: Sendable {
        case html(String)
        case failure(any Error)
    }

    private let chapters: [Int: Reply]
    private(set) var requested: [URL] = []

    init(_ chapters: [Int: Reply]) { self.chapters = chapters }

    func fetchHTML(from url: URL) async throws -> String {
        requested.append(url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let chapText = items.first(where: { $0.name == "chap" })?.value,
              let chap = Int(chapText),
              let reply = chapters[chap]
        else { throw URLError(.fileDoesNotExist) }
        switch reply {
        case .html(let html): return html
        case .failure(let error): throw error
        }
    }
}

struct BiblePassageLoaderTests {

    // MARK: - Helpers

    private static func pro23() throws -> String { try FixtureLoader.html("bskorea-GAE-pro-23") }
    private static func jhn5() throws -> String { try FixtureLoader.html("bskorea-GAE-jhn-5") }

    private static func p(_ book: String, _ c: Int, _ s: Int, _ ec: Int, _ e: Int) -> Passage {
        Passage(book: book, chapter: c, startVerse: s, endChapter: ec, endVerse: e)
    }

    /// Synthetic chapter: verses 1…count, text "v<n>".
    private static func syn(_ count: Int) -> [BibleVerse] {
        (1...count).map { BibleVerse(number: $0, text: "v\($0)") }
    }

    /// 23 = 1…35, 24 = 1…34, 25 = 1…29, 26 = 1…28 (DESIGN AC-7).
    private static let synChapters: [Int: [BibleVerse]] = [23: syn(35), 24: syn(34), 25: syn(29), 26: syn(28)]

    /// (chapter, first verse, last verse, count) per section.
    private static func shape(_ sections: [BibleChapterSection]?) -> [[Int]]? {
        sections?.map { s in [s.chapter, s.verses.first?.number ?? -1, s.verses.last?.number ?? -1, s.verses.count] }
    }

    private static func query(_ url: URL, _ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == name })?.value
    }

    private static func chaps(_ urls: [URL]) -> [String] {
        urls.map { "chap=\(query($0, "chap") ?? "?")" }
    }

    // MARK: - AC-6 single chapter slice

    // F-9 AC-6: Proverbs 23:24-35 from the parsed fixture → one section, 12 verses 24…35
    @Test func ac6_singleChapterProverbs() throws {
        let verses = BibleChapterParser.parse(html: try Self.pro23())
        let r = try #require(BiblePassageSlicer.slice(Self.p("잠언", 23, 24, 23, 35), chapters: [23: verses]))
        #expect(Self.shape(r) == [[23, 24, 35, 12]])
        let nums = r[0].verses.map(\.number)
        #expect(nums == Array(24...35))
        #expect(!nums.contains(23))
        #expect(!nums.contains(36))
        #expect(r[0].verses.first(where: { $0.number == 25 })?.text == "네 부모를 즐겁게 하며 너를 낳은 어미를 기쁘게 하라")
        // verses are taken unchanged from the parsed page
        #expect(r[0].verses == verses.filter { (24...35).contains($0.number) })
    }

    // F-9 AC-6: John 5:30-47 → one section, 18 verses 30…47
    @Test func ac6_singleChapterJohn() throws {
        let verses = BibleChapterParser.parse(html: try Self.jhn5())
        let r = try #require(BiblePassageSlicer.slice(Self.p("요한복음", 5, 30, 5, 47), chapters: [5: verses]))
        #expect(Self.shape(r) == [[5, 30, 47, 18]])
        #expect(r[0].verses.map(\.number) == Array(30...47))
        #expect(r[0].verses.first(where: { $0.number == 31 })?.text.contains("증언하면") == true)
    }

    // F-9 AC-6 boundary: a single-verse range
    @Test func ac6_singleVerse() throws {
        let r = BiblePassageSlicer.slice(Self.p("잠언", 23, 7, 23, 7), chapters: Self.synChapters)
        #expect(r == [BibleChapterSection(chapter: 23, verses: [BibleVerse(number: 7, text: "v7")])])
    }

    // MARK: - AC-7 multi chapter slice

    // F-9 AC-7: two chapters 23:30-24:3
    @Test func ac7_twoChapters() throws {
        let r = BiblePassageSlicer.slice(Self.p("잠언", 23, 30, 24, 3), chapters: Self.synChapters)
        #expect(Self.shape(r) == [[23, 30, 35, 6], [24, 1, 3, 3]])
        #expect(r?[0].verses.map(\.number) == Array(30...35))
        #expect(r?[1].verses.map(\.text) == ["v1", "v2", "v3"])
    }

    // F-9 AC-7: three chapters 23:30-25:3 — the middle chapter is taken whole (1…34)
    @Test func ac7_threeChaptersMiddleWhole() throws {
        let r = BiblePassageSlicer.slice(Self.p("잠언", 23, 30, 25, 3), chapters: Self.synChapters)
        #expect(Self.shape(r) == [[23, 30, 35, 6], [24, 1, 34, 34], [25, 1, 3, 3]])
        #expect(r?[1].verses == Self.syn(34))
    }

    // F-9 AC-7: four chapters 23:30-26:2
    @Test func ac7_fourChapters() throws {
        let r = BiblePassageSlicer.slice(Self.p("잠언", 23, 30, 26, 2), chapters: Self.synChapters)
        #expect(Self.shape(r) == [[23, 30, 35, 6], [24, 1, 34, 34], [25, 1, 29, 29], [26, 1, 2, 2]])
    }

    // F-9 AC-7: chapter header shown for every section after the first
    @Test func ac7_chapterHeaders() throws {
        let sections = try #require(BiblePassageSlicer.slice(Self.p("잠언", 23, 30, 25, 3), chapters: Self.synChapters))
        let text = BiblePassageText(title: "잠언 23:30-25:3", sections: sections)
        #expect(text.showsChapterHeader(at: 0) == false)
        #expect(text.showsChapterHeader(at: 1) == true)
        #expect(text.showsChapterHeader(at: 2) == true)
        let single = BiblePassageText(title: "잠언 23:24-35",
                                      sections: [BibleChapterSection(chapter: 23, verses: Self.syn(3))])
        #expect(single.showsChapterHeader(at: 0) == false)
    }

    // MARK: - AC-8 slice failures

    // F-9 AC-8: every rule-breaking input → nil (9 cases from probe v4)
    @Test func ac8_sliceFailures() {
        let s = Self.synChapters
        // end verse past the chapter
        #expect(BiblePassageSlicer.slice(Self.p("잠언", 23, 30, 23, 36), chapters: [23: s[23]!]) == nil)
        // start verse past the chapter
        #expect(BiblePassageSlicer.slice(Self.p("잠언", 23, 40, 23, 45), chapters: [23: s[23]!]) == nil)
        // later chapter missing
        #expect(BiblePassageSlicer.slice(Self.p("잠언", 23, 30, 24, 3), chapters: [23: s[23]!]) == nil)
        // empty chapter
        #expect(BiblePassageSlicer.slice(Self.p("잠언", 23, 24, 23, 35), chapters: [23: []]) == nil)
        // empty first chapter across chapters
        #expect(BiblePassageSlicer.slice(Self.p("잠언", 23, 30, 24, 3), chapters: [23: [], 24: s[24]!]) == nil)
        // endChapter < chapter
        #expect(BiblePassageSlicer.slice(Self.p("잠언", 24, 1, 23, 3), chapters: [23: s[23]!, 24: s[24]!]) == nil)
        // three chapters, middle missing
        #expect(BiblePassageSlicer.slice(Self.p("잠언", 23, 30, 25, 3), chapters: [23: s[23]!, 25: s[25]!]) == nil)
        // three chapters, middle empty
        #expect(BiblePassageSlicer.slice(Self.p("잠언", 23, 30, 25, 3), chapters: [23: s[23]!, 24: [], 25: s[25]!]) == nil)
        // three chapters, end verse past the last chapter
        #expect(BiblePassageSlicer.slice(Self.p("잠언", 23, 30, 25, 40), chapters: s) == nil)
    }

    // F-9 AC-8 boundary: a gap where startVerse should be (first verse found is not startVerse) → nil
    @Test func ac8_startVerseMissingFromPage() {
        let gapped = Self.syn(35).filter { $0.number != 24 }
        #expect(BiblePassageSlicer.slice(Self.p("잠언", 23, 24, 23, 35), chapters: [23: gapped]) == nil)
        let noEnd = Self.syn(35).filter { $0.number != 35 }
        #expect(BiblePassageSlicer.slice(Self.p("잠언", 23, 24, 23, 35), chapters: [23: noEnd]) == nil)
    }

    // MARK: - AC-9 … AC-12 loader

    // F-9 AC-9: single chapter → one request to the AC-2 URL; title kept
    @Test func ac9_loadSingleChapter() async throws {
        let bible = FakeBible([23: .html(try Self.pro23())])
        let r = try #require(await BiblePassageLoader.load(Self.p("잠언", 23, 24, 23, 35),
                                                           title: "잠언 23:24-35", using: bible))
        #expect(r.title == "잠언 23:24-35")
        let expected = BiblePassageSlicer.slice(Self.p("잠언", 23, 24, 23, 35),
                                                chapters: [23: BibleChapterParser.parse(html: try Self.pro23())])
        #expect(r.sections == expected)
        #expect(Self.shape(r.sections) == [[23, 24, 35, 12]])
        let requested = await bible.requested
        #expect(requested.count == 1)
        #expect(requested.first?.absoluteString
            == "https://www.bskorea.or.kr/bible/korbibReadpage.php?version=GAE&book=pro&chap=23")
    }

    // F-9 AC-9: fetch errors and unparseable pages → nil
    @Test(arguments: [0, 1, 2])
    func ac9_loadFailures(kind: Int) async throws {
        let reply: FakeBible.Reply
        switch kind {
        case 0: reply = .failure(URLError(.notConnectedToInternet))
        case 1: reply = .failure(DevotionLoadError.badStatus(500))
        default: reply = .html("<html></html>")
        }
        let bible = FakeBible([23: reply])
        let r = await BiblePassageLoader.load(Self.p("잠언", 23, 24, 23, 35), title: "잠언 23:24-35", using: bible)
        #expect(r == nil)
        #expect(await bible.requested.count == 1)
    }

    // F-9 AC-10: two chapters, requested in order 23 → 24
    @Test func ac10_loadTwoChapters() async throws {
        let bible = FakeBible([23: .html(try Self.pro23()), 24: .html(try Self.jhn5())])
        let r = try #require(await BiblePassageLoader.load(Self.p("잠언", 23, 30, 24, 3),
                                                           title: "잠언 23:30-24:3", using: bible))
        #expect(r.title == "잠언 23:30-24:3")
        #expect(Self.shape(r.sections) == [[23, 30, 35, 6], [24, 1, 3, 3]])
        let requested = await bible.requested
        #expect(Self.chaps(requested) == ["chap=23", "chap=24"])
        #expect(requested.map { Self.query($0, "book") } == ["pro", "pro"])
        #expect(requested.map { Self.query($0, "version") } == ["GAE", "GAE"])
    }

    // F-9 AC-10: second chapter request throws → nil
    @Test func ac10_loadTwoChaptersSecondFails() async throws {
        let bible = FakeBible([23: .html(try Self.pro23()), 24: .failure(URLError(.notConnectedToInternet))])
        let r = await BiblePassageLoader.load(Self.p("잠언", 23, 30, 24, 3), title: "잠언 23:30-24:3", using: bible)
        #expect(r == nil)
        #expect(Self.chaps(await bible.requested) == ["chap=23", "chap=24"])
    }

    // F-9 AC-10: three chapters → exactly 3 requests 23, 24, 25; middle chapter whole (1…47)
    @Test func ac10_loadThreeChapters() async throws {
        let bible = FakeBible([23: .html(try Self.pro23()), 24: .html(try Self.jhn5()), 25: .html(try Self.pro23())])
        let r = try #require(await BiblePassageLoader.load(Self.p("잠언", 23, 30, 25, 3),
                                                           title: "잠언 23:30-25:3", using: bible))
        #expect(Self.shape(r.sections) == [[23, 30, 35, 6], [24, 1, 47, 47], [25, 1, 3, 3]])
        #expect(Self.chaps(await bible.requested) == ["chap=23", "chap=24", "chap=25"])
        #expect(r.showsChapterHeader(at: 0) == false)
        #expect(r.showsChapterHeader(at: 1) == true)
        #expect(r.showsChapterHeader(at: 2) == true)
    }

    // F-9 AC-10: middle chapter fails → nil, chapter 25 is never requested
    @Test func ac10_loadThreeChaptersStopsAtFirstFailure() async throws {
        let bible = FakeBible([23: .html(try Self.pro23()),
                               24: .failure(URLError(.notConnectedToInternet)),
                               25: .html(try Self.pro23())])
        let r = await BiblePassageLoader.load(Self.p("잠언", 23, 30, 25, 3), title: "잠언 23:30-25:3", using: bible)
        #expect(r == nil)
        #expect(Self.chaps(await bible.requested) == ["chap=23", "chap=24"])
    }

    // F-9 AC-11: unknown book code → nil with no request
    @Test func ac11_unknownBookNoRequest() async throws {
        let bible = FakeBible([23: .html(try Self.pro23())])
        let r = await BiblePassageLoader.load(Self.p("고린도전", 23, 24, 23, 35), title: "고린도전 23:24-35", using: bible)
        #expect(r == nil)
        #expect(await bible.requested.isEmpty)
    }

    // F-9 AC-11: endChapter < chapter → nil with no request
    @Test func ac11_reversedChaptersNoRequest() async throws {
        let bible = FakeBible([23: .html(try Self.pro23()), 24: .html(try Self.jhn5())])
        let r = await BiblePassageLoader.load(Self.p("잠언", 24, 1, 23, 3), title: "잠언 24:1-23:3", using: bible)
        #expect(r == nil)
        #expect(await bible.requested.isEmpty)
    }

    // F-9 AC-12: end verse past the fetched chapter → nil after one request
    @Test func ac12_endVersePastChapter() async throws {
        let bible = FakeBible([23: .html(try Self.pro23())])
        let r = await BiblePassageLoader.load(Self.p("잠언", 23, 30, 23, 36), title: "잠언 23:30-36", using: bible)
        #expect(r == nil)
        #expect(Self.chaps(await bible.requested) == ["chap=23"])
    }
}
