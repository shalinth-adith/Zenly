//
//  SplashView.swift
//  Zenly
//
//  Animated entry screen. Deep-indigo backdrop with the periwinkle moon mark,
//  breathing rings, and a rising wordmark — then calls onFinish to reveal the app.
//

import SwiftUI

struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var iconIn = false
    @State private var pulse = false
    @State private var textIn = false

    private let accent = Color(hex: "5C6BFA")
    private let top = Color(red: 0.05, green: 0.06, blue: 0.12)
    private let bottom = Color(red: 0.10, green: 0.09, blue: 0.20)

    var body: some View {
        ZStack {
            LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            RadialGradient(colors: [accent.opacity(0.28), .clear],
                           center: .center, startRadius: 0, endRadius: 280)
                .ignoresSafeArea()
                .opacity(iconIn ? 1 : 0)

            VStack(spacing: 26) {
                ZStack {
                    if !reduceMotion {
                        ForEach(0..<2, id: \.self) { i in
                            Circle()
                                .stroke(accent.opacity(0.45), lineWidth: 2)
                                .frame(width: 120, height: 120)
                                .scaleEffect(pulse ? 1.9 : 0.85)
                                .opacity(pulse ? 0 : 0.6)
                                .animation(
                                    .easeOut(duration: 2.2)
                                        .repeatForever(autoreverses: false)
                                        .delay(Double(i) * 1.1),
                                    value: pulse
                                )
                        }
                    }

                    Image(systemName: "scope")
                        .font(.system(size: 66, weight: .light))
                        .foregroundStyle(accent)
                        .shadow(color: accent.opacity(0.5), radius: 24)
                        .scaleEffect(iconIn ? 1 : 0.6)
                        .opacity(iconIn ? 1 : 0)
                }

                VStack(spacing: 6) {
                    Text("Zenly")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Find your focus")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
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
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) { iconIn = true }
        pulse = true
        withAnimation(.easeOut(duration: 0.6).delay(0.45)) { textIn = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { onFinish() }
    }
}

#Preview {
    SplashView(onFinish: {})
}
