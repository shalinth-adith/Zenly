//
//  FocusOrb.swift
//  Zenly
//
//  The emotional centerpiece of Zenly — a glowing sphere that replaces the flat
//  timer ring. Three states from the design spec:
//    • idle     — gently breathes (scale 1 → 1.055, 6s loop)
//    • active   — a progress ring of light fills around it
//    • complete — a springy "pop" with a checkmark
//
//  Imported from the Claude Design spec (Zenly.dc.html). Honors Reduce Motion.
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
    /// Accent for the progress ring (defaults to brand glow; sessions pass the profile tint).
    var ringTint: Color = ZTheme.Palette.brandGlow
    /// "Living Focus" motion layer (pulse rings, conic glow, orbiting sparks).
    var living: Bool = true
    /// Idle breathing scale loop. Set false for a fully static orb.
    var breathes: Bool = true
    @ViewBuilder var center: () -> Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SwiftUI.State private var breathing = false
    @SwiftUI.State private var popped = false

    var body: some View {
        ZStack {
            // Idle: a calm clock-style tick ring around the sphere.
            if isIdle {
                OrbTicks(diameter: diameter)
            }

            // The matte sphere: a solid blue fill lit from the upper-left, with a
            // soft inner shadow pooling toward the bottom for depth.
            Circle()
                .fill(ZTheme.orbGradient(diameter: sphereInset))
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [Color(hex: "060A1A").opacity(0.5), .clear]),
                                center: UnitPoint(x: 0.5, y: 0.56),
                                startRadius: 0,
                                endRadius: sphereInset * 0.52
                            )
                        )
                )
                .frame(width: sphereInset, height: sphereInset)

            // Active: a thin progress ring of light fills around the sphere.
            if case let .active(progress) = state {
                Circle()
                    .stroke(Color(light: Color(hex: "1C2644").opacity(0.10),
                                  dark: Color.white.opacity(0.07)), lineWidth: 9)
                    .frame(width: ringDiameter, height: ringDiameter)
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(ringTint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: ringDiameter, height: ringDiameter)
                    .shadow(color: ringTint.opacity(0.9), radius: 8)
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

    // The design always insets the sphere inside its container so the surrounding
    // ring sits in a clear gap around it (rather than the sphere covering it):
    // home/idle orb 24/212 ≈ 0.775·d, session/active orb 32/320 = 0.80·d.
    private var sphereInset: CGFloat {
        switch state {
        case .active:   return diameter * 0.80
        case .complete: return diameter           // standalone celebratory sphere
        case .idle:     return diameter * 0.775
        }
    }

    /// Progress-ring diameter — design draws it at r150 on a 320 box (0.9375·d),
    /// outside the 0.80·d sphere with a clean gap.
    private var ringDiameter: CGFloat { diameter * 0.9375 }

    private var isComplete: Bool {
        if case .complete = state { return true }
        return false
    }

    private var scale: CGFloat {
        if case .complete = state { return popped ? 1 : 0.6 }
        guard !reduceMotion else { return 1 }
        if case .idle = state { return (breathes && breathing) ? 1.055 : 1 }
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
                    .font(.system(size: diameter * 0.34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            )
        }
    }
}

/// Eight clock-style ticks ringing the idle orb (four cardinal, brighter; four
/// diagonal, dimmer), matching the Zenly Matte spec.
private struct OrbTicks: View {
    let diameter: CGFloat

    var body: some View {
        let radius = diameter / 2
        let outer = radius - diameter * 0.038
        let inner = radius - diameter * 0.090
        let length = outer - inner
        let mid = (outer + inner) / 2
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(Color(lightHex: "5C8DF5", darkHex: "8CAAFF")
                        .opacity(i.isMultiple(of: 2) ? 0.45 : 0.25))
                    .frame(width: 2.4, height: length)
                    .offset(y: -mid)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

#Preview {
    ZStack {
        ZenlyBackground()
        VStack(spacing: 40) {
            FocusOrb(state: .idle) {
                Text("25:00").font(ZTheme.Font.numeral(48)).foregroundStyle(.white)
            }
            FocusOrb(state: .active(progress: 0.6), diameter: 160) {
                Text("11:18").font(ZTheme.Font.numeral(36)).foregroundStyle(.white)
            }
        }
    }
}
