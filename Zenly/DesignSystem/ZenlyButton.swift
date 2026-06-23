//
//  ZenlyButton.swift
//  Zenly
//
//  Two button styles from the design spec: a filled periwinkle "primary" with an
//  outer glow, and a frosted "secondary" glass button. Both press with a spring
//  (scale on tap) + a gentle haptic. Periwinkle is the only accent.
//
//  Imported from the Claude Design spec (Zenly.dc.html).
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
                RoundedRectangle(cornerRadius: ZTheme.Radius.button, style: .continuous)
                    .fill(LinearGradient(colors: [ZTheme.Palette.brandLight, tint],
                                         startPoint: .top, endPoint: .bottom))
                    .livingSweep()
                    .clipShape(RoundedRectangle(cornerRadius: ZTheme.Radius.button, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ZTheme.Radius.button, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: tint.opacity(0.5), radius: 18, x: 0, y: 8)
            .shadow(color: tint.opacity(0.32), radius: 30)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
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
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: ZTheme.Radius.chip, style: .continuous)
                        .fill(ZTheme.Palette.glassFillRaised))
                    .overlay(RoundedRectangle(cornerRadius: ZTheme.Radius.chip, style: .continuous)
                        .strokeBorder(ZTheme.Palette.glassStrokeStrong, lineWidth: 1))
                    .environment(\.colorScheme, .dark)
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
