//
//  FocusOrb.swift
//  Zenly
//
//  The Quiet centerpiece: NOT a glossy sphere, but a soft halo of the active
//  profile's tone glowing behind the numerals — "neutral throughout, one bright
//  intent." Three states from the Quiet spec (Zenly Quiet.dc.html):
//    • idle     — a soft tone halo, gently breathing (7s loop)
//    • active   — a thin 2px progress ring in the tone, over the halo
//    • complete — a springy "pop" with a checkmark
//
//  Honors Reduce Motion.
//

import SwiftUI

struct FocusOrb<Center: View>: View {
    enum State {
        case idle
        case active(progress: Double)
        case complete
    }

    var state: State
    var diameter: CGFloat = 212
    /// The single accent — the active profile's tone. Drives the halo and ring.
    var ringTint: Color = ZTheme.Palette.tone
    /// Retained for source compatibility (no separate motion layer in Quiet).
    var living: Bool = true
    /// Idle breathing scale loop. Set false for a fully static orb.
    var breathes: Bool = true
    @ViewBuilder var center: () -> Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SwiftUI.State private var breathing = false
    @SwiftUI.State private var popped = false

    var body: some View {
        ZStack {
            // The soft tone halo — a radial glow of the active profile's tone,
            // inset inside the box so it fades to nothing before the edge.
            Circle()
                .fill(ZTheme.orbHalo(tone: ringTint, diameter: haloInset))
                .frame(width: haloInset, height: haloInset)

            // Complete: a filled tone disc for the celebratory checkmark.
            if isComplete {
                Circle()
                    .fill(ringTint.opacity(0.9))
                    .frame(width: diameter * 0.5, height: diameter * 0.5)
            }

            // Active: a hairline track + a thin progress ring in the tone.
            if case let .active(progress) = state {
                Circle()
                    .stroke(ZTheme.Palette.matteBorder, lineWidth: 2)
                    .frame(width: ringDiameter, height: ringDiameter)
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(ringTint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: ringDiameter, height: ringDiameter)
                    .animation(.linear(duration: 0.3), value: progress)
            }

            center()
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(scale)
        .onAppear { startAnimations() }
        .onChange(of: isComplete) { _, complete in if complete { pop() } }
        .accessibilityElement(children: .combine)
    }

    private var isIdle: Bool {
        if case .idle = state { return true }
        return false
    }

    /// The halo is inset inside the box so its glow dissolves before the rim.
    private var haloInset: CGFloat { diameter * 0.92 }

    /// Progress-ring diameter — sits just inside the box edge.
    private var ringDiameter: CGFloat { diameter * 0.94 }

    private var isComplete: Bool {
        if case .complete = state { return true }
        return false
    }

    private var scale: CGFloat {
        if case .complete = state { return popped ? 1 : 0.6 }
        guard !reduceMotion else { return 1 }
        // A gentler breath than the old sphere (the halo is soft to begin with).
        if case .idle = state { return (breathes && breathing) ? 1.035 : 1 }
        return 1
    }

    private func startAnimations() {
        guard !reduceMotion else { return }
        if breathes, case .idle = state {
            withAnimation(ZTheme.Motion.breathe) { breathing = true }
        }
        if isComplete { pop() }
    }

    private func pop() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { popped = true }
    }
}

// Convenience: a complete-state orb showing a checkmark, used by the summary screen.
extension FocusOrb where Center == AnyView {
    static func completeMark(diameter: CGFloat = 128) -> FocusOrb<AnyView> {
        FocusOrb<AnyView>(state: .complete, diameter: diameter) {
            AnyView(
                Image(systemName: "checkmark")
                    .font(.system(size: diameter * 0.28, weight: .medium, design: .default))
                    .foregroundStyle(ZTheme.Palette.night)   // dark ink on the tone disc
            )
        }
    }
}

#Preview {
    ZStack {
        ZenlyBackground()
        VStack(spacing: 40) {
            FocusOrb(state: .idle) {
                Text("25").font(ZTheme.Font.numeral(72)).foregroundStyle(ZTheme.Palette.textPrimary)
            }
            FocusOrb(state: .active(progress: 0.6), diameter: 160) {
                Text("11:18").font(ZTheme.Font.numeral(36)).foregroundStyle(ZTheme.Palette.textPrimary)
            }
        }
    }
}
