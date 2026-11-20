//
//  DevotionTitleParserTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

@MainActor
struct DevotionTitleParserTests {

    // MARK: - AC-3 quotes

    // AC-3: straight quotes and curly quotes yield the same passage
    @Test func ac3_straightAndCurlyQuotesProduceSamePassage() throws {
        let straight = try #require(DevotionTitleParser.parse(" 2015/06/22(월) \"요한복음 5:30-47\" / 작성: 윤순재"))
        let curly = try #require(DevotionTitleParser.parse(" 2020/07/13(월) “요한복음 5:30-47” / 작성: 박성호"))

        #expect(straight.passageText == "요한복음 5:30-47")
        #expect(curly.passageText == "요한복음 5:30-47")
        #expect(straight.passage == curly.passage)
        #expect(straight.passage == Passage(book: "요한복음", chapter: 5, startVerse: 30, endChapter: 5, endVerse: 47))
        #expect(straight.date == DevotionDate(year: 2015, month: 6, day: 22))
        #expect(straight.author == "윤순재")
        #expect(curly.author == "박성호")
    }

    // AC-3: mixed opening straight quote and closing curly quote
    @Test func ac3_mixedQuotes() throws {
        let entry = try #require(DevotionTitleParser.parse(" 2014/01/21(화) \"이사야 19:1-25” / 작성: 장재령"))
        #expect(entry.passageText == "이사야 19:1-25")
        #expect(entry.passage == Passage(book: "이사야", chapter: 19, startVerse: 1, endChapter: 19, endVerse: 25))
        #expect(entry.author == "장재령")
    }

    // MARK: - AC-4 range separator

    // AC-4: "~" is normalized to "-"
    @Test func ac4_tildeAndHyphenProduceSamePassage() throws {
        let tilde = try #require(DevotionTitleParser.parse("2008/12/24(수) \"잠언 23:1~35\"/ 작성: 김효진"))
        let hyphen = try #require(DevotionTitleParser.parse("2018/12/10(월) “잠언 23:1-35” / 작성: 정인철"))

        #expect(tilde.passageText == "잠언 23:1-35")
        #expect(hyphen.passageText == "잠언 23:1-35")
        #expect(tilde.passage == hyphen.passage)
        #expect(tilde.passage == Passage(book: "잠언", chapter: 23, startVerse: 1, endChapter: 23, endVerse: 35))
        // "/ 작성" with no space before "/"
        #expect(tilde.author == "김효진")
        #expect(tilde.weekday == "수")
    }

    // MARK: - AC-5 space after date

    // AC-5: space between date and "(요일)"
    @Test func ac5_spaceAfterDate() throws {
        let entry = try #require(DevotionTitleParser.parse("2026/11/17 (화) “에스겔 27:1-11” / 작성: 이주영"))
        #expect(entry.date == DevotionDate(year: 2026, month: 11, day: 17))
        #expect(entry.weekday == "화")
        #expect(entry.passageText == "에스겔 27:1-11")
        #expect(entry.passage == Passage(book: "에스겔", chapter: 27, startVerse: 1, endChapter: 27, endVerse: 11))
        #expect(entry.author == "이주영")
    }

    // AC-5: same field shape as the no-space variant
    @Test func ac5_sameShapeAsNoSpaceVariant() throws {
        let entry = try #require(DevotionTitleParser.parse("2026/11/16(월) “에스겔 26:13-21” / 작성: 조광묵"))
        #expect(entry.date == DevotionDate(year: 2026, month: 11, day: 16))
        #expect(entry.weekday == "월")
        #expect(entry.passageText == "에스겔 26:13-21")
        #expect(entry.passage == Passage(book: "에스겔", chapter: 26, startVerse: 13, endChapter: 26, endVerse: 21))
        #expect(entry.author == "조광묵")
    }

    // MARK: - AC-12 broken date (decision: lenient = yes)

