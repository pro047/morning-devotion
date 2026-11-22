//
//  NavigationRulesTests.swift
//  MorningDevotionTests
//

import Foundation
import Testing
@testable import MorningDevotion

struct NavigationRulesTests {

    private static func swipe(_ dx: Double, _ dy: Double, startX: Double = 200, excl: Bool = false) -> MoveDirection? {
        SwipeRules.direction(dx: dx, dy: dy, startX: startX, excludesLeadingEdge: excl)
    }

    // MARK: - AC-69 SwipeRules.direction (FR-4·5, [결정] 5)

    // AC-69: constants are 60pt / 2x / 24pt
    @Test func ac69_constants() {
        #expect(SwipeRules.minimumDistance == 60)
        #expect(SwipeRules.dominanceRatio == 2)
        #expect(SwipeRules.leadingEdgeWidth == 24)
    }

    // AC-69: finger left (dx < 0) → next, finger right (dx > 0) → previous
    @Test func ac69_directionFromSign() {
        #expect(Self.swipe(-80, 10) == .next)
        #expect(Self.swipe(80, 10) == .previous)
        #expect(Self.swipe(-80, -10) == .next)
        #expect(Self.swipe(80, -10) == .previous)
    }

    // AC-69: minimum distance boundary (|dx| == 60 passes, 59 does not), both signs
    @Test func ac69_minimumDistanceBoundary() {
        #expect(Self.swipe(59, 0) == nil)
        #expect(Self.swipe(-59, 0) == nil)
        #expect(Self.swipe(60, 0) == .previous)
        #expect(Self.swipe(-60, 0) == .next)
        #expect(Self.swipe(59.9, 0) == nil)
    }

    // AC-69: dominance boundary (|dx| == 2|dy| passes, |dy| one more fails), sign of dy ignored
    @Test func ac69_dominanceBoundary() {
        #expect(Self.swipe(100, 51) == nil)
        #expect(Self.swipe(100, -51) == nil)
        #expect(Self.swipe(100, 50) == .previous)
        #expect(Self.swipe(100, -50) == .previous)
        #expect(Self.swipe(-100, -50) == .next)
        #expect(Self.swipe(-100, 50) == .next)
        #expect(Self.swipe(-100, 51) == nil)
    }

    // AC-69: vertical scroll and no movement are not swipes
    @Test func ac69_verticalAndZero() {
        #expect(Self.swipe(10, 300) == nil)
        #expect(Self.swipe(10, -300) == nil)
        #expect(Self.swipe(0, 0) == nil)
        #expect(Self.swipe(0, 100) == nil)
        // long but diagonal (dx 200, dy 150 → 200 < 300)
        #expect(Self.swipe(200, 150) == nil)
    }

    // AC-69: leading edge exclusion (startX < 24 only, and only when excludesLeadingEdge)
    @Test func ac69_leadingEdge() {
        #expect(Self.swipe(100, 0, startX: 10, excl: true) == nil)
        #expect(Self.swipe(100, 0, startX: 23.9, excl: true) == nil)
        #expect(Self.swipe(100, 0, startX: 0, excl: true) == nil)
        #expect(Self.swipe(100, 0, startX: 24, excl: true) == .previous)
        #expect(Self.swipe(100, 0, startX: 10, excl: false) == .previous)
        #expect(Self.swipe(100, 0, startX: 0, excl: false) == .previous)
        // exclusion depends on the start position, not the direction
        #expect(Self.swipe(-100, 0, startX: 10, excl: true) == nil)
        #expect(Self.swipe(-100, 0, startX: 24, excl: true) == .next)
        // excluding the edge does not change other rules
        #expect(Self.swipe(59, 0, startX: 200, excl: true) == nil)
        #expect(Self.swipe(100, 51, startX: 200, excl: true) == nil)
        #expect(Self.swipe(-80, 10, startX: 200, excl: true) == .next)
    }

    // MARK: - AC-71 MoveDirection labels (FR-9)

    // AC-71: VoiceOver labels and SF Symbol names
    @Test func ac71_accessibilityLabelAndSymbol() {
        #expect(MoveDirection.previous.accessibilityLabel == "이전 묵상")
        #expect(MoveDirection.next.accessibilityLabel == "다음 묵상")
        #expect(MoveDirection.previous.symbolName == "chevron.left")
        #expect(MoveDirection.next.symbolName == "chevron.right")
    }

    // MARK: - MoveFeedback value (backs AC-78 / AC-79)

    // AC-78 / AC-79: MoveFeedback equality covers all three fields (a new serial is a new trigger value)
    @Test func ac78_moveFeedbackEquality() {
        let a = MoveFeedback(serial: 1, direction: .next, succeeded: true)
        #expect(a == MoveFeedback(serial: 1, direction: .next, succeeded: true))
        #expect(a != MoveFeedback(serial: 2, direction: .next, succeeded: true))
        #expect(a != MoveFeedback(serial: 1, direction: .previous, succeeded: true))
        #expect(a != MoveFeedback(serial: 1, direction: .next, succeeded: false))
        #expect(a.serial == 1)
        #expect(a.direction == .next)
        #expect(a.succeeded == true)
    }
}
