//
//  NavigationRules.swift
//  MorningDevotion
//

import Foundation

nonisolated enum SwipeRules {
    /// Minimum horizontal travel (pt) for a swipe.
    static let minimumDistance: Double = 60
    /// |dx| must be at least this many times |dy|.
    static let dominanceRatio: Double = 2
    /// Starts with x < this (pt, global coordinates) are left to the system back gesture.
    static let leadingEdgeWidth: Double = 24

    /// dx < 0 (finger moved left) -> .next, dx > 0 -> .previous.
    static func direction(dx: Double, dy: Double, startX: Double, excludesLeadingEdge: Bool) -> MoveDirection? {
        let width = abs(dx)
        guard width >= minimumDistance else { return nil }
        guard width >= dominanceRatio * abs(dy) else { return nil }
        if excludesLeadingEdge && startX < leadingEdgeWidth { return nil }
        return dx < 0 ? .next : .previous
    }
}

/// One finished move attempt. A new value (new serial) per attempt.
nonisolated struct MoveFeedback: Equatable, Sendable {
    let serial: Int
    let direction: MoveDirection
    let succeeded: Bool
}

/// Which arrows a row offers.
nonisolated struct NavArrows: Equatable, Sendable {
    let previous: Bool
    let next: Bool

    static let none = NavArrows(previous: false, next: false)
    static let both = NavArrows(previous: true, next: true)
    static let previousOnly = NavArrows(previous: true, next: false)

    func allows(_ direction: MoveDirection) -> Bool {
        switch direction {
        case .previous: return previous
        case .next: return next
        }
    }
}

extension MoveDirection {
    /// VoiceOver label.
    nonisolated var accessibilityLabel: String {
        switch self {
        case .previous: return "이전 묵상"
        case .next: return "다음 묵상"
        }
    }

    nonisolated var symbolName: String {
        switch self {
        case .previous: return "chevron.left"
        case .next: return "chevron.right"
        }
    }
}
