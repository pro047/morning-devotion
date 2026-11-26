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
    private(set) var feedback: MoveFeedback?

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
        state = await buildState(for: entry)
    }

    /// Fetches the article and video slot for `entry` without touching `state`.
    private func buildState(for entry: DevotionEntry) async -> DevotionScreenState {
        guard let no = entry.articleNo, let url = DevotionArticleURL.url(articleNo: no) else {
            return .networkError
        }
        let html: String
        do {
            html = try await fetcher.fetchHTML(from: url)
        } catch {
            return .networkError
        }
        guard let article = DevotionArticleParser.parse(html: html) else {
            return .networkError
        }

        let slot = await videoSlot(for: entry)
        return .showing(DevotionScreenContent(testament: testament, entry: entry, article: article, video: slot))
    }

    func retry() async {
        await load()
    }

    /// Shown while the confirmation action sheet is up. Only requestFinish sets it to true.
    private(set) var isConfirmingFinish: Bool = false

    /// Bottom capsule is shown only while an article is on screen (F-8 FR-1, FR-2).
    /// A move search keeps state .showing, so the capsule stays during moves (FR-3).
    var showsCapsule: Bool {
        if case .showing = state { return true }
        return false
    }

    /// Moving first, then finish (screen is .showing and unread), else dot.
    var capsuleCenter: CapsuleCenter {
        if isMoving { return .moving }
        if case .showing = state, showsFinishButton { return .finish }
        return .dot
    }

    /// Opens the confirmation only; never writes the store.
    func requestFinish() {
        guard capsuleCenter == .finish else { return }
        isConfirmingFinish = true
    }

    /// No guard on isConfirmingFinish: the binding may clear it before the button action runs.
    func confirmFinish() {
        isConfirmingFinish = false
        markSeen()
    }

    func cancelFinish() {
        isConfirmingFinish = false
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
        switch outcome {
        case .moved(let next):
            // Keep isMoving true and the current state until the new content is built.
            let built = await buildState(for: next)
            entry = next
            state = built
            isMoving = false
            var succeeded = false
            if case .showing = built { succeeded = true }
            recordFeedback(direction, succeeded: succeeded)
        case .notFound, .networkError:
            isMoving = false
            notice = AdjacentDevotionSearch.message(for: outcome, direction: direction)
            recordFeedback(direction, succeeded: false)
        }
    }

    private func recordFeedback(_ direction: MoveDirection, succeeded: Bool) {
        let serial = (feedback?.serial ?? 0) + 1
        feedback = MoveFeedback(serial: serial, direction: direction, succeeded: succeeded)
    }

    func refreshIfStale() async {
        if case .networkError = state {
            await load()
        }
    }

    private func videoSlot(for entry: DevotionEntry) async -> VideoSlot {
        guard let key = apiKey, !key.isEmpty else { return .notFound }
        let result = await DevotionVideoFinder.findVideo(for: entry, apiKey: key, using: searcher)
        switch result {
        case .found(let id): return .video(id: id)
        case .notFound: return .notFound
        case .searchFailed: return .networkError
        }
    }
}
