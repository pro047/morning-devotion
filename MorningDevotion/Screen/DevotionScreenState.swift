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
