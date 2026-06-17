//
//  HomeView.swift
//  Zenly
//
//  The hub: pick the active profile, see today's streak, and start a focus
//  session. Presents the full-screen Session / Summary flow while one is active.
//

import SwiftUI

struct HomeView: View {
    @Environment(ProfileStore.self) private var profiles
    @Environment(FocusSessionController.self) private var session
    @Environment(AuthorizationService.self) private var authorization
    @Environment(AnalyticsService.self) private var analytics

    @State private var streak = 0
    @State private var todayMinutes = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if !authorization.isAuthorized {
                        permissionCard
                    }
                    profilePicker
                    ringSection
                    statsRow
                }
                .padding()
            }
            .navigationTitle("Zenly")
            .task { await prepare() }
            .onChange(of: session.phase) { _, newPhase in
                if newPhase == .idle { refreshStats() }
            }
            .fullScreenCover(isPresented: presentingSession) {
                switch session.phase {
                case .focus, .breakTime: SessionView()
                case .summary: SessionSummaryView()
                case .idle: Color.clear
                }
            }
        }
    }

    private var presentingSession: Binding<Bool> {
        Binding(get: { session.phase != .idle }, set: { _ in })
    }

    private var activeProfile: FocusProfile? { profiles.activeProfile }
    private var tint: Color { Color(hex: activeProfile?.accentHex ?? "5C6BFA") }

    // MARK: - Sections

    private var permissionCard: some View {
        VStack(spacing: 12) {
            Label("Screen Time access needed", systemImage: "hand.raised.fill")
                .font(.headline)
            Text("Zenly needs Screen Time access to block distracting apps during focus.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Grant Access") {
                Task { await authorization.requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private var profilePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(profiles.profiles, id: \.objectID) { profile in
                    let isActive = profile.id == profiles.activeProfileID
                    HStack(spacing: 8) {
                        Image(systemName: profile.iconName ?? "brain.head.profile")
                        Text(profile.name ?? "Untitled")
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(isActive ? .white : .primary)
                    .background(
                        isActive ? Color(hex: profile.accentHex ?? "5C6BFA") : Color(.secondarySystemFill),
                        in: Capsule()
                    )
                    .onTapGesture { profiles.setActive(profile) }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var ringSection: some View {
        VStack(spacing: 24) {
            ZStack {
                TimerRing(progress: 0, tint: tint)
                VStack(spacing: 4) {
                    Text("\(Int(activeProfile?.focusMinutes ?? 25)) min")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    Text(activeProfile?.name ?? "Focus")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 240, height: 240)

            Button(action: startFocus) {
                Label("Start Focus", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(tint)
            .disabled(activeProfile == nil || !authorization.isAuthorized)
            .padding(.horizontal, 24)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statCard(value: "\(streak)", label: "day streak", systemImage: "flame.fill", color: .orange)
            statCard(value: "\(todayMinutes)", label: "min today", systemImage: "clock.fill", color: .blue)
        }
    }

    private func statCard(value: String, label: String, systemImage: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions

    private func prepare() async {
        await NotificationService.shared.requestAuthorization()
        refreshStats()
    }

    private func refreshStats() {
        streak = session.currentStreak()
        todayMinutes = session.todayFocusMinutes()
        analytics.updateSnapshot()
    }

    private func startFocus() {
        guard let profile = activeProfile else { return }
        session.startFocus(
            profileName: profile.name ?? "Focus",
            accentHex: profile.accentHex ?? "5C6BFA",
            focusMinutes: Int(profile.focusMinutes),
            breakMinutes: Int(profile.breakMinutes),
            isStrict: profile.isStrict,
            block: profiles.block(for: profile),
            allow: profiles.allow(for: profile)
        )
    }
}
