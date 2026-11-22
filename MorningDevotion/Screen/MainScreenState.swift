//
//  MainScreenState.swift
//  MorningDevotion
//

import Foundation

extension Testament {
    nonisolated var displayName: String {
        switch self {
        case .oldTestament: return "구약"
        case .newTestament: return "신약"
        }
    }
}

nonisolated struct MainRowContent: Equatable, Sendable {
    let testament: Testament
    let entry: DevotionEntry
    let isRead: Bool

    var title: String { entry.displayTitle }
}

nonisolated enum MainRowState: Equatable, Sendable {
    case loading
    case ready(MainRowContent)
    case networkError
    case noNextDevotion

    var message: String? {
        switch self {
        case .loading, .ready: return nil
        case .networkError: return "인터넷 연결을 확인해 주세요"
        case .noNextDevotion: return "다음 묵상을 찾지 못했습니다"
        }
    }
}

nonisolated enum MainRowRules {
    /// 00:00-11:59 → old testament, 12:00-23:59 → new testament.
    static func nowTestament(at instant: Date, calendar: Calendar) -> Testament {
        NextDevotionPicker.testament(at: instant, calendar: calendar)
    }

    /// Same-day refresh without network: only a `.ready` row changes, and only its `isRead`.
    static func refreshed(
        _ row: MainRowState,
        lastSeen: DevotionDate,
        finishedDay: DevotionDate?,
        today: DevotionDate
    ) -> MainRowState {
        guard case .ready(let content) = row else { return row }
        let isRead = finishedDay == today && content.entry.date == lastSeen
        return .ready(MainRowContent(testament: content.testament, entry: content.entry, isRead: isRead))
    }
}

nonisolated enum MainRowLoader {
    /// Read branch (finished today): the entry of `lastSeen` itself. Otherwise: the next entry after `lastSeen`.
    /// Any thrown error, or a read branch with no matching entry, becomes `.networkError`.
    static func load(
        _ testament: Testament,
        lastSeen: DevotionDate,
        finishedDay: DevotionDate?,
        today: DevotionDate,
        using fetcher: some DevotionHTMLFetching
    ) async -> MainRowState {
        do {
            if finishedDay == today {
                guard let entry = try await SeenDevotionSearch.find(on: lastSeen, using: fetcher) else {
                    return .networkError
                }
                return .ready(MainRowContent(testament: testament, entry: entry, isRead: true))
            }
            guard let entry = try await NextDevotionSearch.findNext(after: lastSeen, using: fetcher) else {
                return .noNextDevotion
            }
            return .ready(MainRowContent(testament: testament, entry: entry, isRead: false))
        } catch {
            return .networkError
        }
    }
}
