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
    private(set) var entry: DevotionEntry
    private(set) var isMoving: Bool = false
    private(set) var notice: String?

    /// Read on every access so it follows both the shown entry and the stored progress.
    var isRead: Bool { store.storedProgress().isRead(entry.date, for: testament) }
    var showsFinishButton: Bool { !isRead && !isFinished }

    private let store: ReadingProgressStore
    private let fetcher: any DevotionHTMLFetching
    private let searcher: any YouTubeSearchFetching
    private let apiKey: String?

    init(
        testament: Testament,
        entry: DevotionEntry,
        store: ReadingProgressStore,
        fetcher: any DevotionHTMLFetching,
        searcher: any YouTubeSearchFetching,
        apiKey: String?
    ) {
        self.testament = testament
        self.entry = entry
        self.store = store
        self.fetcher = fetcher
        self.searcher = searcher
        self.apiKey = apiKey
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
        guard !isRead, !isFinished, !isMoving, case .showing = state else { return }
        store.markSeen(testament, date: entry.date)
        isFinished = true
    }

    /// Replaces the shown entry in place. A failed search keeps the current entry and state.
    func move(_ direction: MoveDirection) async {
        guard !isMoving, !isFinished else { return }
        switch state {
        case .showing, .networkError: break
        case .loading: return
        }
        isMoving = true
        notice = nil
        let outcome = await AdjacentDevotionSearch.move(direction, from: entry.date, using: fetcher)
        isMoving = false
        switch outcome {
        case .moved(let next):
            entry = next
            await load()
        case .notFound, .networkError:
            notice = AdjacentDevotionSearch.message(for: outcome, direction: direction)
        }
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
