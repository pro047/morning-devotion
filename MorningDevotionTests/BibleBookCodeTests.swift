//
//  BibleBookCodeTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

struct BibleBookCodeTests {

    // F-9 AC-1: 66 books, unique names and codes
    @Test func ac1_tableHas66UniqueBooks() {
        let all = BibleBookCode.all
        #expect(all.count == 66)
        #expect(Set(all.map { $0.name }).count == 66)
        #expect(Set(all.map { $0.code }).count == 66)
    }

    // F-9 AC-1: canon order boundary (names only): [38] = 말라기 (last OT), [39] = 마태복음 (first NT)
    @Test func ac1_canonOrderBoundary() throws {
        let all = BibleBookCode.all
        try #require(all.count == 66)
        #expect(all[0].name == "창세기")
        #expect(all[38].name == "말라기")
        #expect(all[39].name == "마태복음")
        #expect(all[65].name == "요한계시록")
    }

    // F-9 AC-1: measured codes (gen / pro / jhn) and whitespace trimming
    @Test func ac1_measuredCodes() {
        #expect(BibleBookCode.code(for: "잠언") == "pro")
        #expect(BibleBookCode.code(for: "요한복음") == "jhn")
        #expect(BibleBookCode.code(for: "창세기") == "gen")
        #expect(BibleBookCode.code(for: " 잠언 ") == "pro")
    }

    // F-9 AC-1: abbreviations, empty and partial names → nil
    @Test func ac1_unknownNamesAreNil() {
        #expect(BibleBookCode.code(for: "고린도전") == nil)
        #expect(BibleBookCode.code(for: "") == nil)
        #expect(BibleBookCode.code(for: "잠") == nil)
        #expect(BibleBookCode.code(for: "   ") == nil)
        #expect(BibleBookCode.code(for: "잠언서") == nil)
    }

    // F-9 AC-1 (확정 결정 1): every book in the table, incl. the 63 estimated ones, resolves to its own code
    @Test func ac1_everyBookHasCode() {
        for book in BibleBookCode.all {
            #expect(BibleBookCode.code(for: book.name) == book.code, "\(book.name)")
            #expect(BibleBookCode.code(for: book.name) != nil, "\(book.name)")
        }
        for name in ["에스겔", "이사야", "요한계시록", "고린도전서", "시편"] {
            #expect(BibleBookCode.code(for: name) != nil, "\(name)")
        }
    }

    // F-9 AC-1 boundary: devotion fixture title books all resolve
    @Test func ac1_fixtureTitleBooksResolve() {
        for name in ["에스겔", "요한복음", "이사야", "잠언", "창세기"] {
            #expect(BibleBookCode.code(for: name) != nil, "\(name)")
        }
    }

    // F-9 AC-2: chapter URL
    @Test func ac2_chapterURL() {
        #expect(BiblePassageURL.url(bookCode: "pro", chapter: 23)?.absoluteString
            == "https://www.bskorea.or.kr/bible/korbibReadpage.php?version=GAE&book=pro&chap=23")
        #expect(BiblePassageURL.url(bookCode: "jhn", chapter: 5)?.absoluteString
            == "https://www.bskorea.or.kr/bible/korbibReadpage.php?version=GAE&book=jhn&chap=5")
    }

    // F-9 AC-2: chapter < 1 or empty code → nil
    @Test func ac2_invalidInputsAreNil() {
        #expect(BiblePassageURL.url(bookCode: "pro", chapter: 0) == nil)
        #expect(BiblePassageURL.url(bookCode: "pro", chapter: -1) == nil)
        #expect(BiblePassageURL.url(bookCode: "", chapter: 23) == nil)
    }
}
