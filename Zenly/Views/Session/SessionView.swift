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
    /// The app a shield stood in front of in the last few minutes, if any.
    @State private var paused: (name: String, at: Date)?

    /// Dismiss the full-screen timer without ending the session.
    var onMinimize: () -> Void = {}

    private var tint: Color { ZTheme.tone(forHex: session.accentHex) }
    private var isBreak: Bool { session.phase == .breakTime }

    /// "Focusing · Work", or the state the session is actually in.
    private var eyebrow: String {
        if isBreak { return "BREAK" }
        if session.isPaused { return "HELD · \(session.profileName.uppercased())" }
        return "FOCUSING · \(session.profileName.uppercased())"
    }

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

                VStack(spacing: 0) {
                    // "Focusing · Work" — one quiet tracked line, not a heading
                    // stack. The screen's subject is the number, not the label.
                    Text(eyebrow)
                        .font(ZTheme.Font.body(11))
                        .tracking(3.08)                    // .28em at 11pt
                        .foregroundStyle(ZTheme.Palette.text(0.55))
                        .padding(.bottom, 44)

                    FocusOrb(state: .active(progress: session.progress),
                             diameter: 300, ringTint: tint, living: false) {
                        VStack(spacing: 10) {
                            Text(session.timeString)
                                .font(ZTheme.Font.numeral(62, weight: .regular))
                                .monospacedDigit()
                                .foregroundStyle(ZTheme.Palette.textPrimary)
                            Text(session.isPaused ? "HELD" : "REMAINING")
                                .font(ZTheme.Font.body(11))
                                .tracking(2.64)            // .24em at 11pt
                                .foregroundStyle(ZTheme.Palette.text(0.55))
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(isBreak ? "Break time remaining" : "Focus time remaining")
                    .accessibilityValue(session.timeString)

                    Text(sessionMessage)
                        .font(ZTheme.Font.body(15))
                        .foregroundStyle(ZTheme.Palette.text(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.top, 44)
                }

                Spacer()

                VStack(spacing: 10) {
                    // Pausing is only offered when the session isn't strict —
                    // strict exists so a session can't be wriggled out of, and
                    // an open-ended pause would be exactly that.
                    if !isBreak && !session.strictLockActive {
                        QuietCircleButton(systemImage: session.isPaused ? "play.fill" : "pause.fill",
                                          label: session.isPaused ? "Resume session" : "Pause session") {
                            session.isPaused ? session.resume() : session.pause()
                        }
                        .accessibilityIdentifier("session-pause")
                    }

                    if session.strictLockActive {
                        // Strict keeps its own gate: a deliberate confirmation
                        // rather than a hold anyone could complete distractedly.
                        Button("End early", action: endTapped)
                            .font(ZTheme.Font.body(14))
                            .foregroundStyle(ZTheme.Palette.text(0.30))
                            .buttonStyle(.plain)
                            .padding(10)
                    } else {
                        QuietHoldToEnd(tone: tint,
                                       idleLabel: isBreak ? "Hold to end the break" : "Hold to end early",
                                       action: endTapped)
                    }
                }
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
        // Quiet spec screen 03b — what the app says when you come back from the
        // block screen having tapped "Back to focus". See `AppPausedView`.
        .overlay {
            if let paused {
                AppPausedView(subject: paused.name,
                              tone: tint,
                              remaining: session.timeString,
                              onDismiss: dismissPaused)
                    .transition(.opacity)
            }
        }
        .animation(ZTheme.Motion.smooth, value: paused?.at)
        .onAppear(perform: refreshPaused)
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification)) { _ in refreshPaused() }
    }

    // MARK: - 03b · Back to focus

    private func refreshPaused() {
        // Only while something is actually being blocked. A held session has no
        // shields up, so there is nothing to have been stopped by.
        guard session.phase == .focus, !session.isPaused else {
            paused = nil
            return
        }
        paused = PausedApp.pending()
    }

    private func dismissPaused() {
        PausedApp.markSeen()
        paused = nil
    }

    private var sessionMessage: String {
        if session.isPaused { return "Held for you. Nothing is blocked while you\u{2019}re away." }
        return isBreak ? "Take a breath." : "Stay with it."
    }

    private func endTapped() {
        if session.strictLockActive {
            showStopConfirmation = true
        } else {
            session.endEarly()
        }
    }
}
