//
//  Theme.swift
//  MorningDevotion
//

import SwiftUI
import UIKit

/// Colors and fonts shared by the main and devotion screens.
enum Theme {
    /// Reading background: warm paper in light mode, dark brown in dark mode.
    static let paper = dynamic(light: (0.97, 0.95, 0.90), dark: (0.13, 0.11, 0.09))
    /// Body text on paper.
    static let ink = dynamic(light: (0.20, 0.17, 0.14), dark: (0.91, 0.88, 0.82))

    /// Soft background behind the glass cards on the main screen.
    static let mainBackground = LinearGradient(
        colors: [
            dynamic(light: (0.99, 0.90, 0.78), dark: (0.20, 0.14, 0.10)),
            dynamic(light: (0.84, 0.89, 0.97), dark: (0.08, 0.10, 0.17)),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sermonFont = Font.body
    static let passageFont = Font.title2.weight(.semibold)
    static let sermonLineSpacing: CGFloat = 7

    private static func dynamic(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

/// 44x44 circular Liquid Glass arrow.
struct GlassArrowButton: View {
    let direction: MoveDirection
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: direction.symbolName)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(direction.accessibilityLabel)
    }
}

/// Small capsule label such as "지금" or "읽음".
struct BadgeLabel: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: Capsule())
    }
}
