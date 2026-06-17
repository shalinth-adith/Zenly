//
//  OnboardingView.swift
//  Zenly
//
//  First-run flow. Pre-sells the Screen Time permission (what it's for + privacy)
//  on a screen we control, then triggers the real system prompt — so users
//  arrive at the prompt primed to allow it.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AuthorizationService.self) private var authorization

    var onComplete: () -> Void

    @State private var step = 0
    @State private var requesting = false

    private let tint = Color(hex: "5C6BFA")

    var body: some View {
        TabView(selection: $step) {
            infoPage(icon: "moon.stars.fill",
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
        .background(tint.opacity(0.06).ignoresSafeArea())
        .animation(.easeInOut, value: step)
    }

    // MARK: - Pages

    private func infoPage(icon: String, title: String, message: String,
                          button: String, advancesTo next: Int) -> some View {
        scaffold(icon: icon, title: title, message: message) {
            Button(button) { withAnimation { step = next } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(tint)
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
                        if requesting { ProgressView().padding(.leading, 4) }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(tint)
                .disabled(requesting || authorization.isAuthorized)

                Button(authorization.isAuthorized ? "Continue" : "Maybe later") {
                    withAnimation { step = 4 }
                }
                .font(.subheadline)
            }
        }
    }

    private var donePage: some View {
        scaffold(icon: "checkmark.seal.fill",
                 title: "You're all set",
                 message: "Pick a profile, set your timer, and start your first focus session.") {
            Button("Start Focusing", action: onComplete)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(tint)
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
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(tint)
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            buttons()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
            Spacer().frame(height: 48)
        }
        .padding()
    }
}
