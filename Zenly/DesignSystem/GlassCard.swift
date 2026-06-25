//
//  GlassCard.swift
//  Zenly
//
//  The "Zenly Matte" surface used for every card: a flat, opaque fill with a
//  thin 1px hairline border — no frosted blur, no heavy shadow. Depth comes from
//  the solid surface lifting off the near-black background, plus one soft shadow.
//
//  Imported from the Claude Design spec (Zenly Matte.dc.html). The modifier is
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
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
            }
            .environment(\.colorScheme, .dark)
    }
}

extension View {
    /// Wrap content in the signature matte card surface.
    func glassCard(radius: CGFloat = ZTheme.Radius.card,
                   padding: CGFloat = ZTheme.Spacing.lg) -> some View {
        modifier(GlassCardModifier(radius: radius, padding: padding))
    }
}
