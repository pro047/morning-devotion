//
//  BibleChapterParserTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

struct BibleChapterParserTests {

    private static func verses(_ fixture: String) throws -> [BibleVerse] {
        BibleChapterParser.parse(html: try FixtureLoader.html(fixture))
    }

    private static func text(_ verses: [BibleVerse], _ n: Int) -> String? {
        verses.first(where: { $0.number == n })?.text
    }

    private static func expectClean(_ verses: [BibleVerse]) {
        for v in verses {
            #expect(!v.text.contains("<"), "verse \(v.number)")
            #expect(!v.text.contains("&"), "verse \(v.number)")
            #expect(!v.text.contains("\u{00A0}"), "verse \(v.number)")
            #expect(v.text == v.text.trimmingCharacters(in: .whitespacesAndNewlines), "verse \(v.number)")
            #expect(!v.text.contains("  "), "verse \(v.number)")
            #expect(!v.text.isEmpty, "verse \(v.number)")
        }
    }

    // F-9 AC-3: Proverbs 23 fixture → 35 verses 1…35, supplement words kept as plain text
    @Test func ac3_proverbs23() throws {
        let v = try Self.verses("bskorea-GAE-pro-23")
        #expect(v.count == 35)
        #expect(v.map(\.number) == Array(1...35))
        #expect(Self.text(v, 25) == "네 부모를 즐겁게 하며 너를 낳은 어미를 기쁘게 하라")
        #expect(Self.text(v, 25)?.contains("너 낳은") == false)
        #expect(Self.text(v, 14) == "네가 그를 채찍으로 때리면 그의 영혼을 스올에서 구원하리라")
        #expect(Self.text(v, 35)
            == "네가 스스로 말하기를 사람이 나를 때려도 나는 아프지 아니하고 나를 상하게 하여도 내게 감각이 없도다 내가 언제나 깰까 다시 술을 찾겠다 하리라")
        Self.expectClean(v)
    }

    // F-9 AC-4: John 5 fixture → 47 verses, footnotes and section titles removed
    @Test func ac4_john5() throws {
        let v = try Self.verses("bskorea-GAE-jhn-5")
        #expect(v.count == 47)
        #expect(v.map(\.number) == Array(1...47))
        #expect(Self.text(v, 31) == "내가 만일 나를 위하여 증언하면 내 증언은 참되지 아니하되")
        #expect(Self.text(v, 24)
            == "내가 진실로 진실로 너희에게 이르노니 내 말을 듣고 또 나 보내신 이를 믿는 자는 영생을 얻었고 심판에 이르지 아니하나니 사망에서 생명으로 옮겼느니라")
        #expect(Self.text(v, 3) == "그 안에 많은 병자, 맹인, 다리 저는 사람, 혈기 마른 사람들이 누워 [물의 움직임을 기다리니")
        #expect(Self.text(v, 29) == "선한 일을 행한 자는 생명의 부활로, 악한 일을 행한 자는 심판의 부활로 나오리라")
        let banned = ["오래된 병을 고치시다", "아들의 권한", "예수를 믿게 하는 증언", "어떤 사본에는", "또는 정죄", "2)"]
        for verse in v {
            for word in banned {
                #expect(!verse.text.contains(word), "verse \(verse.number) contains \(word)")
            }
        }
        Self.expectClean(v)
    }

    // F-9 AC-5: no verses → []
    @Test func ac5_emptyInputs() throws {
        #expect(BibleChapterParser.parse(html: "") == [])
        #expect(BibleChapterParser.parse(html: "<html></html>") == [])
        #expect(BibleChapterParser.parse(html: try FixtureLoader.html("cast-body-15155")) == [])
    }

    // F-9 AC-20: a verse whose body is empty is dropped
    @Test func ac20_emptyBodyVerseDropped() {
        let html = ##"<span class="number">1&nbsp;</span><br /><span class="number">2&nbsp;</span>b<br />"##
        #expect(BibleChapterParser.parse(html: html) == [BibleVerse(number: 2, text: "b")])
    }

    // F-9 AC-20: six entities, &amp; decoded last (so &amp;lt; stays "&lt;")
    @Test func ac20_entitiesAmpLast() {
        let html = ##"<span class="number">1&nbsp;</span>a&amp;b &lt;c&gt; &quot;d&quot; &#39;e&#39; &amp;lt;<br />"##
        #expect(BibleChapterParser.parse(html: html) == [BibleVerse(number: 1, text: "a&b <c> \"d\" 'e' &lt;")])
    }

    // F-9 AC-20: non-numeric verse marker → []
    @Test func ac20_nonNumericMarkerIgnored() {
        let html = ##"<span class="number">x</span>a<br />"##
        #expect(BibleChapterParser.parse(html: html) == [])
    }

    // F-9 AC-20 boundary: last verse ends at </div> (no <br), tags stripped, U+00A0 and runs of spaces folded
    @Test func ac20_lastVerseEndsAtDivAndSpacesFold() {
        let html = ##"<div><span class="number">7&nbsp;</span>  a <font size='1'>b</font>\##u{00A0}\##u{00A0}c  </div><p>tail</p>"##
        #expect(BibleChapterParser.parse(html: html) == [BibleVerse(number: 7, text: "a b c")])
    }

    // F-9 AC-20 boundary: footnote marker and footnote body are removed before splitting (rules 1·2 → 3)
    @Test func ac20_footnotesRemovedBeforeSplit() {
        let html = ##"<span class="number">1&nbsp;</span>x<a class=comment href="#">1)</a>y<div class=D2>note</div>z<br /><span class="number">2&nbsp;</span>w<br />"##
        #expect(BibleChapterParser.parse(html: html)
            == [BibleVerse(number: 1, text: "xyz"), BibleVerse(number: 2, text: "w")])
    }

    // F-9 AC-20 boundary: page order is kept (no sorting)
    @Test func ac20_pageOrderKept() {
        let html = ##"<span class="number">3&nbsp;</span>c<br /><span class="number">1&nbsp;</span>a<br />"##
        #expect(BibleChapterParser.parse(html: html)
            == [BibleVerse(number: 3, text: "c"), BibleVerse(number: 1, text: "a")])
    }
}
