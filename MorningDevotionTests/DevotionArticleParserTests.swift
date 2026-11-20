//
//  DevotionArticleParserTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

@MainActor
struct DevotionArticleParserTests {

    // MARK: - Helpers

    private static func article(_ fixture: String) throws -> DevotionArticle {
        try #require(DevotionArticleParser.parse(html: try FixtureLoader.html(fixture)))
    }

    private static func lines(_ sermon: String) -> [String] {
        sermon.components(separatedBy: "\n")
    }

    // MARK: - AC-6 cast-body-15155

    // AC-6: passage, hymn, sermon start/end, no tags left
    @Test func ac6_body15155() throws {
        let a = try Self.article("cast-body-15155")
        #expect(a.passageText == "잠언 23:24-35")
        #expect(a.hymn == "454장 ‘주와 같이 되기를’")
        #expect(a.sermon.hasPrefix("오늘 본문의 주제어는 크게 세 가지입니다."))
        #expect(a.sermon.hasSuffix("(작성: 김광욱)"))
        #expect(!a.sermon.contains("<"))
    }

    // MARK: - AC-7 cast-body-11480

    // AC-7: passage, hymn, sermon start/end, no tags left
    @Test func ac7_body11480() throws {
        let a = try Self.article("cast-body-11480")
        #expect(a.passageText == "요한복음 5:30-47")
        #expect(a.hymn == "90장 ‘주 예수 내가 알기 전’")
        #expect(a.sermon.hasPrefix("예루살렘 양문 곁 베데스다 못에서."))
        #expect(a.sermon.hasSuffix("(작성: 박성호)"))
        #expect(!a.sermon.contains("<"))
    }

    // MARK: - AC-8 line structure

    // AC-8: <br> becomes "\n", blank lines kept, source newlines removed
    @Test func ac8_lineStructure15155() throws {
        let a = try Self.article("cast-body-15155")
        #expect(a.sermon.contains("묵상해 보겠습니다.\n\n부모를 즐겁게 하는 길(24-25)\n\n24 의인의 아비는"))
    }

    // AC-8: no "\r", no line starting/ending with space or tab (both fixtures)
    @Test(arguments: ["cast-body-15155", "cast-body-11480"])
    func ac8_linesTrimmed(fixture: String) throws {
        let a = try Self.article(fixture)
        #expect(!a.sermon.contains("\r"))
        let bad = Self.lines(a.sermon).filter {
            $0.hasPrefix(" ") || $0.hasPrefix("\t") || $0.hasSuffix(" ") || $0.hasSuffix("\t")
        }
        #expect(bad.isEmpty)
    }

    // AC-8: 11480 nested </span></span> line stays one line; leading-space line is trimmed
    @Test func ac8_lines11480() throws {
        let lines = Self.lines(try Self.article("cast-body-11480").sermon)
        #expect(lines.contains("(47) 그러나 그의 글도 믿지 아니하거든 어찌 내 말을 믿겠느냐 하시니라"))
        #expect(lines.contains { $0.hasPrefix("예수님은 주관적 결정에 따라 심판하지 않고,") })
    }

    // MARK: - AC-9 out-of-scope content excluded

    // AC-9: no youtube iframe, no Cloudflare script, no hymn label/line in the sermon
    @Test(arguments: ["cast-body-15155", "cast-body-11480"])
    func ac9_outOfScopeExcluded(fixture: String) throws {
        let a = try Self.article(fixture)
        #expect(!a.sermon.contains("youtube"))
        #expect(!a.sermon.contains("__CF$cv$params"))
        #expect(!a.sermon.contains("찬송가"))
        #expect(Self.lines(a.sermon).first != a.passageText)
        #expect(!(Self.lines(a.sermon).first ?? "").contains(a.passageText))
    }

    // AC-9: hymn text itself not in the sermon
    @Test func ac9_hymnTextNotInSermon() throws {
        let a15155 = try Self.article("cast-body-15155")
        let a11480 = try Self.article("cast-body-11480")
        #expect(!a15155.sermon.contains("454장"))
        #expect(!a11480.sermon.contains("90장 ‘"))
    }

    // MARK: - AC-10 <TITLE>

    // AC-10: titleEntry parsed from <TITLE>
    @Test func ac10_titleEntry() throws {
        let t1 = try #require(try Self.article("cast-body-15155").titleEntry)
        #expect(t1.date == DevotionDate(year: 2025, month: 9, day: 11))
        #expect(t1.author == "김광욱")
        #expect(t1.passageText == "잠언 23:24-35")
        #expect(t1.articleNo == nil)

        let t2 = try #require(try Self.article("cast-body-11480").titleEntry)
        #expect(t2.date == DevotionDate(year: 2020, month: 7, day: 13))
        #expect(t2.author == "박성호")
    }

    // MARK: - AC-11 entities and order

