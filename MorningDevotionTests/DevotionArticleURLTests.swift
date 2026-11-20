//
//  DevotionArticleURLTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

@MainActor
struct DevotionArticleURLTests {

    private static let url15155 = "https://100church.org/home/board.php?board=cast&config=6&category=6&command=body&no=15155&body_only=y&button_view=n"
    private static let url11480 = "https://100church.org/home/board.php?board=cast&config=6&category=6&command=body&no=11480&body_only=y&button_view=n"

    // AC-5: string template for 15155
    @Test func ac5_stringFor15155() {
        #expect(DevotionArticleURL.string(articleNo: 15155) == Self.url15155)
    }

    // AC-5: URL is non-nil and keeps the exact string
    @Test func ac5_urlFor15155PreservesString() throws {
        let url = try #require(DevotionArticleURL.url(articleNo: 15155))
        #expect(url.absoluteString == Self.url15155)
        #expect(url.host == "100church.org")
    }

    // AC-5: second article number
    @Test func ac5_stringAndURLFor11480() throws {
        #expect(DevotionArticleURL.string(articleNo: 11480) == Self.url11480)
        let url = try #require(DevotionArticleURL.url(articleNo: 11480))
        #expect(url.absoluteString == Self.url11480)
    }

    // AC-5 boundary: only the no= part changes between numbers
    @Test func ac5_onlyNumberDiffers() {
        let a = DevotionArticleURL.string(articleNo: 1)
        let b = DevotionArticleURL.string(articleNo: 2)
        #expect(a.replacingOccurrences(of: "&no=1&", with: "&no=2&") == b)
        #expect(a.contains("&no=1&body_only=y"))
    }
}
