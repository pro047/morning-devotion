//
//  MainScreenModel.swift
//  MorningDevotion
//

import Foundation
import Observation

@MainActor @Observable
final class MainScreenModel {
    private(set) var oldRow: MainRowState = .loading
    private(set) var newRow: MainRowState = .loading

    private let store: ReadingProgressStore
    private let fetcher: any DevotionHTMLFetching
    private let searcher: any YouTubeSearchFetching
    private let apiKey: String?
    private let calendar: Calendar
    private let now: () -> Date

    /// Local day the rows were last decided for; used by refreshOnReturn.
    private var decidedDay: DevotionDate?

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

    func row(for testament: Testament) -> MainRowState {
        switch testament {
        case .oldTestament: return oldRow
        case .newTestament: return newRow
        }
    }

    func isNow(_ testament: Testament) -> Bool {
        MainRowRules.nowTestament(at: now(), calendar: calendar) == testament
    }

    func load() async {
        let today = DevotionDate(localDayOf: now(), calendar: calendar)
        decidedDay = today
        oldRow = .loading
        newRow = .loading
        async let old = loadRow(.oldTestament, today: today)
        async let new = loadRow(.newTestament, today: today)
        let (oldResult, newResult) = await (old, new)
        oldRow = oldResult
        newRow = newResult
    }

    func retry(_ testament: Testament) async {
        let today = DevotionDate(localDayOf: now(), calendar: calendar)
        setRow(.loading, for: testament)
        let result = await loadRow(testament, today: today)
        setRow(result, for: testament)
    }

    func refreshOnReturn() async {
        if case .loading = oldRow { return }
        if case .loading = newRow { return }
        let today = DevotionDate(localDayOf: now(), calendar: calendar)
        if today != decidedDay {
            await load()
            return
        }
        let progress = store.storedProgress()
        oldRow = MainRowRules.refreshed(
            oldRow,
            lastSeen: progress.lastSeenOld,
            finishedDay: store.finishedDay(for: .oldTestament),
            today: today
        )
        newRow = MainRowRules.refreshed(
            newRow,
            lastSeen: progress.lastSeenNew,
            finishedDay: store.finishedDay(for: .newTestament),
            today: today
        )
    }

    func makeScreenModel(for testament: Testament) -> DevotionScreenModel? {
        guard case .ready(let content) = row(for: testament) else { return nil }
        return DevotionScreenModel(
            testament: content.testament,
            entry: content.entry,
            mode: content.isRead ? .review : .next,
            store: store,
            fetcher: fetcher,
            searcher: searcher,
            apiKey: apiKey,
            calendar: calendar,
            now: now
        )
    }

    // Reads the store without writing (storedProgress / finishedDay only).
    private func loadRow(_ testament: Testament, today: DevotionDate) async -> MainRowState {
        let lastSeen = store.storedProgress().lastSeen(for: testament)
        let finishedDay = store.finishedDay(for: testament)
        return await MainRowLoader.load(
            testament,
            lastSeen: lastSeen,
            finishedDay: finishedDay,
            today: today,
            using: fetcher
        )
    }

    private func setRow(_ row: MainRowState, for testament: Testament) {
        switch testament {
        case .oldTestament: oldRow = row
        case .newTestament: newRow = row
        }
    }
}
