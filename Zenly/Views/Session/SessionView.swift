//
//  SessionView.swift
//  Zenly
//
//  Full-screen, minimal session timer with a single end action. During focus,
//  strict mode routes "End early" through the 5-second confirmation gate.
//

import SwiftUI

struct SessionView: View {
    @Environment(FocusSessionController.self) private var session
    @State private var showStopConfirmation = false

    private var tint: Color { Color(hex: session.accentHex) }
    private var isBreak: Bool { session.phase == .breakTime }

    var body: some View {
        ZStack {
            tint.opacity(0.08).ignoresSafeArea()

            VStack(spacing: 40) {
                Text(isBreak ? "Break" : session.profileName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)

                ZStack {
                    TimerRing(progress: session.progress, tint: isBreak ? .green : tint)
                    VStack(spacing: 4) {
                        Text(session.timeString)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(isBreak ? "until focus" : "remaining")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 260, height: 260)

                Button(role: .destructive, action: endTapped) {
                    Text(isBreak ? "End break" : "End early")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal, 48)
            }
            .padding()
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
