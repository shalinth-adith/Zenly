//
//  SplashView.swift
//  Zenly
//
//  Animated entry screen. The drifting aurora with the breathing Focus Orb and a
//  rising wordmark — then calls onFinish to reveal the app. (Redesign: matches
//  the Claude Design spec, Zenly.dc.html.)
//

import SwiftUI

struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var textIn = false

    var body: some View {
        ZStack {
            ZenlyBackground()

            VStack(spacing: 26) {
                FocusOrb(state: .idle, diameter: 196) {
                    // A faint ring mark inside the orb (echoes the app's "scope" identity).
                    Circle()
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5)
                        .frame(width: 58, height: 58)
                        .shadow(color: .white.opacity(0.4), radius: 8)
                }

                VStack(spacing: 6) {
                    ShimmerText(text: "Zenly", font: ZTheme.Font.display(46, weight: .bold))
                    Text("Focus that feels alive.")
                        .font(ZTheme.Font.body(19, weight: .medium))
                        .foregroundStyle(ZTheme.Palette.text(0.62))
                }
                .opacity(textIn ? 1 : 0)
                .offset(y: textIn ? 0 : 14)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Zenly. Find your focus.")
        .onAppear(perform: animate)
    }

    private func animate() {
        if reduceMotion {
            textIn = true
        } else {
            withAnimation(.easeOut(duration: 0.6).delay(0.35)) { textIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { onFinish() }
    }
}

#Preview {
    SplashView(onFinish: {})
}
