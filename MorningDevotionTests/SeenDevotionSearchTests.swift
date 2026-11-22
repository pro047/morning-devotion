//
//  SeenDevotionSearchTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

/// Fake homepage for one date search: search value → reply; unknown dates → 0-entry page. No network.
private actor FakeSeenHomepage: DevotionHTMLFetching {
    enum Reply: Sendable {
        case html(String)
        case failure(any Error)
    }

    private let search: [String: Reply]
    private let defaultSearch: String
    private(set) var requested: [URL] = []

    init(search: [String: Reply], defaultSearch: String) {
        self.search = search
        self.defaultSearch = defaultSearch
    }

    func fetchHTML(from url: URL) async throws -> String {
        requested.append(url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let value = items.first(where: { $0.name == "search" })?.value else {
            throw URLError(.badURL)
        }
        switch search[value] ?? .html(defaultSearch) {
        case .html(let html): return html
        case .failure(let error): throw error
        }
    }
}

@MainActor
struct SeenDevotionSearchTests {

    // MARK: - Helpers

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> DevotionDate {
        DevotionDate(year: y, month: m, day: d)
    }

    private static func emptyPage() throws -> String {
        try FixtureLoader.html("cast-search-date-20250914")
    }

    private static func searchValues(_ urls: [URL]) -> [String?] {
        urls.map { url in
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "search" })?.value
        }
    }

    private static func entry(_ date: DevotionDate, _ passage: String, no: Int?) -> DevotionEntry {
        DevotionEntry(date: date, weekday: nil, passageText: passage, passage: nil, author: nil, articleNo: no)
    }

    // MARK: - AC-1 find(on:)

    // AC-1: one search for 2025/09/11 → the 2025/09/11 entry (first in list) with its article number
    @Test func ac1_findReturnsEntryOfThatDate() async throws {
        let homepage = FakeSeenHomepage(
            search: ["2025/09/11": .html(try FixtureLoader.html("cast-search-proverbs-23"))],
            defaultSearch: try Self.emptyPage())

        let found = try await SeenDevotionSearch.find(on: Self.date(2025, 9, 11), using: homepage)

        let e = try #require(found)
        #expect(e.date == Self.date(2025, 9, 11))
        #expect(e.weekday == "목")
        #expect(e.passageText == "잠언 23:24-35")
        #expect(e.articleNo == 15155)
        let requested = await homepage.requested
        #expect(requested.count == 1)
        #expect(Self.searchValues(requested) == ["2025/09/11"])
        #expect(requested.first == DevotionSearchURL.url(date: Self.date(2025, 9, 11)))
    }

    // AC-1: picks by date, not list position (2020/07/11 is the second item of john-5)
    @Test func ac1_findPicksByDateNotFirstItem() async throws {
        let homepage = FakeSeenHomepage(
            search: ["2020/07/11": .html(try FixtureLoader.html("cast-search-john-5"))],
            defaultSearch: try Self.emptyPage())

        let found = try await SeenDevotionSearch.find(on: Self.date(2020, 7, 11), using: homepage)

        let e = try #require(found)
        #expect(e.date == Self.date(2020, 7, 11))
        #expect(e.weekday == "토")
        #expect(e.passageText == "요한복음 5:19-29")
        #expect(Self.searchValues(await homepage.requested) == ["2020/07/11"])
    }

    // MARK: - AC-2 not found / errors / pure part

    // AC-2: 0-entry page → nil, still exactly one request
    @Test func ac2_emptyPageIsNil() async throws {
        let homepage = FakeSeenHomepage(search: [:], defaultSearch: try Self.emptyPage())

        let found = try await SeenDevotionSearch.find(on: Self.date(2025, 9, 11), using: homepage)

        #expect(found == nil)
        #expect(await homepage.requested.count == 1)
    }

    // AC-2 boundary: page has entries but none on that date (proverbs-23 has no 2025/09/12) → nil
    @Test func ac2_pageWithoutThatDateIsNil() async throws {
        let homepage = FakeSeenHomepage(
            search: ["2025/09/12": .html(try FixtureLoader.html("cast-search-proverbs-23"))],
            defaultSearch: try Self.emptyPage())

        let found = try await SeenDevotionSearch.find(on: Self.date(2025, 9, 12), using: homepage)

        #expect(found == nil)
    }

    // AC-2: fetch error is rethrown unchanged
    @Test func ac2_fetchErrorIsRethrown() async throws {
        let homepage = FakeSeenHomepage(
            search: ["2025/09/11": .failure(URLError(.notConnectedToInternet))],
            defaultSearch: try Self.emptyPage())

        var caught: (any Error)?
        do {
            _ = try await SeenDevotionSearch.find(on: Self.date(2025, 9, 11), using: homepage)
        } catch {
            caught = error
        }
        let urlError = try #require(caught as? URLError)
        #expect(urlError.code == .notConnectedToInternet)
        #expect(await homepage.requested.count == 1)
    }

    // AC-2: pure part — duplicates keep the first in list order; no match → nil; empty list → nil
    @Test func ac2_entryInPicksFirstMatchingDate() {
        let a = Self.entry(Self.date(2025, 9, 11), "A", no: 1)
        let b = Self.entry(Self.date(2025, 9, 11), "B", no: 2)
        let other = Self.entry(Self.date(2025, 9, 10), "C", no: 3)

        #expect(SeenDevotionSearch.entry(in: [other, a, b], on: Self.date(2025, 9, 11)) == a)
        #expect(SeenDevotionSearch.entry(in: [b, a], on: Self.date(2025, 9, 11)) == b)
        #expect(SeenDevotionSearch.entry(in: [other], on: Self.date(2025, 9, 11)) == nil)
        #expect(SeenDevotionSearch.entry(in: [], on: Self.date(2025, 9, 11)) == nil)
    }

    // AC-2 boundary: a later date is not "on" the date (exact match, not next)
    @Test func ac2_entryInIsExactDate() {
        let later = Self.entry(Self.date(2025, 9, 12), "L", no: 4)
        #expect(SeenDevotionSearch.entry(in: [later], on: Self.date(2025, 9, 11)) == nil)
    }
}
