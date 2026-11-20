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
}
