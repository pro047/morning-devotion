//
//  DevotionVideoFinder.swift
//  MorningDevotion
//

import Foundation

/// Outcome of resolving a video for one devotion (M3 PRD R-4).
nonisolated enum DevotionVideoResult: Equatable, Sendable {
    case found(videoID: String)
    case notFound          // not on the article page and no matching search result
    case searchFailed      // network / HTTP / malformed response
}

/// Network boundary for YouTube Data API search.list. Tests inject a fake.
nonisolated protocol YouTubeSearchFetching: Sendable {
    func fetchSearchResponse(from url: URL) async throws -> Data
}

nonisolated enum YouTubeSearchError: Error, Equatable {
    case badStatus(Int)
}

/// Real fetcher. Non-2xx → YouTubeSearchError.badStatus. URLSession errors rethrown unchanged.
nonisolated struct URLSessionYouTubeSearchFetcher: YouTubeSearchFetching {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchSearchResponse(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw YouTubeSearchError.badStatus(http.statusCode)
        }
        return data
    }
}

nonisolated enum DevotionVideoFinder {
    static let channelID = "UCSkjujMSzrh6nghHWTSvIJg"

    private static let embedPattern = try! NSRegularExpression(pattern: #"youtube\.com/embed/([A-Za-z0-9_-]+)"#)
    private static let titleDatePattern = try! NSRegularExpression(pattern: #"^\s*\d{4}/\d{1,2}/\d{1,2}"#)

    /// Minimal shape of a search.list response. Every leaf is optional so one odd item can't fail the decode.
    private struct SearchResponse: Decodable {
        struct Item: Decodable {
            struct ID: Decodable { let videoId: String? }
            struct Snippet: Decodable { let title: String? }
            let id: ID?
            let snippet: Snippet?
        }
        let items: [Item]
    }

    /// R-1. First `youtube.com/embed/<id>` anywhere in the document.
    static func videoID(inArticleHTML html: String) -> String? {
        let ns = html as NSString
        guard let m = embedPattern.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        let id = ns.substring(with: m.range(at: 1))
        return id.isEmpty ? nil : id
    }

    /// R-2. "<YYYY/MM/DD> <passageText>".
    static func searchQuery(for entry: DevotionEntry) -> String {
        "\(entry.date.description) \(entry.passageText)"
    }

    /// R-2. Parameter order is fixed (tests assert it).
    static func searchURL(query: String, apiKey: String) -> URL? {
        guard var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "channelId", value: channelID),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: "5"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "key", value: apiKey),
        ]
        return components.url
    }

    /// R-3. Video titles look like `2020/07/13(월) “요한복음 5:30-47” / 박성호`; drop the trailing author
    /// so DevotionTitleParser (which only strips `/ 작성: 이름`) can read the passage.
    static func videoTitleEntry(_ rawTitle: String) -> DevotionEntry? {
        let decoded = DevotionListParser.decodeEntities(rawTitle)
        let ns = decoded as NSString
        guard let m = titleDatePattern.firstMatch(in: decoded, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        let head = ns.substring(with: m.range)
        var tail = ns.substring(from: m.range.location + m.range.length)
        if let slash = tail.range(of: "/", options: .backwards) {
            tail = String(tail[..<slash.lowerBound])
        }
        return DevotionTitleParser.parse(head + tail)
    }

    /// R-3. Same date, and same passage (structured when both parse, else exact normalized text).
    private static func isSameDevotion(_ entry: DevotionEntry, _ video: DevotionEntry) -> Bool {
        guard video.date == entry.date else { return false }
        if let a = entry.passage, let b = video.passage {
            return a == b
        }
        return entry.passageText == video.passageText
    }

    /// R-3. First item (response order) whose title is the same devotion. Throws on a malformed response.
    static func pickVideoID(for entry: DevotionEntry, searchResponse data: Data) throws -> String? {
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        for item in response.items {
            guard let videoID = item.id?.videoId,
                  let title = item.snippet?.title,
                  let videoEntry = videoTitleEntry(title)
            else { continue }
            if isSameDevotion(entry, videoEntry) { return videoID }
        }
        return nil
    }

    /// R-1 → R-2 → R-3 → R-4 → R-5. A video on the article page wins and skips the search entirely.
    static func findVideo(
        for entry: DevotionEntry,
        articleHTML: String?,
        apiKey: String,
        using searcher: some YouTubeSearchFetching
    ) async -> DevotionVideoResult {
        if let html = articleHTML, let id = videoID(inArticleHTML: html) {
            return .found(videoID: id)
        }
        guard let url = searchURL(query: searchQuery(for: entry), apiKey: apiKey) else {
            return .searchFailed
        }
        let data: Data
        do {
            data = try await searcher.fetchSearchResponse(from: url)
        } catch {
            return .searchFailed
        }
        do {
            if let id = try pickVideoID(for: entry, searchResponse: data) {
                return .found(videoID: id)
            }
            return .notFound
        } catch {
            return .searchFailed
        }
    }
}
