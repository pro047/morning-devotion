//
//  DevotionScreenState.swift
//  MorningDevotion
//

import Foundation

nonisolated enum VideoSlot: Equatable, Sendable {
    case video(id: String)
    case notFound
    case networkError

    var message: String? {
        switch self {
        case .video: return nil
        case .notFound: return "영상을 찾지 못했습니다"
        case .networkError: return "인터넷 연결을 확인해 주세요"
        }
    }
}

extension DevotionEntry {
    /// "2025/09/11(목)"; weekday nil → "2025/09/11".
    nonisolated var displayDate: String {
        if let weekday {
            return "\(date.description)(\(weekday))"
        }
        return date.description
    }

    /// displayDate + " " + passageText.
    nonisolated var displayTitle: String {
        "\(displayDate) \(passageText)"
    }
}

nonisolated struct DevotionScreenContent: Equatable, Sendable {
    let testament: Testament
    let entry: DevotionEntry
    let article: DevotionArticle
    let video: VideoSlot

    // Header comes from the list entry, never from the article's own passage line.
    var headerDate: String { entry.displayDate }
    var headerPassage: String { entry.passageText }
    var headerTitle: String { entry.displayTitle }
}

/// What the middle of the bottom capsule shows (F-7 FR-1). Exactly one at a time.
nonisolated enum CapsuleCenter: Equatable, Sendable {
    case moving   // move search in flight → ProgressView
    case finish   // unread entry shown → "다 봤어요" text button
    case dot      // everything else → 6pt dot
}

/// Copy for the finish button and its confirmation action sheet (F-7 US-2).
nonisolated enum FinishConfirmation {
    static let buttonLabel = "다 봤어요"
    static let title = "다 봤어요로 표시할까요?"
    static let confirmLabel = "다 봤어요"
    static let cancelLabel = "취소"
}

/// Bible bottom sheet (F-9). `.closed` = not presented.
nonisolated enum BibleSheetState: Equatable, Sendable {
    case closed
    case loading(title: String)
    case showing(BiblePassageText)
    case failed(title: String)

    var isPresented: Bool {
        if case .closed = self { return false }
        return true
    }

    var title: String? {
        switch self {
        case .closed: return nil
        case .loading(let title), .failed(let title): return title
        case .showing(let text): return text.title
        }
    }

    var message: String? {
        if case .failed = self { return "인터넷 연결을 확인해 주세요" }
        return nil
    }
}

nonisolated enum DevotionScreenState: Equatable, Sendable {
    case loading
    case showing(DevotionScreenContent)
    case networkError

    var message: String? {
        switch self {
        case .loading, .showing: return nil
        case .networkError: return "인터넷 연결을 확인해 주세요"
        }
    }
}
