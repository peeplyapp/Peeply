//
//  DesignSystem.swift
//  Peeply
//
//  Created by Jason LaChance on 1/18/26.
//

import SwiftUI

struct DesignSystem {
    // MARK: - Brand Colors
    // Reference colors from PeeplyColors.swift
    // These are raw brand tokens and should be used intentionally for branded moments,
    // accents, illustrations, hero treatments, and marketing-style surfaces.
    static let cream = Color.peeplyCream
    static let background = Color.peeplyBackground
    static let rose = Color.peeplyRose
    static let lavender = Color.peeplyLavender
    static let charcoal = Color.peeplyCharcoal
    static let white = Color.peeplyWhite

    // MARK: - Semantic Colors
    // These are the default colors views should use for app UI.
    // They adapt correctly to light/dark mode and reduce the need for hardcoded colors
    // in screens like settings, onboarding forms, legal views, and utility surfaces.
    struct SemanticColors {
        // Screen and container backgrounds
        static let screenBackground = Color(uiColor: .systemBackground)
        static let groupedScreenBackground = Color(uiColor: .systemGroupedBackground)
        static let secondaryGroupedBackground = Color(uiColor: .secondarySystemGroupedBackground)
        static let cardBackground = Color(uiColor: .secondarySystemBackground)
        static let inputBackground = Color(uiColor: .secondarySystemBackground)

        // Text roles
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let tertiaryText = Color(uiColor: .tertiaryLabel)
        static let inverseText = Color(uiColor: .systemBackground)

        // Interactive and status roles
        static let accent = Color.peeplyPink
        static let destructiveText = Color.red
        static let separator = Color(uiColor: .separator)
        static let border = Color(uiColor: .separator).opacity(0.35)

        // Navigation and chrome
        static let navigationBackground = Color(uiColor: .systemBackground)
        static let toolbarIcon = Color.primary

        // Branded semantic helpers
        // These let you keep Peeply identity where desired without forcing
        // every screen to be styled as a light-only brand surface.
        static let brandSurface = Color.peeplyBackground
        static let brandPrimaryText = Color.peeplyCharcoal
        static let brandOnAccent = Color.peeplyWhite
    }

    // MARK: - Typography
    struct Typography {
        static let h1 = Font.system(size: 20, weight: .medium, design: .default)
        static let h2 = Font.system(size: 16, weight: .medium, design: .default)
        static let body = Font.system(size: 14, weight: .regular, design: .default)
        static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)
    }

    // MARK: - Spacing
    struct Spacing {
        static let standard: CGFloat = 12
        static let ellipsesSpacing: CGFloat = 20
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let card: CGFloat = 20
        static let ellipses: CGFloat = 30
        static let button: CGFloat = 44
        static let navigationButton: CGFloat = 52
        static let inputCard: CGFloat = 24
    }

    // MARK: - Sizes
    struct Sizes {
        static let ellipsesSize: CGFloat = 52
        static let searchIcon: CGFloat = 20
        static let cardIcon: CGFloat = 24
        static let navigationIcon: CGFloat = 24
    }
}
