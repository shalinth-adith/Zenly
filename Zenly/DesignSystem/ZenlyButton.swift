//
//  ZenlyButton.swift
//  Zenly
//
//  Two button styles from the design spec: a flat matte "primary" (solid blue
//  gradient with a crisp top highlight — no glow, no sweep) and a frosted
//  "secondary" glass button. Both press with a spring (scale on tap) + a gentle
//  haptic. Periwinkle is the only accent.
//
//  Imported from the Claude Design spec (Zenly Matte.dc.html — the Start Focus /
//  Done CTA: linear-gradient(180deg,#2E63E0,#1E47B0) + inset 0 1px 0
//  rgba(255,255,255,0.28), radius 18, flat).
//

import SwiftUI

struct ZenlyPrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 56
    /// Override the brand accent (e.g. an active profile's tint).
    var tint: Color = ZTheme.Palette.brand

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ZTheme.Font.display(18, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                // Flat vertical gradient — a lit top stop (tint blended toward
                // white) down to the tint. No living-sweep, no outer glow: the
                // matte surface is opaque and calm.
                RoundedRectangle(cornerRadius: ZTheme.Radius.button, style: .continuous)
                    .fill(LinearGradient(colors: [tint.lightened(0.24), tint],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                // Emulates `inset 0 1px 0 rgba(255,255,255,0.28)`: a bright top
                // edge fading down the rim.
                RoundedRectangle(cornerRadius: ZTheme.Radius.button, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.04)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
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
            .font(ZTheme.Font.display(16, weight: .semibold))
            .foregroundStyle(ZTheme.Palette.text(0.85))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: ZTheme.Radius.chip, style: .continuous)
                    .fill(ZTheme.Palette.matteRaised)
                    .overlay(RoundedRectangle(cornerRadius: ZTheme.Radius.chip, style: .continuous)
                        .strokeBorder(ZTheme.Palette.matteBorderStrong, lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
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
