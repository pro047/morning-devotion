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

    /// Progress each row was decided from; used by refreshOnReturn.
    private var oldBasis: DevotionDate?
    private var newBasis: DevotionDate?
    private var oldNotice: String?
    private var newNotice: String?
    private var oldMoving = false
    private var newMoving = false
    private var oldFeedback: MoveFeedback?
    private var newFeedback: MoveFeedback?
    private var feedbackSerial = 0

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

    func notice(for testament: Testament) -> String? {
        switch testament {
        case .oldTestament: return oldNotice
        case .newTestament: return newNotice
        }
    }

    func isMoving(_ testament: Testament) -> Bool {
        switch testament {
        case .oldTestament: return oldMoving
        case .newTestament: return newMoving
        }
    }

    func load() async {
        oldNotice = nil
        newNotice = nil
        oldRow = .loading
        newRow = .loading
        async let old = loadRow(.oldTestament)
        async let new = loadRow(.newTestament)
        let (oldResult, newResult) = await (old, new)
        oldRow = oldResult
        newRow = newResult
    }

    func retry(_ testament: Testament) async {
        setNotice(nil, for: testament)
        setRow(.loading, for: testament)
        let result = await loadRow(testament)
        setRow(result, for: testament)
    }

    func refreshOnReturn() async {
        if case .loading = oldRow { return }
        if case .loading = newRow { return }
        oldNotice = nil
        newNotice = nil
        let progress = store.storedProgress()
        var reload: [Testament] = []
        for testament in [Testament.oldTestament, .newTestament] {
            let action = MainRowRules.returnAction(
                row(for: testament),
                basis: basis(for: testament),
                lastSeen: progress.lastSeen(for: testament)
            )
            switch action {
            case .keep(let kept): setRow(kept, for: testament)
            case .reload: reload.append(testament)
            }
        }
        for testament in reload {
            await retry(testament)
        }
    }

    /// Moves one row to the previous/next entry without touching the store.
    func move(_ testament: Testament, _ direction: MoveDirection) async {
        guard case .ready(let content) = row(for: testament), !isMoving(testament) else { return }
        setMoving(true, for: testament)
        setNotice(nil, for: testament)
        let outcome = await AdjacentDevotionSearch.move(direction, from: content.entry.date, using: fetcher)
        setMoving(false, for: testament)

        // Drop the result if load/retry replaced the row while the search ran.
        guard case .ready(let current) = row(for: testament), current.entry == content.entry else { return }
        switch outcome {
        case .moved(let entry):
            let isRead = store.storedProgress().isRead(entry.date, for: testament)
            setRow(.ready(MainRowContent(testament: testament, entry: entry, isRead: isRead)), for: testament)
            recordFeedback(direction, succeeded: true, for: testament)
        case .notFound, .networkError:
            setNotice(AdjacentDevotionSearch.message(for: outcome, direction: direction), for: testament)
            recordFeedback(direction, succeeded: false, for: testament)
        }
    }

    /// Single entry point for arrows and swipes.
    func navigate(_ testament: Testament, _ direction: MoveDirection) async {
        switch row(for: testament) {
        case .ready:
            await move(testament, direction)
        case .noNextDevotion:
            if direction == .previous {
                await revealLastSeen(testament)
            }
        case .loading, .networkError:
            break
        }
    }

    /// Latest finished attempt for that row (nil until the first one).
    func feedback(for testament: Testament) -> MoveFeedback? {
        switch testament {
        case .oldTestament: return oldFeedback
        case .newTestament: return newFeedback
        }
    }

    /// Shows the entry on the stored progress date for a row that has no next entry.
    private func revealLastSeen(_ testament: Testament) async {
        guard case .noNextDevotion = row(for: testament), !isMoving(testament) else { return }
        setMoving(true, for: testament)
        setNotice(nil, for: testament)
        let date = store.storedProgress().lastSeen(for: testament)
        let outcome: Result<DevotionEntry?, Error>
        do {
            outcome = .success(try await SeenDevotionSearch.find(on: date, using: fetcher))
        } catch {
            outcome = .failure(error)
        }
        setMoving(false, for: testament)

        // Drop the result if load/retry replaced the row while the search ran.
        guard case .noNextDevotion = row(for: testament) else { return }
        switch outcome {
        case .success(let entry?):
            let isRead = store.storedProgress().isRead(entry.date, for: testament)
            setRow(.ready(MainRowContent(testament: testament, entry: entry, isRead: isRead)), for: testament)
            recordFeedback(.previous, succeeded: true, for: testament)
        case .success(nil):
            setNotice(AdjacentDevotionSearch.message(for: .notFound, direction: .previous), for: testament)
            recordFeedback(.previous, succeeded: false, for: testament)
        case .failure:
            setNotice(AdjacentDevotionSearch.message(for: .networkError, direction: .previous), for: testament)
            recordFeedback(.previous, succeeded: false, for: testament)
        }
    }

    private func recordFeedback(_ direction: MoveDirection, succeeded: Bool, for testament: Testament) {
        feedbackSerial += 1
        let value = MoveFeedback(serial: feedbackSerial, direction: direction, succeeded: succeeded)
        switch testament {
        case .oldTestament: oldFeedback = value
        case .newTestament: newFeedback = value
        }
    }

    func makeScreenModel(for testament: Testament) -> DevotionScreenModel? {
        guard case .ready(let content) = row(for: testament) else { return nil }
        return DevotionScreenModel(
            testament: content.testament,
            entry: content.entry,
            store: store,
            fetcher: fetcher,
            searcher: searcher,
            apiKey: apiKey
        )
    }

    // Reads the store without writing (storedProgress only).
    private func loadRow(_ testament: Testament) async -> MainRowState {
        let lastSeen = store.storedProgress().lastSeen(for: testament)
        setBasis(lastSeen, for: testament)
        return await MainRowLoader.load(testament, lastSeen: lastSeen, using: fetcher)
    }

    private func setRow(_ row: MainRowState, for testament: Testament) {
        switch testament {
        case .oldTestament: oldRow = row
        case .newTestament: newRow = row
        }
    }

    private func basis(for testament: Testament) -> DevotionDate? {
        switch testament {
        case .oldTestament: return oldBasis
        case .newTestament: return newBasis
        }
    }

    private func setBasis(_ value: DevotionDate?, for testament: Testament) {
        switch testament {
        case .oldTestament: oldBasis = value
        case .newTestament: newBasis = value
        }
    }

    private func setNotice(_ value: String?, for testament: Testament) {
        switch testament {
        case .oldTestament: oldNotice = value
        case .newTestament: newNotice = value
        }
    }

    private func setMoving(_ value: Bool, for testament: Testament) {
        switch testament {
        case .oldTestament: oldMoving = value
        case .newTestament: newMoving = value
        }
    }
}
