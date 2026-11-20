//
//  DevotionScreenModel.swift
//  MorningDevotion
//

import Foundation
import Observation

@MainActor @Observable
final class DevotionScreenModel {
    private(set) var state: DevotionScreenState = .loading

    private let store: ReadingProgressStore
    private let fetcher: any DevotionHTMLFetching
    private let searcher: any YouTubeSearchFetching
    private let apiKey: String?
    private let calendar: Calendar
    private let now: () -> Date

    /// (testament, local day) the current state was decided for; used by refreshIfStale.
    private var decidedFor: (testament: Testament, day: DevotionDate)?

    init(
        store: ReadingProgressStore,
        fetcher: any DevotionHTMLFetching,
        searcher: any YouTubeSearchFetching,
        apiKey: String?,
        calendar: Calendar,
        now: @escaping () -> Date
    ) {
        self.store = store
        self.fetcher = fetcher
        self.searcher = searcher
        self.apiKey = apiKey
        self.calendar = calendar
        self.now = now
    }

    func load() async {
        let instant = now()
        let testament = NextDevotionPicker.testament(at: instant, calendar: calendar)
        let today = DevotionDate(localDayOf: instant, calendar: calendar)
        state = .loading
        decidedFor = (testament, today)

        if store.finishedDay(for: testament) == today {
            state = .finishedToday(testament)
            return
        }

        let lastSeen = store.storedProgress().lastSeen(for: testament)
        let entry: DevotionEntry
        do {
            guard let found = try await NextDevotionSearch.findNext(after: lastSeen, using: fetcher) else {
                state = .noNextDevotion
                return
            }
            entry = found
        } catch {
            state = .networkError
            return
        }

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
        guard case .showing(let content) = state else { return }
        let today = DevotionDate(localDayOf: now(), calendar: calendar)
        store.markSeen(content.testament, date: content.entry.date)
        store.markFinished(content.testament, on: today)
        state = .finishedToday(content.testament)
        decidedFor = (content.testament, today)
    }

    func refreshIfStale() async {
        if case .loading = state { return }
        let instant = now()
        let current = (
            testament: NextDevotionPicker.testament(at: instant, calendar: calendar),
            day: DevotionDate(localDayOf: instant, calendar: calendar)
        )
        if case .networkError = state {
            await load()
            return
        }
        if let decided = decidedFor, decided.testament == current.testament, decided.day == current.day {
            return
        }
        await load()
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
