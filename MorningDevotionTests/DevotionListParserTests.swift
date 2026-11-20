//
//  DevotionListParserTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

@MainActor
struct DevotionListParserTests {

    // MARK: - AC-6 entity decoding + author spacing variants

    // AC-6: no raw entity remains, "&#58;" decoded in passage and "작성&#58;"
    @Test func ac6_entitiesDecodedInJohnFixture() throws {
        let html = try FixtureLoader.html("cast-search-john-5")
        let titles = DevotionListParser.extractTitles(fromHTML: html)

        #expect(titles.count == 9)
        #expect(titles.filter { $0.contains("&") }.isEmpty)
        #expect(titles[6] == "2010/07/08(목) \"요한복음 5:30-47\"/ 작성: 이영란")
        #expect(titles[7] == "2010/07/07(수) \"요한복음 5:19-29\" / 작성:김순식")

        let entries = titles.compactMap(DevotionTitleParser.parse)
        let e0708 = try #require(entries.first { $0.date == DevotionDate(year: 2010, month: 7, day: 8) })
        #expect(e0708.passageText == "요한복음 5:30-47")
        #expect(e0708.author == "이영란")

        let e0707 = try #require(entries.first { $0.date == DevotionDate(year: 2010, month: 7, day: 7) })
        #expect(e0707.author == "김순식")
        #expect(e0707.passageText == "요한복음 5:19-29")
    }

    // MARK: - AC-11 counts, order, menu exclusion

    // AC-11: parseEntries counts per fixture (isaiah 5 because decision 1 = yes)
    @Test(arguments: [
        ("cast-search-proverbs-23", 6),
        ("cast-search-john-5", 9),
        ("cast-list-latest", 9),
        ("cast-search-isaiah-19", 5),
    ])
    func ac11_entryCounts(fixture: String, expected: Int) throws {
        let html = try FixtureLoader.html(fixture)
        #expect(DevotionListParser.parseEntries(fromHTML: html).count == expected)
    }

