//
//  ZenlyComponents.swift
//  Zenly
//
//  Small shared building blocks for the redesign: selectable pills (profile &
//  ambient-sound rows), stat tiles, and a section header. Each carries the
//  selected-state glow from the design spec (Zenly.dc.html).
//

import SwiftUI

/// A glass pill that lights up with a periwinkle border + fill when selected.
/// Used for the profile picker and the ambient-sound row.
struct SelectablePill<Label: View>: View {
    var isSelected: Bool
    var height: CGFloat = 48
    var tint: Color = ZTheme.Palette.brand
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            label()
                .font(ZTheme.Font.display(15, weight: .medium))
                // Selected text takes the tone; unselected stays quiet ink.
                .foregroundStyle(isSelected ? tint : ZTheme.Palette.text(0.7))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(
                    // Soft tone wash when selected (design `--tone-soft`), else
                    // the neutral card surface.
                    RoundedRectangle(cornerRadius: ZTheme.Radius.chip, style: .continuous)
                        .fill(isSelected ? tint.opacity(0.16) : ZTheme.Palette.matte)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ZTheme.Radius.chip, style: .continuous)
                        .strokeBorder(isSelected ? tint.opacity(0.5) : ZTheme.Palette.matteBorder,
                                      lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(ZTheme.Motion.smooth, value: isSelected)
    }
}

/// A glass stat tile: icon + label up top, big rounded numeral below.
struct StatTile: View {
    var value: String
    var label: String
    var systemImage: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: ZTheme.Spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                Text(label)
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
            }
            Text(value)
                .font(ZTheme.Font.numeral(30, weight: .bold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

/// A left-aligned section header in the brand display face.
struct ZenlySectionHeader: View {
    var title: String
    var body: some View {
        Text(title)
            .font(ZTheme.Font.display(15, weight: .semibold))
            .foregroundStyle(ZTheme.Palette.text(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A round glass icon button (toolbar / minimize / stepper chrome).
struct GlassIconButton: View {
    var systemImage: String
    var size: CGFloat = 44
    var corner: CGFloat = 14
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(ZTheme.Palette.text(0.8))
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(ZTheme.Palette.matteRaised)
                        .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(ZTheme.Palette.matteBorder, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}
