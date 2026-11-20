//
//  DevotionArticleLoaderTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

/// Fake fetcher: records requested URLs, returns a fixed HTML or throws a fixed error. No network.
private actor FakeFetcher: DevotionHTMLFetching {
    enum Reply: Sendable {
        case html(String)
        case failure(any Error)
    }

    private let reply: Reply
    private(set) var requested: [URL] = []

    init(_ reply: Reply) {
        self.reply = reply
    }

    func fetchHTML(from url: URL) async throws -> String {
        requested.append(url)
        switch reply {
        case .html(let html): return html
        case .failure(let error): throw error
        }
    }
}

@MainActor
struct DevotionArticleLoaderTests {

    // MARK: - Helpers

    private static let url15155 = "https://100church.org/home/board.php?board=cast&config=6&category=6&command=body&no=15155&body_only=y&button_view=n"

    private static func entry(articleNo: Int?) throws -> DevotionEntry {
        var e = try #require(DevotionTitleParser.parse("2025/09/11(목) “잠언 23:24-35” / 작성: 김광욱"))
        e.articleNo = articleNo
        return e
    }

    /// Runs the loader and returns the thrown error (nil if it returned normally).
    private static func loadError(_ entry: DevotionEntry, _ fetcher: FakeFetcher) async -> (any Error)? {
        do {
            _ = try await DevotionArticleLoader.load(entry: entry, using: fetcher)
            return nil
        } catch {
            return error
        }
    }

    // MARK: - AC-13 success path

    // AC-13: fetcher receives the article URL once; result parsed from the fixture
    @Test func ac13_loadsArticleThroughFetcher() async throws {
        let fetcher = FakeFetcher(.html(try FixtureLoader.html("cast-body-15155")))
        let article = try await DevotionArticleLoader.load(entry: try Self.entry(articleNo: 15155), using: fetcher)

        let requested = await fetcher.requested
        #expect(requested.count == 1)
        #expect(requested.first?.absoluteString == Self.url15155)
        #expect(article.passageText == "잠언 23:24-35")
        #expect(article.hymn == "454장 ‘주와 같이 되기를’")
        #expect(article.titleEntry?.date == DevotionDate(year: 2025, month: 9, day: 11))
    }

    // MARK: - AC-14 errors

    // AC-14 (a): missing article number → missingArticleNumber, fetcher not called
    @Test func ac14a_missingArticleNumber() async throws {
        let fetcher = FakeFetcher(.html(try FixtureLoader.html("cast-body-15155")))
        let error = await Self.loadError(try Self.entry(articleNo: nil), fetcher)

        #expect(error as? DevotionLoadError == .missingArticleNumber)
        #expect(await fetcher.requested.isEmpty)
    }

    // AC-14 (b): URLError from the fetcher is rethrown unchanged
    @Test func ac14b_urlErrorRethrown() async throws {
        let fetcher = FakeFetcher(.failure(URLError(.notConnectedToInternet)))
        let error = await Self.loadError(try Self.entry(articleNo: 15155), fetcher)

        let urlError = try #require(error as? URLError)
        #expect(urlError.code == .notConnectedToInternet)
        #expect(await fetcher.requested.count == 1)
    }

    // AC-14 (c): unparseable HTML → unparseable
    @Test func ac14c_unparseableHTML() async throws {
        let fetcher = FakeFetcher(.html("<html></html>"))
        let error = await Self.loadError(try Self.entry(articleNo: 15155), fetcher)

        #expect(error as? DevotionLoadError == .unparseable)
        #expect(await fetcher.requested.count == 1)
    }

    // AC-14 boundary: loader-domain errors thrown by the fetcher pass through as-is (not remapped)
    @Test func ac14_fetcherLoadErrorPassesThrough() async throws {
        let fetcher = FakeFetcher(.failure(DevotionLoadError.badStatus(404)))
        let error = await Self.loadError(try Self.entry(articleNo: 15155), fetcher)
        #expect(error as? DevotionLoadError == .badStatus(404))

        let fetcher2 = FakeFetcher(.failure(DevotionLoadError.notUTF8))
        let error2 = await Self.loadError(try Self.entry(articleNo: 15155), fetcher2)
        #expect(error2 as? DevotionLoadError == .notUTF8)
    }

    // AC-14 boundary: empty HTML → unparseable
    @Test func ac14_emptyHTMLIsUnparseable() async throws {
        let fetcher = FakeFetcher(.html(""))
        let error = await Self.loadError(try Self.entry(articleNo: 11480), fetcher)
        #expect(error as? DevotionLoadError == .unparseable)
        #expect(await fetcher.requested.first?.absoluteString.contains("&no=11480&") == true)
    }
}
