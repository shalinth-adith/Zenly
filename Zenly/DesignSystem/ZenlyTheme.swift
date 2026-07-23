//
//  ZenlyTheme.swift
//  Zenly
//
//  Single source of truth for the "Quiet" visual language — imported from the
//  Claude Design spec (Zenly Quiet.dc.html): "Quiet dark, one bright intent. A
//  space that helps you concentrate, not one that competes for attention.
//  Neutral throughout, with a single highlight — the active profile's tone —
//  reserved for the one thing to do next."
//
//  The app follows the system appearance (no in-app toggle): canvas, screen,
//  ink and hairline tokens resolve light/dark per the OS setting via the
//  `Color(lightHex:darkHex:)` / `Color(light:dark:)` helpers in Color+Hex.swift.
//  Every surface is a neutral grey. The ONLY chromatic accent is the active
//  profile's `tone`, threaded through the app as a `tint:` — see `tone(forHex:)`.
//

import SwiftUI

enum ZTheme {

    // MARK: - Palette (Zenly Quiet spec — neutral surfaces + one profile tone)

    enum Palette {
        // Neutral backgrounds (design `--bg` / `--canvas`). Warm near-black in
        // dark, warm off-white in light — no blue cast anywhere.
        /// Screen background base (design `--bg`).
        static let night       = Color(lightHex: "F3F3F0", darkHex: "0A0B0E")
        /// Outermost backdrop behind every screen (design `--canvas`).
        static let nightDeep   = Color(lightHex: "E7E7E3", darkHex: "07080A")
        /// Retained aliases (no aurora in Quiet); resolve to the screen base.
        static let auroraTop   = Color(lightHex: "F3F3F0", darkHex: "0A0B0E")
        static let sessionTop  = Color(lightHex: "F3F3F0", darkHex: "0A0B0E")

        // The single accent = the active profile's tone. Default = Work
        // (periwinkle #7C93E8). Everything that used to be "brand blue" now
        // resolves to this quiet periwinkle so no loud blue survives; per-profile
        // screens override with `tint:` from `profile.accentHex`.
        static let tone        = Color(hex: "7C93E8")
        static let brand       = tone
        static let brandLight  = tone
        static let brandGlow   = tone
        /// Interactive TEXT / icon accent. On light the periwinkle is darkened a
        /// step so it clears contrast on the near-white surface.
        static let brandBright = Color(lightHex: "5566C9", darkHex: "9AA9EE")

        /// Folded to the single tone — kept for source compatibility.
        static let violet      = tone
        static let teal        = Color(hex: "7FBE9A")   // gym tone, used sparingly

        /// Orb halo tones (superseded by `tone` in the Quiet orb) — kept defined.
        static let lavender    = tone
        static let lavenderSoft = tone
        static let orbMid      = Color(hex: "16171B")

        // Surface tokens (Quiet cards — a barely-raised neutral fill + a thin
        // hairline; depth is a hint, not a slab). `--raise` over `--bg`.
        static let matte             = Color(lightHex: "FFFFFF", darkHex: "121317")
        static let matteRaised       = Color(lightHex: "FCFCFA", darkHex: "16171C")
        static let matteBorder       = Color(light: line(0.10), dark: Color.white.opacity(0.07))
        static let matteBorderStrong = Color(light: line(0.14), dark: Color.white.opacity(0.12))

        /// Hairline/overlay base for light mode (design `--line` = pure black).
        private static func line(_ opacity: Double) -> Color { Color.black.opacity(opacity) }

        /// Text (design `--ink` / `--ink-2` / `--ink-3`).
        static let textPrimary = Color(lightHex: "16171B", darkHex: "E7E8EC")
        static func text(_ opacity: Double) -> Color { textPrimary.opacity(opacity) }

        /// Semantic warm accent (streak). Muted to sit in the Quiet palette.
        static let streak      = Color(hex: "D6A85C")
        static let streakWarm  = Color(hex: "D6A85C")

        // Subtle fills/strokes (design `--raise` / `--line` / `--line-2`).
        static let glassFill        = Color(light: line(0.04), dark: Color.white.opacity(0.035))
        static let glassFillRaised   = Color(light: line(0.05), dark: Color.white.opacity(0.05))
        static let glassStroke      = Color(light: line(0.08), dark: Color.white.opacity(0.07))
        static let glassStrokeStrong = Color(light: line(0.12), dark: Color.white.opacity(0.12))
        static let glassHighlight   = Color(light: line(0.05), dark: Color.white.opacity(0.10))
    }

    // MARK: - Profile tones (the single accent, one per profile)

    /// Map an arbitrary stored `accentHex` onto the Quiet tone palette. New
    /// profiles seed the exact Quiet hexes; this also nudges the legacy Matte
    /// defaults (blue/green/orange) onto their quiet equivalents so existing
    /// installs pick up the muted look without a data migration.
    static func tone(forHex hex: String?) -> Color {
        switch (hex ?? "").uppercased() {
        case "1A3FA8", "5C6BFA", "244FC4": return Color(hex: "7C93E8")  // → Work periwinkle
        case "34C759", "30D158":           return Color(hex: "7FBE9A")  // → Gym-ish green
        case "FF9F0A", "FF9F40", "FFB257": return Color(hex: "D6A85C")  // → Study amber
        case "":                           return Palette.tone
        default:                           return Color(hex: hex!)
        }
    }

    // MARK: - The orb halo (Quiet spec: a soft tone glow, no sphere)

    /// A soft radial glow of the active tone (`radial-gradient(circle at 50% 45%,
    /// tone-glow, transparent 68%)`). Scales with the orb diameter.
    static func orbHalo(tone: Color, diameter: CGFloat) -> RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: tone.opacity(0.30), location: 0.0),
                .init(color: tone.opacity(0.16), location: 0.42),
                .init(color: .clear, location: 0.68)
            ]),
            center: UnitPoint(x: 0.5, y: 0.45),
            startRadius: 0,
            endRadius: diameter * 0.5
        )
    }

    // MARK: - Typography (Apple system fonts, calm two-weight scale)

    enum Font {
        /// Big numerals (timer, stats) — clean SF (not rounded), light weight and
        /// monospaced digits so the live timer doesn't shift width. "Gentle."
        static func numeral(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default).monospacedDigit()
        }
        /// Headings / titles — "Gentle titles": SF, medium weight, not bold.
        static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .medium) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }
        /// Body / supporting labels — standard SF (San Francisco).
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
        static let chip: CGFloat = 14
        static let card: CGFloat = 18
        static let sheet: CGFloat = 24
        static let button: CGFloat = 16
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
