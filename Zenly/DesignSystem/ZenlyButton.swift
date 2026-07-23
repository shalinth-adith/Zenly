//
//  ZenlyButton.swift
//  Zenly
//
//  Two button styles from the Quiet spec: a flat "primary" (a solid fill of the
//  active profile's tone with dark ink on top — the single bright element, the
//  one thing to do next) and a "secondary" ghost (transparent, hairline border,
//  ink text). Both press with a spring + a gentle haptic.
//
//  Imported from the Claude Design spec (Zenly Quiet.dc.html — the Begin focus /
//  Done CTA: background:var(--tone); color:#0A0B0E; radius 16; weight 600; flat).
//

import SwiftUI

struct ZenlyPrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 56
    /// The single accent — the active profile's tone.
    var tint: Color = ZTheme.Palette.tone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ZTheme.Font.display(16, weight: .semibold))
            // Dark ink on the bright tone — the tones are light enough that a
            // near-black label reads cleanly (spec: color:#0A0B0E).
            .foregroundStyle(Color(hex: "0A0B0E"))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                // Flat, solid tone — no gradient, no highlight, no outer glow.
                RoundedRectangle(cornerRadius: ZTheme.Radius.button, style: .continuous)
                    .fill(tint)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(ZTheme.Motion.bouncy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.light() }
            }
    }
}

struct ZenlySecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ZTheme.Font.display(15, weight: .medium))
            .foregroundStyle(ZTheme.Palette.text(0.85))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                // Ghost: no fill, just a hairline — recedes so the primary is
                // the only bright thing on screen.
                RoundedRectangle(cornerRadius: ZTheme.Radius.button, style: .continuous)
                    .strokeBorder(ZTheme.Palette.matteBorderStrong, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ZTheme.Motion.bouncy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.light() }
            }
    }
}

extension ButtonStyle where Self == ZenlyPrimaryButtonStyle {
    static var zenlyPrimary: ZenlyPrimaryButtonStyle { ZenlyPrimaryButtonStyle() }
    static func zenlyPrimary(tint: Color, height: CGFloat = 56) -> ZenlyPrimaryButtonStyle {
        ZenlyPrimaryButtonStyle(height: height, tint: tint)
    }
}

extension ButtonStyle where Self == ZenlySecondaryButtonStyle {
    static var zenlySecondary: ZenlySecondaryButtonStyle { ZenlySecondaryButtonStyle() }
}
