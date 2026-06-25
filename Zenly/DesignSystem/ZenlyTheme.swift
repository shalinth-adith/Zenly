//
//  ZenlyTheme.swift
//  Zenly
//
//  Single source of truth for the "calm focus universe" visual language —
//  imported from the Claude Design spec (Zenly.dc.html). Colors, typography,
//  spacing, radii, and motion presets live here so every screen stays in sync
//  and the old hardcoded "#5C6BFA" string literals can be retired.
//
//  The design is intentionally dark-only (an aurora night sky), so these are
//  fixed brand colors rather than light/dark asset color sets.
//

import SwiftUI

enum ZTheme {

    // MARK: - Palette (hex from the design spec)

    enum Palette {
        /// Night-sky background base.
        static let night       = Color(hex: "0D0F1E")
        static let nightDeep   = Color(hex: "0A0B12")
        /// Top tint of the radial backdrop on most screens.
        static let auroraTop   = Color(hex: "171B38")
        /// Warmer/brighter backdrop tint used on the immersive session screens.
        static let sessionTop  = Color(hex: "1A1F44")

        /// Brand deep-blue — the one accent. Used for glow, active states, primary actions.
        static let brand       = Color(hex: "1A3FA8")
        static let brandLight  = Color(hex: "244FC4")   // top of the primary-button gradient
        static let brandGlow   = Color(hex: "4A72E0")   // brighter accent for fine strokes / ring
        /// High-contrast accent for interactive TEXT / icons / thin strokes on the
        /// dark surfaces — `brand` (#1A3FA8) is too dark to read as a foreground.
        static let brandBright = Color(hex: "7FBFFF")

        /// Aurora accents (`violet` now holds the cyan accent in the blue theme).
        static let violet      = Color(hex: "1FA8E0")
        static let teal        = Color(hex: "3FD0C9")

        /// Orb highlight tones.
        static let lavender    = Color(hex: "BDE8FF")
        static let lavenderSoft = Color(hex: "9FE0FF")
        static let orbMid      = Color(hex: "15294F")

        // Matte surface tokens (the "Zenly Matte" theme — flat opaque cards
        // replacing frosted glass: solid fill + a thin 10%-white hairline).
        static let matte             = Color(hex: "1A1F33")
        static let matteRaised       = Color(hex: "191E30")
        static let matteBorder       = Color.white.opacity(0.10)
        static let matteBorderStrong = Color.white.opacity(0.14)

        /// Text.
        static let textPrimary = Color(hex: "F4F5FF")
        static func text(_ opacity: Double) -> Color { textPrimary.opacity(opacity) }

        /// Semantic accents.
        static let streak      = Color(hex: "FF9F40")
        static let streakWarm  = Color(hex: "FFB257")

        // Glass surface tokens.
        static let glassFill        = Color.white.opacity(0.05)
        static let glassFillRaised   = Color.white.opacity(0.06)
        static let glassStroke      = Color.white.opacity(0.10)
        static let glassStrokeStrong = Color.white.opacity(0.14)
        static let glassHighlight   = Color.white.opacity(0.14)
    }

    // MARK: - The orb gradient (shared by every Focus Orb instance)

    static var orbGradient: RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: Color(hex: "E5DBFF"), location: 0.0),
                .init(color: Color(hex: "5FB6F0"), location: 0.22),
                .init(color: Color(hex: "4A72E0"), location: 0.48),
                .init(color: Palette.brand,        location: 0.64),
                .init(color: Color(hex: "13294D"), location: 0.86),
                .init(color: Palette.night.opacity(0), location: 1.0)
            ]),
            center: UnitPoint(x: 0.5, y: 0.38),
            startRadius: 0,
            endRadius: 120
        )
    }

    // MARK: - Typography (Quicksand display/numerals · Nunito body)

    enum Font {
        /// Bundled variable-font families (see Resources/Fonts + Info.plist UIAppFonts).
        static let displayFamily = "Quicksand"
        static let bodyFamily    = "Nunito"

        /// Big numerals (timer, stats, score) — Quicksand.
        static func numeral(_ size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .custom(displayFamily, size: size).weight(weight)
        }
        /// Headings / titles — Quicksand.
        static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .bold) -> SwiftUI.Font {
            .custom(displayFamily, size: size).weight(weight)
        }
        /// Body / labels — Nunito.
        static func body(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .custom(bodyFamily, size: size).weight(weight)
        }
    }

    // MARK: - Spacing & radii

    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 34
    }

    enum Radius {
        static let chip: CGFloat = 16
        static let card: CGFloat = 20
        static let sheet: CGFloat = 26
        static let button: CGFloat = 18
    }

    // MARK: - Motion

    enum Motion {
        /// Springy press / appearance feel (matches the design's cubic-bezier(.34,1.56,.64,1)).
        static let bouncy = Animation.spring(response: 0.35, dampingFraction: 0.55)
        static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.85)
        /// Idle orb breathing loop.
        static let breathe = Animation.easeInOut(duration: 6).repeatForever(autoreverses: true)
    }
}
