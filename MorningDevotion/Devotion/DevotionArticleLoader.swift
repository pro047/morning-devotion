//
//  DevotionArticleLoader.swift
//  MorningDevotion
//

import Foundation

nonisolated protocol DevotionHTMLFetching: Sendable {
    func fetchHTML(from url: URL) async throws -> String
}

nonisolated enum DevotionLoadError: Error, Equatable {
    case missingArticleNumber
    case invalidURL
    case badStatus(Int)
    case notUTF8
    case unparseable
}

/// Real fetcher. Errors thrown by URLSession are rethrown unchanged.
nonisolated struct URLSessionHTMLFetcher: DevotionHTMLFetching {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchHTML(from url: URL) async throws -> String {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw DevotionLoadError.badStatus(http.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw DevotionLoadError.notUTF8
        }
        return html
    }
}

nonisolated enum DevotionArticleLoader {
    static func load(entry: DevotionEntry, using fetcher: some DevotionHTMLFetching) async throws -> DevotionArticle {
        guard let no = entry.articleNo else { throw DevotionLoadError.missingArticleNumber }
        guard let url = DevotionArticleURL.url(articleNo: no) else { throw DevotionLoadError.invalidURL }
        let html = try await fetcher.fetchHTML(from: url)
        guard let article = DevotionArticleParser.parse(html: html) else { throw DevotionLoadError.unparseable }
        return article
    }
}
