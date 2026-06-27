//
//  ZenlyListComponents.swift
//  Zenly
//
//  Building blocks for the list-style screens (Profiles, Schedule, Settings):
//  a glowing periwinkle toggle, a rounded tinted icon tile, and the dashed
//  "add" button — all from the Claude Design spec (Zenly.dc.html).
//

import SwiftUI

/// The design's pill toggle: a 50×30 track with a white knob and a periwinkle
/// glow when on. Drop-in replacement for the system Toggle look.
struct ZenlyToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 12)
            // A Button (not .onTapGesture) so taps are reliable inside List rows.
            Button {
                Haptics.light()
                withAnimation(ZTheme.Motion.bouncy) { configuration.isOn.toggle() }
            } label: {
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn ? ZTheme.Palette.brand : ZTheme.Palette.matteBorderStrong)
                        .frame(width: 50, height: 30)
                        .shadow(color: configuration.isOn ? ZTheme.Palette.brand.opacity(0.5) : .clear, radius: 8)
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                        .padding(.horizontal, 3)
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                }
                .frame(width: 50, height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isOn ? "On" : "Off")
        }
    }
}

extension ToggleStyle where Self == ZenlyToggleStyle {
    static var zenly: ZenlyToggleStyle { ZenlyToggleStyle() }
}

/// A rounded, tinted icon container used in list rows.
struct IconTile: View {
    var systemImage: String
    var color: Color
    var size: CGFloat = 44
    var corner: CGFloat = 14

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(color.opacity(0.18))
                .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(color.opacity(0.4), lineWidth: 1))
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

/// The dashed periwinkle "New …" / "Add …" button.
struct DashedActionButton: View {
    var title: String
    var systemImage: String = "plus"
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            HStack(spacing: 9) {
                Image(systemName: systemImage).font(.system(size: 16, weight: .bold))
                Text(title).font(ZTheme.Font.display(16, weight: .bold))
            }
            .foregroundStyle(ZTheme.Palette.brandBright)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: ZTheme.Radius.button, style: .continuous)
                    .fill(ZTheme.Palette.glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ZTheme.Radius.button, style: .continuous)
                    .strokeBorder(ZTheme.Palette.brandBright.opacity(0.5),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        }
        .buttonStyle(.plain)
    }
}

/// A large left-aligned screen title (the look the design uses on Profiles /
/// Schedule / Settings), placed above aurora-backed content.
struct ZenlyScreenTitle: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ZTheme.Font.display(28, weight: .bold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(ZTheme.Font.body(14))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