    // AC-12: "2009/2/19/(목)" is parsed leniently as 2009-02-19
    @Test func ac12_brokenDateParsedLeniently() throws {
        let entry = try #require(DevotionTitleParser.parse("2009/2/19/(목) \"이사야 19:1-25\"/ 작성: 김순식"))
        #expect(entry.date == DevotionDate(year: 2009, month: 2, day: 19))
        #expect(entry.weekday == "목")
        #expect(entry.author == "김순식")
        #expect(entry.passageText == "이사야 19:1-25")
        #expect(entry.passage == Passage(book: "이사야", chapter: 19, startVerse: 1, endChapter: 19, endVerse: 25))
    }

    // MARK: - AC-13 no date → nil, odd passage → entry kept

    // AC-13: title without a date is dropped
    @Test func ac13_noDateReturnsNil() {
        #expect(DevotionTitleParser.parse("공지사항") == nil)
    }

    // AC-13: unparseable passage keeps the entry with passage == nil
    @Test func ac13_unparseablePassageKeepsEntry() throws {
        let entry = try #require(DevotionTitleParser.parse("2026/11/21(토) “특별새벽기도회” / 작성: 홍길동"))
        #expect(entry.date == DevotionDate(year: 2026, month: 11, day: 21))
        #expect(entry.weekday == "토")
        #expect(entry.passage == nil)
        #expect(entry.passageText == "특별새벽기도회")
        #expect(entry.author == "홍길동")
    }

    // MARK: - Boundaries beyond the listed criteria

    @Test func emptyAndWhitespaceTitlesReturnNil() {
        #expect(DevotionTitleParser.parse("") == nil)
        #expect(DevotionTitleParser.parse("   ") == nil)
    }

    // Design rule 2: month 1~12, day 1~31 out of range → nil
    @Test func outOfRangeMonthOrDayReturnsNil() {
        #expect(DevotionTitleParser.parse("2026/13/01(금) “잠언 1:1-7” / 작성: 홍길동") == nil)
        #expect(DevotionTitleParser.parse("2026/00/10(금) “잠언 1:1-7” / 작성: 홍길동") == nil)
        #expect(DevotionTitleParser.parse("2026/01/32(금) “잠언 1:1-7” / 작성: 홍길동") == nil)
        #expect(DevotionTitleParser.parse("2026/01/00(금) “잠언 1:1-7” / 작성: 홍길동") == nil)
    }

    // Design rule 2: date must be at the start
    @Test func dateNotAtStartReturnsNil() {
        #expect(DevotionTitleParser.parse("공지 2026/11/20(금) “잠언 1:1-7” / 작성: 홍길동") == nil)
    }

    // Design rule 3/4: weekday and author are optional
    @Test func missingWeekdayAndAuthorAreNil() throws {
        let entry = try #require(DevotionTitleParser.parse("2026/11/20 “잠언 1:1-7”"))
        #expect(entry.date == DevotionDate(year: 2026, month: 11, day: 20))
        #expect(entry.weekday == nil)
        #expect(entry.author == nil)
        #expect(entry.passageText == "잠언 1:1-7")
        #expect(entry.passage == Passage(book: "잠언", chapter: 1, startVerse: 1, endChapter: 1, endVerse: 7))
    }

    // Design rule 6: cross-chapter range "a:b-c:d"
    @Test func crossChapterRange() throws {
        let entry = try #require(DevotionTitleParser.parse("2026/11/22(일) “잠언 23:24-24:5” / 작성: 홍길동"))
        #expect(entry.passageText == "잠언 23:24-24:5")
        #expect(entry.passage == Passage(book: "잠언", chapter: 23, startVerse: 24, endChapter: 24, endVerse: 5))
    }

    // Design rule 4: no space after "작성:"
    @Test func authorWithoutSpaceAfterColon() throws {
        let entry = try #require(DevotionTitleParser.parse("2010/07/07(수) \"요한복음 5:19-29\" / 작성:김순식"))
        #expect(entry.author == "김순식")
        #expect(entry.passageText == "요한복음 5:19-29")
    }
}
