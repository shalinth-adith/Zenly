//
//  GlassCard.swift
//  Zenly
//
//  The Quiet card surface: a barely-raised neutral fill with a thin 1px hairline
//  — no frosted blur, no glow, and only the faintest shadow. Depth is a hint, so
//  the card recedes into the calm background rather than lifting off it.
//
//  Imported from the Claude Design spec (Zenly Quiet.dc.html). The modifier is
//  still named `glassCard()` so existing call sites convert without churn.
//

import SwiftUI

struct GlassCardModifier: ViewModifier {
    var radius: CGFloat = ZTheme.Radius.card
    var padding: CGFloat = ZTheme.Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(ZTheme.Palette.matte)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(ZTheme.Palette.matteBorder, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 2)
            }
    }
}

extension View {
    /// Wrap content in the signature matte card surface.
    func glassCard(radius: CGFloat = ZTheme.Radius.card,
                   padding: CGFloat = ZTheme.Spacing.lg) -> some View {
        modifier(GlassCardModifier(radius: radius, padding: padding))
    }
}
