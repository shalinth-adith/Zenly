//
//  OnboardingView.swift
//  Zenly
//
//  First-run flow. Pre-sells the Screen Time permission (what it's for + privacy)
//  on a screen we control, then triggers the real system prompt — so users
//  arrive at the prompt primed to allow it.
//
//  Redesign: the aurora + breathing Focus Orb with glass cards and the primary
//  glow button (Claude Design spec, Zenly.dc.html). Logic unchanged.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AuthorizationService.self) private var authorization

    var onComplete: () -> Void

    @State private var step = 0
    @State private var requesting = false

    var body: some View {
        ZStack {
            ZenlyBackground()

            TabView(selection: $step) {
                infoPage(icon: "scope",
                         title: "Welcome to Zenly",
                         message: "Block distractions and reclaim your focus, one session at a time.",
                         button: "Get Started", advancesTo: 1)
                    .tag(0)

                infoPage(icon: "timer",
                         title: "Focus, your way",
                         message: "Start a focus session and Zenly blocks distracting apps and websites until your timer ends.",
                         button: "Next", advancesTo: 2)
                    .tag(1)

                infoPage(icon: "flame.fill",
                         title: "Build the habit",
                         message: "Earn streaks, unlock badges, and watch your focused time add up.",
                         button: "Next", advancesTo: 3)
                    .tag(2)

                permissionPage.tag(3)
                donePage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut, value: step)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Pages

    private func infoPage(icon: String, title: String, message: String,
                          button: String, advancesTo next: Int) -> some View {
        scaffold(icon: icon, title: title, message: message) {
            Button(button) { withAnimation { step = next } }
                .buttonStyle(.zenlyPrimary)
        }
    }

    private var permissionPage: some View {
        scaffold(icon: "hand.raised.fill",
                 title: "Screen Time Access",
                 message: "Zenly uses Apple's Screen Time to block distracting apps during focus. Your activity stays private on your device — Zenly never sees it.") {
            VStack(spacing: 12) {
                Button(action: requestAccess) {
                    HStack {
                        Text(authorization.isAuthorized ? "Access Granted" : "Grant Screen Time Access")
                        if requesting { ProgressView().tint(.white).padding(.leading, 4) }
                    }
                }
                .buttonStyle(.zenlyPrimary)
                .disabled(requesting || authorization.isAuthorized)
                .opacity(requesting || authorization.isAuthorized ? 0.6 : 1)

                Button(authorization.isAuthorized ? "Continue" : "Maybe later") {
                    withAnimation { step = 4 }
                }
                .font(ZTheme.Font.display(16, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.text(0.55))
            }
        }
    }

    private var donePage: some View {
        scaffold(icon: "checkmark.seal.fill",
                 title: "You're all set",
                 message: "Pick a profile, set your timer, and start your first focus session.") {
            Button("Start Focusing", action: onComplete)
                .buttonStyle(.zenlyPrimary)
        }
    }

    // MARK: - Helpers

    private func requestAccess() {
        requesting = true
        Task {
            await authorization.requestAuthorization()
            requesting = false
            withAnimation { step = 4 }
        }
    }

    private func scaffold<Buttons: View>(icon: String, title: String, message: String,
                                         @ViewBuilder buttons: () -> Buttons) -> some View {
        VStack(spacing: ZTheme.Spacing.xl) {
            Spacer()
            FocusOrb(state: .idle, diameter: 160) {
                Image(systemName: icon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.white)
            }
            Text(title)
                .font(ZTheme.Font.display(34, weight: .bold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(ZTheme.Font.body(16))
                .foregroundStyle(ZTheme.Palette.text(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            buttons()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
            Spacer().frame(height: 60)
        }
        .padding()
    }
}