    // AC-11: entities decoded in passage/hymn/sermon; tags removed before decoding
    @Test func ac11_entitiesAndOrder() throws {
        let html = "<title>x</title><div style='margin:60px;'><span>본문</span> 잠언 1&#58;1-7<br /><span>찬송가</span> 1장 &quot;만복&quot;<br />가 &amp; 나<BR>다 &lt;b&gt;</div>"
        let a = try #require(DevotionArticleParser.parse(html: html))
        #expect(a.passageText == "잠언 1:1-7")
        #expect(a.hymn == "1장 \"만복\"")
        #expect(a.sermon == "가 & 나\n다 <b>")
        #expect(a.titleEntry == nil)
    }

    // AC-11 boundary: <TITLE> is case-insensitive and entity-decoded before title parsing
    @Test func ac11_titleCaseInsensitiveAndDecoded() throws {
        let html = "<TITLE> 2026/11/20(금) &quot;잠언 1:8-19&quot; / 작성&#58; 김철수 </TITLE><div style='margin:60px;'><span>본문</span> 잠언 1:8-19<br />가</div>"
        let a = try #require(DevotionArticleParser.parse(html: html))
        let t = try #require(a.titleEntry)
        #expect(t.date == DevotionDate(year: 2026, month: 11, day: 20))
        #expect(t.passageText == "잠언 1:8-19")
        #expect(t.author == "김철수")
    }

    // MARK: - AC-12 failure and optional boundaries

    // AC-12: empty string → nil
    @Test func ac12_emptyIsNil() {
        #expect(DevotionArticleParser.parse(html: "") == nil)
    }

    // AC-12: no margin:60px div → nil
    @Test func ac12_noBodyDivIsNil() {
        let html = "<html><body><div style='margin:10px;'><span>본문</span> 잠언 1:1-7<br />가</div></body></html>"
        #expect(DevotionArticleParser.parse(html: html) == nil)
    }

    // AC-12: body div without 본문 label → nil
    @Test func ac12_noPassageLabelIsNil() {
        let html = "<div style='margin:60px;'><span>찬송가</span> 1장<br />설교만<br />가</div>"
        #expect(DevotionArticleParser.parse(html: html) == nil)
    }

    // AC-12: no 찬송가 label → hymn nil, sermon starts after the passage line's <br>
    @Test func ac12_noHymnLabel() throws {
        let html = "<div style='margin:60px;'><span>본문</span> 잠언 1:1-7<br />가<br />나</div>"
        let a = try #require(DevotionArticleParser.parse(html: html))
        #expect(a.passageText == "잠언 1:1-7")
        #expect(a.hymn == nil)
        #expect(a.sermon == "가\n나")
    }

    // AC-12: nested div inside body div → content of and after the nested div kept; outside excluded
    @Test func ac12_nestedDivKept() throws {
        let html = "<div style='margin:60px;'><span>본문</span> 잠언 1:1-7<br />a<div>안</div>끝</div>뒤"
        let a = try #require(DevotionArticleParser.parse(html: html))
        #expect(a.sermon == "a안끝")
        #expect(!a.sermon.contains("뒤"))
    }

    // AC-12 boundary: "margin: 60px" with space and upper case attribute still matches
    @Test func ac12_marginMatchIsCaseInsensitiveWithSpaces() throws {
        let html = "<DIV STYLE='font-size:14px;MARGIN:  60PX;'><span>본문</span> 잠언 1:1-7<br />가</DIV>"
        let a = try #require(DevotionArticleParser.parse(html: html))
        #expect(a.passageText == "잠언 1:1-7")
        #expect(a.sermon == "가")
    }

    // AC-12 boundary: unclosed body div → until end of document
    @Test func ac12_unclosedDivRunsToEnd() throws {
        let html = "<div style='margin:60px;'><span>본문</span> 잠언 1:1-7<br />가<br />나"
        let a = try #require(DevotionArticleParser.parse(html: html))
        #expect(a.sermon == "가\n나")
    }

    // AC-12 boundary: earlier non-body divs (e.g. iframe div) are skipped
    @Test func ac12_earlierDivsSkipped() throws {
        let html = "<div><iframe src='https://www.youtube.com/embed/x'></iframe></div><div style='margin:60px;'><span>본문</span> 잠언 1:1-7<br />가</div><script>__CF$cv$params={}</script>"
        let a = try #require(DevotionArticleParser.parse(html: html))
        #expect(a.sermon == "가")
    }

    // AC-12 boundary: blank lines are not collapsed; edges trimmed; per-line space/tab trimmed
    @Test func ac12_blankLinesKeptEdgesTrimmed() throws {
        let html = "<div style='margin:60px;'><span>본문</span> 잠언 1:1-7<br />\n<br />  가 \t<br />\r\n<br /><br />\t나<br /><br /></div>"
        let a = try #require(DevotionArticleParser.parse(html: html))
        #expect(a.sermon == "가\n\n\n나")
    }

    // AC-12 boundary: other inline tags removed, text kept on the same line
    @Test func ac12_inlineTagsRemoved() throws {
        let html = "<div style='margin:60px;'><span>본문</span> 잠언 1:1-7<br /><span style='font-weight:bold;'>제목</span></span> 줄<br />끝</div>"
        let a = try #require(DevotionArticleParser.parse(html: html))
        #expect(a.sermon == "제목 줄\n끝")
    }
}
