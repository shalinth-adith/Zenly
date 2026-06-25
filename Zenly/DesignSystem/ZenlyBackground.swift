//
//  ZenlyBackground.swift
//  Zenly
//
//  The signature "Living Focus" backdrop: a deep radial night base with three
//  soft, blurred aurora ribbons that wave left/right, plus a layer of slowly
//  rising glowing particles. Honors Reduce Motion (ribbons settle, particles off).
//
//  Imported from the Claude Design spec (Zenly Aurora.dc.html).
//

import SwiftUI

struct ZenlyBackground: View {
    /// `.standard` for most screens, `.session` for the warmer immersive timer.
    enum Variant { case standard, session }
    var variant: Variant = .standard
    /// Floating particle layer. Off by default — the Matte theme keeps the
    /// backdrop simple (no drifting dots); opt in explicitly if ever needed.
    var particles: Bool = false
    /// Quieter backdrop for the active focus session: fewer, softer aurora
    /// ribbons, no particles, and a dimmer tint so the breathing orb leads.
    var calm: Bool = false

    private var topTint: Color {
        let tint = variant == .session ? ZTheme.Palette.sessionTop : ZTheme.Palette.auroraTop
        return calm ? tint.opacity(0.55) : tint
    }

    private var showParticles: Bool { particles && !calm }

    var body: some View {
        ZStack {
            // Radial night base.
            RadialGradient(
                gradient: Gradient(colors: [topTint, ZTheme.Palette.night]),
                center: variant == .session ? UnitPoint(x: 0.5, y: 0.45) : UnitPoint(x: 0.5, y: 0.08),
                startRadius: 0,
                endRadius: variant == .session ? 540 : 660
            )

            // Aurora ribbons (wave drift). Calm mode keeps a single slow, faint
            // ribbon instead of three so the motion recedes during a session.
            if calm {
                WaveRibbon(colors: [.clear, ZTheme.Palette.brand, ZTheme.Palette.violet, .clear],
                           height: 240, yFraction: 0.5, opacity: 0.18, blur: 60, duration: 26)
            } else {
                WaveRibbon(colors: [.clear, ZTheme.Palette.brand, ZTheme.Palette.violet, .clear],
                           height: 230, yFraction: 0.16, opacity: 0.5, blur: 46, duration: 14)
                WaveRibbon(colors: [.clear, ZTheme.Palette.teal, ZTheme.Palette.brand, .clear],
                           height: 200, yFraction: 0.40, opacity: 0.30, blur: 50, duration: 18, reversed: true)
                WaveRibbon(colors: [.clear, ZTheme.Palette.violet, ZTheme.Palette.brand, .clear],
                           height: 240, yFraction: 0.86, opacity: 0.42, blur: 52, duration: 16)
            }

            // Rising particles.
            if showParticles {
                FloatingParticles(count: 6)
            }
        }
        .ignoresSafeArea()
        .background(ZTheme.Palette.nightDeep)
    }
}

#Preview {
    ZenlyBackground()
}
