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

nonisolated struct DevotionScreenContent: Equatable, Sendable {
    let testament: Testament
    let entry: DevotionEntry
    let article: DevotionArticle
    let video: VideoSlot
}

nonisolated enum DevotionScreenState: Equatable, Sendable {
    case loading
    case showing(DevotionScreenContent)
    case finishedToday(Testament)
    case networkError
    case noNextDevotion

    var message: String? {
        switch self {
        case .loading, .showing: return nil
        case .finishedToday(.oldTestament): return "오늘 구약 묵상을 마쳤습니다"
        case .finishedToday(.newTestament): return "오늘 신약 묵상을 마쳤습니다"
        case .networkError: return "인터넷 연결을 확인해 주세요"
        case .noNextDevotion: return "다음 묵상을 찾지 못했습니다"
        }
    }
}