    // AC-11: document order preserved (first and full date sequence)
    @Test func ac11_documentOrderPreserved() throws {
        let proverbs = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-proverbs-23"))
        let john = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-john-5"))
        let latest = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-list-latest"))
        let isaiah = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-isaiah-19"))

        #expect(proverbs.first?.date == DevotionDate(year: 2025, month: 9, day: 11))
        #expect(john.first?.date == DevotionDate(year: 2020, month: 7, day: 13))
        #expect(latest.first?.date == DevotionDate(year: 2026, month: 11, day: 20))
        #expect(isaiah.first?.date == DevotionDate(year: 2026, month: 1, day: 3))

        #expect(proverbs.map(\.date.description) == [
            "2025/09/11", "2025/09/10", "2025/09/09", "2018/12/10", "2013/11/25", "2008/12/24",
        ])
        #expect(isaiah.map(\.date.description) == [
            "2026/01/03", "2026/01/02", "2019/02/05", "2014/01/21", "2009/02/19",
        ])
        #expect(latest.map(\.date.description) == [
            "2026/11/20", "2026/11/19", "2026/11/18", "2026/11/17", "2026/11/16",
            "2026/11/14", "2026/11/13", "2026/11/12", "2026/11/11",
        ])
        #expect(latest.map(\.author) == [
            "김현욱", "이영란", "김완영", "이주영", "조광묵", "송주영", "이재호", "강요섭", "최정운",
        ])
    }

    // AC-11: menu links (no subjectColor) are not extracted
    @Test func ac11_menuLinksExcluded() throws {
        let html = try FixtureLoader.html("cast-search-john-5")
        #expect(html.contains("한국기독교100주년기념재단 연혁"))
        let titles = DevotionListParser.extractTitles(fromHTML: html)
        #expect(!titles.contains { $0.contains("연혁") })
        #expect(!titles.contains { $0.contains("교회정관") })
    }

    // MARK: - Boundaries beyond the listed criteria

    @Test func emptyHTMLYieldsNothing() {
        #expect(DevotionListParser.extractTitles(fromHTML: "").isEmpty)
        #expect(DevotionListParser.parseEntries(fromHTML: "").isEmpty)
        #expect(DevotionListParser.parseEntries(fromHTML: "<html><body><a href=x>메뉴</a></body></html>").isEmpty)
    }

    // extractTitles: trimmed, hex/named entities decoded, document order kept
    @Test func extractTitlesDecodesOtherEntitiesAndTrims() {
        let html = """
        <td><a href="a" class=subjectColor>  2026/11/21(토) &quot;잠언 1&#x3A;1-7&quot; / 작성&#58; 홍&amp;길동  </a></td>
        <td><a href="b" class=subjectColor> 2026/11/20(금) “잠언 1:8-19” / 작성: 김철수</a></td>
        """
        let titles = DevotionListParser.extractTitles(fromHTML: html)
        #expect(titles == [
            "2026/11/21(토) \"잠언 1:1-7\" / 작성: 홍&길동",
            "2026/11/20(금) “잠언 1:8-19” / 작성: 김철수",
        ])
    }

    // parseEntries drops undated titles but keeps the rest in order
    @Test func parseEntriesDropsUndatedTitles() {
        let html = """
        <a class=subjectColor> 공지사항</a>
        <a class=subjectColor> 2026/11/20(금) “잠언 1:8-19” / 작성: 김철수</a>
        <a class=subjectColor> 2026/11/21(토) “특별새벽기도회” / 작성: 홍길동</a>
        """
        let entries = DevotionListParser.parseEntries(fromHTML: html)
        #expect(entries.map(\.date) == [
            DevotionDate(year: 2026, month: 11, day: 20),
            DevotionDate(year: 2026, month: 11, day: 21),
        ])
        #expect(entries.last?.passage == nil)
    }

    // MARK: - M2 R-1 article number (AC-1 ~ AC-4)

    private static func entry(_ entries: [DevotionEntry], _ y: Int, _ m: Int, _ d: Int) throws -> DevotionEntry {
        try #require(entries.first { $0.date == DevotionDate(year: y, month: m, day: d) })
    }

    // AC-1: articleNo of the target entries in the list fixtures
    @Test func ac1_articleNoFromListFixtures() throws {
        let proverbs = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-proverbs-23"))
        let john = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-john-5"))

        #expect(try Self.entry(proverbs, 2025, 9, 11).articleNo == 15155)
        #expect(try Self.entry(john, 2020, 7, 13).articleNo == 11480)
        #expect(try Self.entry(john, 2015, 6, 22).articleNo == 7999)
    }

    // AC-1: proverbs top three keep their own numbers
    @Test func ac1_proverbsTopThreeArticleNos() throws {
        let proverbs = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-proverbs-23"))
        #expect(Array(proverbs.prefix(3)).map(\.articleNo) == [15155, 15148, 15146])
    }

    // AC-2: extractLinks matches extractTitles 1:1 on every M1 fixture; all numbers present
    @Test(arguments: [
        ("cast-search-proverbs-23", 6),
        ("cast-search-john-5", 9),
        ("cast-list-latest", 9),
        ("cast-search-isaiah-19", 5),
    ])
    func ac2_linksMatchTitlesOnFixtures(fixture: String, expected: Int) throws {
        let html = try FixtureLoader.html(fixture)
        let links = DevotionListParser.extractLinks(fromHTML: html)
        let titles = DevotionListParser.extractTitles(fromHTML: html)

        #expect(links.count == titles.count)
        #expect(links.count == expected)
        #expect(links.map(\.title) == titles)
        #expect(links.allSatisfy { $0.articleNo != nil })

        let entries = DevotionListParser.parseEntries(fromHTML: html)
        #expect(entries.count == expected)
        #expect(entries.allSatisfy { $0.articleNo != nil })
    }

    // AC-2: john-5 full article number sequence in document order
    @Test func ac2_johnArticleNoSequence() throws {
        let john = DevotionListParser.parseEntries(fromHTML: try FixtureLoader.html("cast-search-john-5"))
        #expect(john.map(\.articleNo) == [11480, 11477, 11475, 7999, 7996, 7995, 4905, 4904, 4903])
    }

    // AC-3 (a): link without no= → nil, title unchanged
    @Test func ac3a_linkWithoutNoIsNil() {
        let html = #"<a href="/home/board.php?board=cast" class=subjectColor> 2026/11/20(금) “잠언 1:8-19” / 작성: 김철수</a>"#
        let links = DevotionListParser.extractLinks(fromHTML: html)
        #expect(links == [DevotionListLink(title: "2026/11/20(금) “잠언 1:8-19” / 작성: 김철수", articleNo: nil)])
        #expect(DevotionListParser.parseEntries(fromHTML: html).map(\.articleNo) == [nil])
    }

    // AC-3 (b): HTML-escaped ampersand before no= is accepted
    @Test func ac3b_escapedAmpersandAccepted() {
        let html = #"<a href="/home/board.php?board=cast&amp;no=42&amp;body_only=y" class=subjectColor> 2026/11/20(금) “잠언 1:8-19” / 작성: 김철수</a>"#
        #expect(DevotionListParser.extractLinks(fromHTML: html).map(\.articleNo) == [42])
    }

    // AC-3 (c): "xno=" is not "no="
    @Test func ac3c_xnoIgnored() {
        let html = #"<a href="/home/board.php?xno=7&no=8" class=subjectColor> 2026/11/20(금) “잠언 1:8-19” / 작성: 김철수</a>"#
        #expect(DevotionListParser.extractLinks(fromHTML: html).map(\.articleNo) == [8])
    }

    // AC-3 (d): class before onclick/href, no= after class in the same tag
    @Test func ac3d_noAfterClassInSameTag() {
        let html = #"<a class=subjectColor onclick="SLB('/home/board.php?board=cast&command=body&no=77&body_only=y')" href="x"> 2026/11/20(금) “잠언 1:8-19” / 작성: 김철수</a>"#
        let links = DevotionListParser.extractLinks(fromHTML: html)
        #expect(links.map(\.articleNo) == [77])
        #expect(links.map(\.title) == ["2026/11/20(금) “잠언 1:8-19” / 작성: 김철수"])
    }

    // AC-3 (e): second link without no= does not inherit the first link's value
    @Test func ac3e_previousLinkValueDoesNotLeak() {
        let html = """
        <a href="?board=cast&no=5" class=subjectColor> 2026/11/20(금) “잠언 1:8-19” / 작성: 김철수</a>
        <a href="?board=cast" class=subjectColor> 2026/11/21(토) “잠언 1:20-33” / 작성: 홍길동</a>
        """
        #expect(DevotionListParser.extractLinks(fromHTML: html).map(\.articleNo) == [5, nil])
        #expect(DevotionListParser.parseEntries(fromHTML: html).map(\.articleNo) == [5, nil])
    }

    // AC-3 (f): pairing — dropped undated link's number must not shift into the next entry
    @Test func ac3f_articleNoStaysPairedWithItsTitle() {
        let html = """
        <a href="?no=1" class=subjectColor> 공지사항</a>
        <a href="?no=2" class=subjectColor> 2026/11/20(금) “잠언 1:8-19” / 작성: 김철수</a>
        <a href="?no=3" class=subjectColor> 2026/11/21(토) “특별새벽기도회” / 작성: 홍길동</a>
        """
        let links = DevotionListParser.extractLinks(fromHTML: html)
        #expect(links.count == 3)
        #expect(links.map(\.articleNo) == [1, 2, 3])
        #expect(links.map(\.title) == [
            "공지사항",
            "2026/11/20(금) “잠언 1:8-19” / 작성: 김철수",
            "2026/11/21(토) “특별새벽기도회” / 작성: 홍길동",
        ])
        #expect(DevotionListParser.extractTitles(fromHTML: html).count == 3)

        let entries = DevotionListParser.parseEntries(fromHTML: html)
        #expect(entries.count == 2)
        #expect(entries.map(\.articleNo) == [2, 3])
        #expect(entries.map(\.date) == [
            DevotionDate(year: 2026, month: 11, day: 20),
            DevotionDate(year: 2026, month: 11, day: 21),
        ])
        #expect(entries.map(\.author) == ["김철수", "홍길동"])
    }

    // AC-3 boundary: no= in an enclosing (non-<a>) tag or in the title text is not this link's number
    @Test func ac3_noOutsideTheOpeningTagIgnored() {
        let html = """
        <td data-x="?no=9"><a href="?board=cast" class=subjectColor> 2026/11/20(금) “잠언 1:8-19” / 작성: 김철수</a></td>
        <a href="?board=cast" class=subjectColor> ?no=10 공지</a>
        """
        #expect(DevotionListParser.extractLinks(fromHTML: html).map(\.articleNo) == [nil, nil])
    }

    // AC-3 boundary: only the first no= in the tag is used
    @Test func ac3_firstNoInTagWins() {
        let html = #"<a href="?no=11&back=list&no=12" class=subjectColor> 2026/11/20(금) “잠언 1:8-19” / 작성: 김철수</a>"#
        #expect(DevotionListParser.extractLinks(fromHTML: html).map(\.articleNo) == [11])
    }

    // AC-3 boundary: empty HTML → no links
    @Test func ac3_emptyHTMLHasNoLinks() {
        #expect(DevotionListParser.extractLinks(fromHTML: "").isEmpty)
    }

    // AC-3 boundary: decodeEntities is reachable (internal) and unchanged
    @Test func ac3_decodeEntitiesIsInternal() {
        #expect(DevotionListParser.decodeEntities("&quot;잠언 1&#58;1&#x3A;2&quot; &amp; &lt;b&gt;") == "\"잠언 1:1:2\" & <b>")
    }

    // MARK: - AC-4 M1 → M2 linkage through NextDevotionPicker

    private static func kst() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    // AC-4: pick result carries the article number
    @Test func ac4_pickCarriesArticleNo() throws {
        let calendar = Self.kst()
        let progress = ReadingProgress(
            lastSeenOld: DevotionDate(year: 2025, month: 9, day: 10),
            lastSeenNew: DevotionDate(year: 2020, month: 7, day: 11)
        )
        let morning = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 8, minute: 0)))
        let afternoon = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 13, minute: 0)))

        let old = NextDevotionPicker.pick(
            listHTML: try FixtureLoader.html("cast-search-proverbs-23"),
            progress: progress, now: morning, calendar: calendar
        )
        #expect(old.entry?.date == DevotionDate(year: 2025, month: 9, day: 11))
        #expect(old.entry?.articleNo == 15155)

        let new = NextDevotionPicker.pick(
            listHTML: try FixtureLoader.html("cast-search-john-5"),
            progress: progress, now: afternoon, calendar: calendar
        )
        #expect(new.entry?.date == DevotionDate(year: 2020, month: 7, day: 13))
        #expect(new.entry?.articleNo == 11480)
    }
}
