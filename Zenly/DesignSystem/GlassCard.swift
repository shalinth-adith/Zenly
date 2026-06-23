//
//  GlassCard.swift
//  Zenly
//
//  Frosted-glass surface used for every card in the redesign: translucent fill,
//  faint 1px light border, soft drop shadow, inset top highlight. Depth comes
//  from blur + shadow, never heavy borders — and glass never stacks on glass.
//
//  Imported from the Claude Design spec (Zenly.dc.html).
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
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(ZTheme.Palette.glassFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [ZTheme.Palette.glassHighlight, ZTheme.Palette.glassStroke],
                                    startPoint: .top, endPoint: .bottom),
                                lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
            }
            .environment(\.colorScheme, .dark)
    }
}

extension View {
    /// Wrap content in the signature frosted-glass card.
    func glassCard(radius: CGFloat = ZTheme.Radius.card,
                   padding: CGFloat = ZTheme.Spacing.lg) -> some View {
        modifier(GlassCardModifier(radius: radius, padding: padding))
    }
}
