//
//  SplashView.swift
//  Zenly
//
//  Quiet entry screen (Claude Design spec, Zenly Quiet Entry.dc.html):
//  a single point of focus breathes in, the ring settles, the name arrives
//  quietly. No splash of color, no motion competing for attention. Plays
//  once, then crossfades into the app. Tap anywhere to begin immediately.
//  Honors Reduce Motion.
//

import SwiftUI

struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ProfileStore.self) private var profiles

    @State private var glowIn = false       // tone glow breathes in (scale .6 → 1)
    @State private var breathing = false    // settled glow keeps a gentle 1 → 1.04 breathe
    @State private var dotIn = false        // focus point pops in
    @State private var ringDrawn = false    // ring draws once (trim 0 → 1)
    @State private var wordIn = false       // wordmark rises + fades
    @State private var subIn = false        // subtitle rises + fades
    @State private var ctaIn = false        // "tap to begin" fades in
    @State private var finished = false

    /// The single accent — the active profile's tone (design `--tone`).
    private var tone: Color { ZTheme.tone(forHex: profiles.activeProfile?.accentHex) }

    var body: some View {
        ZStack {
            ZenlyBackground()

            VStack(spacing: 0) {
                stage
                wordmark.padding(.top, 36)
            }

            cta
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 60)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Zen-ly. A calm and simple way to stay focused.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to begin")
        .onAppear(perform: animate)
    }

    // MARK: - Stage (glow + ring + focus point)

    private var stage: some View {
        ZStack {
            // Breathing tone glow (design: 220px radial, tone-glow → transparent 66%)
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: tone.opacity(0.30), location: 0.0),
                        .init(color: .clear, location: 0.66)
                    ]),
                    center: UnitPoint(x: 0.5, y: 0.48),
                    startRadius: 0, endRadius: 110))
                .frame(width: 220, height: 220)
                .scaleEffect((glowIn ? 1 : 0.6) * (breathing ? 1.04 : 1))
                .opacity(glowIn ? 1 : 0)

            // Ring drawing once (design: r 85 in 192 box, 1.5 stroke, round cap)
            Circle()
                .trim(from: 0, to: ringDrawn ? 1 : 0)
                .stroke(tone, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 170, height: 170)
                .opacity(ringDrawn ? 0.9 : 0)

            // Focus point
            Circle()
                .fill(tone)
                .frame(width: 14, height: 14)
                .scaleEffect(dotIn ? 1 : 0.001)
                .opacity(dotIn ? 1 : 0)
        }
        .frame(width: 260, height: 260)
    }

    // MARK: - Wordmark + CTA

    private var wordmark: some View {
        VStack(spacing: 6) {
            Text("Zen-ly")
                .font(.system(size: 34, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .opacity(wordIn ? 1 : 0)
                .offset(y: wordIn ? 0 : 8)
            // The Zen-ly signature line.
            Text("A calm and simple way to stay focused.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(ZTheme.Palette.text(0.55))
                .multilineTextAlignment(.center)
                .opacity(subIn ? 1 : 0)
                .offset(y: subIn ? 0 : 6)
        }
    }

    private var cta: some View {
        Text("Tap to begin")
            .font(.system(size: 12, weight: .regular))
            .tracking(1.7)
            .textCase(.uppercase)
            .foregroundStyle(ZTheme.Palette.text(0.30))
            .opacity(ctaIn ? 1 : 0)
            .offset(y: ctaIn ? 0 : 6)
    }

    // MARK: - Timeline

    private func animate() {
        guard !reduceMotion else {
            glowIn = true; dotIn = true; ringDrawn = true
            wordIn = true; subIn = true; ctaIn = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: finish)
            return
        }
        // Transcribed from the design's 8s cycle, compressed to a one-shot
        // entrance: glow breathes in, the dot pops, the ring draws and settles,
        // then the name and CTA arrive quietly.
        withAnimation(.easeOut(duration: 1.1)) { glowIn = true }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.25)) { dotIn = true }
        withAnimation(.easeInOut(duration: 1.3).delay(0.45)) { ringDrawn = true }
        withAnimation(.easeOut(duration: 0.55).delay(1.5)) { wordIn = true }
        withAnimation(.easeOut(duration: 0.55).delay(1.9)) { subIn = true }
        withAnimation(.easeOut(duration: 0.5).delay(2.4)) { ctaIn = true }
        // Once settled, the glow keeps a gentle breathe until the crossfade.
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(1.2)) {
            breathing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6, execute: finish)
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

#Preview {
    SplashView(onFinish: {})
        .environment(ProfileStore())
}
