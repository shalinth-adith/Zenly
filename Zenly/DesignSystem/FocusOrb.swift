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

    private var showLiving: Bool { living && !reduceMotion }

    var body: some View {
        ZStack {
            // Living: expanding pulse rings (outermost) + a slow conic glow.
            if showLiving && diameter >= 150 {
                PulseRings(diameter: diameter)
                ConicSpinGlow(diameter: diameter * 0.87)
            }

            // Glow halo (sits behind the sphere).
            Circle()
                .fill(ZTheme.Palette.brand)
                .frame(width: diameter * 0.92, height: diameter * 0.92)
                .blur(radius: diameter * 0.28)
                .opacity(0.45)

            // The sphere.
            Circle()
                .fill(ZTheme.orbGradient)
                .overlay(
                    // Specular highlight (top-left).
                    Circle()
                        .fill(
                            RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.65), .clear]),
                                           center: .center, startRadius: 0, endRadius: diameter * 0.16)
                        )
                        .frame(width: diameter * 0.28, height: diameter * 0.28)
                        .blur(radius: 6)
                        .offset(x: -diameter * 0.16, y: -diameter * 0.20)
                )
                .frame(width: sphereInset, height: sphereInset)

            // Active progress ring.
            if case let .active(progress) = state {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 9)
                    .frame(width: diameter - 10, height: diameter - 10)
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(ringTint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: diameter - 10, height: diameter - 10)
                    .shadow(color: ringTint.opacity(0.9), radius: 8)
                    .animation(.linear(duration: 0.3), value: progress)
            }

            center()

            // Living: two counter-rotating sparks orbiting the rim.
            if showLiving && diameter >= 170 {
                OrbitingSpark(diameter: diameter, dotSize: 9,
                              color: ZTheme.Palette.lavenderSoft, duration: 9)
                OrbitingSpark(diameter: diameter * 0.82, dotSize: 6,
                              color: ZTheme.Palette.teal, duration: 7, reversed: true)
            }
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(scale)
        .onAppear { startAnimations() }
        .onChange(of: isComplete) { _, complete in if complete { pop() } }
        .accessibilityElement(children: .combine)
    }

    // The sphere is slightly inset for the active state so the ring clears it.
    private var sphereInset: CGFloat {
        if case .active = state { return diameter - 24 }
        return diameter
    }

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
