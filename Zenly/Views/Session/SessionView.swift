//
//  SessionView.swift
//  Zenly
//
//  Full-screen, immersive session timer with a single end action. During focus,
//  strict mode routes "End early" through the 5-second confirmation gate.
//
//  Redesign: the breathing Focus Orb with a progress ring of light on the warmer
//  session aurora (Claude Design spec, Zenly.dc.html). Logic unchanged.
//

import SwiftUI

struct SessionView: View {
    @Environment(FocusSessionController.self) private var session
    @State private var showStopConfirmation = false

    /// Dismiss the full-screen timer without ending the session.
    var onMinimize: () -> Void = {}

    private var tint: Color { Color(hex: session.accentHex) }
    private var isBreak: Bool { session.phase == .breakTime }
    private var ringTint: Color { isBreak ? ZTheme.Palette.teal : ZTheme.Palette.brandGlow }
    private var percent: Int { Int((max(0, min(1, session.progress)) * 100).rounded()) }

    var body: some View {
        ZStack {
            ZenlyBackground(variant: .session, calm: true)

            VStack(spacing: 0) {
                HStack {
                    GlassIconButton(systemImage: "chevron.down", action: onMinimize)
                        .accessibilityLabel("Minimize timer")
                    Spacer()
                }
                .padding(.horizontal, ZTheme.Spacing.xl)
                .padding(.top, 12)

                Spacer()

                VStack(spacing: 30) {
                    VStack(spacing: 5) {
                        Text(isBreak ? "BREAK" : "FOCUSING")
                            .font(ZTheme.Font.body(13, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(ringTint)
                        Text(isBreak ? "Recharge" : session.profileName)
                            .font(ZTheme.Font.display(22, weight: .semibold))
                            .foregroundStyle(ZTheme.Palette.textPrimary)
                    }

                    FocusOrb(state: .active(progress: session.progress),
                             diameter: 300, ringTint: ringTint, living: false) {
                        VStack(spacing: 8) {
                            Text(session.timeString)
                                .font(ZTheme.Font.numeral(64, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                            Text(isBreak ? "until focus" : "\(percent)% complete")
                                .font(ZTheme.Font.body(13, weight: .semibold))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(isBreak ? "Break time remaining" : "Focus time remaining")
                    .accessibilityValue(session.timeString)

                    Text(isBreak ? "Take a breath. Focus resumes soon." : "Stay with it. You're doing great.")
                        .font(ZTheme.Font.body(17, weight: .medium))
                        .foregroundStyle(ZTheme.Palette.text(0.6))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button(role: .destructive, action: endTapped) {
                    Text(isBreak ? "End break" : "End early")
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.zenlySecondary)
                .fixedSize()
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showStopConfirmation) {
            StopBlockingConfirmation(
                onConfirm: {
                    showStopConfirmation = false
                    session.endEarly()
                },
                onCancel: { showStopConfirmation = false }
            )
        }
    }

    private func endTapped() {
        if session.strictLockActive {
            showStopConfirmation = true
        } else {
            session.endEarly()
        }
    }
}
