//
//  DevotionScreenModel.swift
//  MorningDevotion
//

import Foundation
import Observation

@MainActor @Observable
final class DevotionScreenModel {
    private(set) var state: DevotionScreenState = .loading

    private(set) var isFinished: Bool = false
    let testament: Testament
    let entry: DevotionEntry
    let mode: DevotionScreenMode

    var showsFinishButton: Bool { mode == .next && !isFinished }

    private let store: ReadingProgressStore
    private let fetcher: any DevotionHTMLFetching
    private let searcher: any YouTubeSearchFetching
    private let apiKey: String?
    private let calendar: Calendar
    private let now: () -> Date

    init(
        testament: Testament,
        entry: DevotionEntry,
        mode: DevotionScreenMode,
        store: ReadingProgressStore,
        fetcher: any DevotionHTMLFetching,
        searcher: any YouTubeSearchFetching,
        apiKey: String?,
        calendar: Calendar,
        now: @escaping () -> Date
    ) {
        self.testament = testament
        self.entry = entry
        self.mode = mode
        self.store = store
        self.fetcher = fetcher
        self.searcher = searcher
        self.apiKey = apiKey
        self.calendar = calendar
        self.now = now
    }

    func load() async {
        state = .loading

        guard let no = entry.articleNo, let url = DevotionArticleURL.url(articleNo: no) else {
            state = .networkError
            return
        }
        let html: String
        do {
            html = try await fetcher.fetchHTML(from: url)
        } catch {
            state = .networkError
            return
        }
        guard let article = DevotionArticleParser.parse(html: html) else {
            state = .networkError
            return
        }

        let slot = await videoSlot(for: entry, articleHTML: html)
        state = .showing(DevotionScreenContent(testament: testament, entry: entry, article: article, video: slot))
    }

    func retry() async {
        await load()
    }

    func markSeen() {
        guard mode == .next, !isFinished, case .showing = state else { return }
        let today = DevotionDate(localDayOf: now(), calendar: calendar)
        store.markSeen(testament, date: entry.date)
        store.markFinished(testament, on: today)
        isFinished = true
    }

    func refreshIfStale() async {
        if case .networkError = state {
            await load()
        }
    }

    private func videoSlot(for entry: DevotionEntry, articleHTML: String) async -> VideoSlot {
        guard let key = apiKey, !key.isEmpty else { return .notFound }
        let result = await DevotionVideoFinder.findVideo(
            for: entry, articleHTML: articleHTML, apiKey: key, using: searcher
        )
        switch result {
        case .found(let id): return .video(id: id)
        case .notFound: return .notFound
        case .searchFailed: return .networkError
        }
    }
}
