//
//  ZenlyTheme.swift
//  Zenly
//
//  Single source of truth for the "calm focus universe" visual language —
//  imported from the Claude Design spec (Zenly.dc.html). Colors, typography,
//  spacing, radii, and motion presets live here so every screen stays in sync
//  and the old hardcoded "#5C6BFA" string literals can be retired.
//
//  The app follows the system appearance (no in-app toggle): surface, screen,
//  ink and hairline tokens resolve light/dark per the OS setting via the
//  `Color(lightHex:darkHex:)` / `Color(light:dark:)` helpers in Color+Hex.swift.
//  The brand-blue accent and the Focus orb stay identical in both modes (brand
//  identity). Light/dark hex values are transcribed from the Claude Design spec
//  (Zenly Matte.dc.html — `applyTheme()`): canvas/screen/surface/ink and a single
//  `--line-rgb` hairline base (white #FFFFFF in dark, #1C2644 in light).
//

import SwiftUI

enum ZTheme {

    // MARK: - Palette (hex from the design spec)

    enum Palette {
        // Adaptive surfaces/backgrounds (design `--screen` / `--canvas`).
        /// Screen background base.
        static let night       = Color(lightHex: "F4F5FA", darkHex: "0D0F1E")
        /// Outermost backdrop behind every screen (design `--canvas`).
        static let nightDeep   = Color(lightHex: "DFE3EC", darkHex: "0A0B12")
        /// Top tint of the radial backdrop on most screens.
        static let auroraTop   = Color(lightHex: "E8ECF4", darkHex: "171B38")
        /// Warmer/brighter backdrop tint used on the immersive session screens.
        static let sessionTop  = Color(lightHex: "EAEEF6", darkHex: "1A1F44")

        // Brand blue — identical in both modes (the one accent: glow, button
        // fills, active states). These are fills/strokes that read on light too.
        static let brand       = Color(hex: "1A3FA8")
        static let brandLight  = Color(hex: "244FC4")   // top of the primary-button gradient
        static let brandGlow   = Color(hex: "4A72E0")   // brighter accent for fine strokes / ring
        /// High-contrast accent for interactive TEXT / icons / thin strokes.
        /// On dark surfaces a pale sky-blue reads best; on light it must be a
        /// deeper blue (the design's interactive accent #2257D6) for contrast.
        static let brandBright = Color(lightHex: "2257D6", darkHex: "7FBFFF")

        /// Aurora accents (`violet` now holds the cyan accent in the blue theme).
        static let violet      = Color(hex: "1FA8E0")
        static let teal        = Color(hex: "3FD0C9")

        /// Orb highlight tones.
        static let lavender    = Color(hex: "BDE8FF")
        static let lavenderSoft = Color(hex: "9FE0FF")
        static let orbMid      = Color(hex: "15294F")

        // Matte surface tokens (the "Zenly Matte" theme — flat opaque cards:
        // solid fill + a thin hairline). Surface = design `--surface` (#FFFFFF
        // light / #1A1F33 dark); the hairline uses the `--line-rgb` base, which
        // is white on dark and a deep navy (#1C2644) on light.
        static let matte             = Color(lightHex: "FFFFFF", darkHex: "1A1F33")
        static let matteRaised       = Color(lightHex: "FFFFFF", darkHex: "191E30")
        static let matteBorder       = Color(light: line(0.10), dark: Color.white.opacity(0.10))
        static let matteBorderStrong = Color(light: line(0.14), dark: Color.white.opacity(0.14))

        /// Hairline/overlay base from the design's `--line-rgb` for light mode.
        private static func line(_ opacity: Double) -> Color { Color(hex: "1C2644").opacity(opacity) }

        /// Text (design `--ink`).
        static let textPrimary = Color(lightHex: "12151E", darkHex: "F4F5FF")
        static func text(_ opacity: Double) -> Color { textPrimary.opacity(opacity) }

        /// Semantic accents — warm tones read on both modes; kept identical.
        static let streak      = Color(hex: "FF9F40")
        static let streakWarm  = Color(hex: "FFB257")

        // Glass surface tokens — subtle lightening on dark, subtle darkening on
        // light (the `--line-rgb` base), so hairlines/fills stay visible in both.
        static let glassFill        = Color(light: line(0.04), dark: Color.white.opacity(0.05))
        static let glassFillRaised   = Color(light: line(0.05), dark: Color.white.opacity(0.06))
        static let glassStroke      = Color(light: line(0.08), dark: Color.white.opacity(0.10))
        static let glassStrokeStrong = Color(light: line(0.12), dark: Color.white.opacity(0.14))
        static let glassHighlight   = Color(light: line(0.05), dark: Color.white.opacity(0.14))
    }

    // MARK: - The orb gradient (shared by every Focus Orb instance)

    /// Matte sphere fill (Zenly Matte spec): a solid blue sphere lit from the
    /// upper-left, no transparent falloff. `endRadius` scales with the orb so the
    /// 212pt home orb and 320pt session orb fill consistently.
    static func orbGradient(diameter: CGFloat) -> RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: Color(hex: "9FD4FF"), location: 0.0),
                .init(color: Color(hex: "2E8CFF"), location: 0.22),
                .init(color: Color(hex: "1A3FA8"), location: 0.52),
                .init(color: Color(hex: "13294D"), location: 0.80),
                .init(color: Color(hex: "0C1430"), location: 1.0)
            ]),
            center: UnitPoint(x: 0.38, y: 0.30),
            startRadius: 0,
            endRadius: diameter * 0.72
        )
    }

    // MARK: - Typography (Apple system fonts: SF Pro Rounded display/numerals · SF Pro body)

    enum Font {
        /// Big numerals (timer, stats, score) — SF Pro Rounded, monospaced digits
        /// so the live timer doesn't shift width as digits change.
        static func numeral(_ size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .rounded).monospacedDigit()
        }
        /// Headings / titles — SF Pro Rounded.
        static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .bold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        /// Body / labels — standard SF (San Francisco).
        static func body(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
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
