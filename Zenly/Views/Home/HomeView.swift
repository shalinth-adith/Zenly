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
    @Environment(ChallengeService.self) private var challenges
    @Environment(AmbientSoundService.self) private var ambient
    @Environment(CalendarService.self) private var calendar
    @Environment(MusicController.self) private var music

    @AppStorage("dailyGoalMinutes", store: AppGroup.defaults) private var dailyGoalMinutes = 120

    @State private var streak = 0
    @State private var todayMinutes = 0
    @State private var selectedMinutes = 25
    @State private var showTasks = false
    @State private var showSession = false
    @State private var freeBlock: FreeBlock?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if session.isActive && !showSession {
                        resumeBanner
                    }
                    if !authorization.isAuthorized {
                        permissionCard
                    }
                    profilePicker
                    ringSection
                    statsRow
                    goalCard
                    challengeCard
                    if freeBlock != nil { calendarCard }
                    soundRow
                    musicRow
                }
                .padding()
            }
            .navigationTitle("Zenly")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showTasks = true } label: { Image(systemName: "checklist") }
                }
            }
            .sheet(isPresented: $showTasks) { TasksView() }
            .task { await prepare() }
            .onChange(of: session.phase) { oldPhase, newPhase in
                switch newPhase {
                case .idle:
                    showSession = false
                    refreshStats()
                case .summary:
                    showSession = true // always surface the celebration
                default:
                    if oldPhase == .idle { showSession = true } // session just started
                }
            }
            .onChange(of: profiles.activeProfileID) { _, _ in syncDuration() }
            .fullScreenCover(isPresented: $showSession) {
                switch session.phase {
                case .focus, .breakTime: SessionView(onMinimize: { showSession = false })
                case .summary: SessionSummaryView()
                case .idle: Color.clear
                }
            }
        }
    }

    private var resumeBanner: some View {
        Button { showSession = true } label: {
            HStack(spacing: 10) {
                Image(systemName: session.phase == .breakTime ? "cup.and.saucer.fill" : "timer")
                Text(session.phase == .breakTime ? "Break" : session.profileName)
                    .fontWeight(.semibold)
                Spacer()
                Text(session.timeString).monospacedDigit()
                Image(systemName: "chevron.up").font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color(hex: session.accentHex), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
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
        VStack(spacing: 20) {
            ZStack {
                TimerRing(progress: 0, tint: tint)
                VStack(spacing: 4) {
                    Text("\(selectedMinutes)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("minutes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 240, height: 240)

            durationStepper

            Button(action: startFocus) {
                Label("Start Focus", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(tint)
            .disabled(activeProfile == nil || !authorization.isAuthorized || session.isActive)
            .padding(.horizontal, 24)
        }
    }

    private var durationStepper: some View {
        HStack(spacing: 24) {
            durationButton("minus") { adjustDuration(-5) }
            VStack(spacing: 0) {
                Text("\(selectedMinutes) min")
                    .font(.headline.monospacedDigit())
                Text(activeProfile?.name ?? "Focus")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 90)
            durationButton("plus") { adjustDuration(5) }
        }
    }

    private func durationButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(Color(.secondarySystemFill), in: Circle())
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
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

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Daily Goal", systemImage: "target")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(todayMinutes) / \(dailyGoalMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(1, Double(todayMinutes) / Double(max(1, dailyGoalMinutes))))
                .tint(tint)
            if todayMinutes >= dailyGoalMinutes {
                Label("Goal reached — nice work!", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var challengeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Daily Challenge", systemImage: challenges.challenge.systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if challenges.isComplete {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            Text(challenges.challenge.title)
                .font(.headline)
            ProgressView(value: challenges.fraction)
                .tint(tint)
            Text("\(challenges.progress) / \(challenges.challenge.target)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var soundRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focus sound")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 10) {
                ForEach(AmbientSound.allCases) { sound in
                    let active = ambient.current == sound
                    Button {
                        ambient.toggle(sound)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: sound.systemImage)
                            Text(sound.title).font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(active ? .white : .primary)
                        .background(active ? tint : Color(.secondarySystemFill),
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Free time", systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
            if let block = freeBlock {
                Text("You're free until \(block.end.formatted(date: .omitted, time: .shortened)) — \(block.minutes) min.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    selectedMinutes = max(5, min(120, (block.minutes / 5) * 5))
                    startFocus()
                } label: {
                    Label("Start focus now", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(activeProfile == nil || !authorization.isAuthorized)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var musicRow: some View {
        HStack(spacing: 22) {
            Button { music.previous() } label: { Image(systemName: "backward.fill") }
            Button { music.playPause() } label: {
                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill").font(.title3)
            }
            Button { music.next() } label: { Image(systemName: "forward.fill") }
            VStack(alignment: .leading, spacing: 2) {
                Text(music.nowPlaying.isEmpty ? "Apple Music" : music.nowPlaying)
                    .font(.subheadline).lineLimit(1)
                Text("Focus music").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .buttonStyle(.plain)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions

    private func prepare() async {
        authorization.refresh() // pick up persisted Screen Time approval
        await NotificationService.shared.requestAuthorization()
        NotificationService.shared.scheduleDailyChallengeReminder()
        syncDuration()
        refreshStats()
        music.updateState()
        freeBlock = calendar.isAuthorized ? calendar.nextFreeBlock : nil
    }

    /// Reset the editable duration to the active profile's default.
    private func syncDuration() {
        if let profile = activeProfile {
            selectedMinutes = Int(profile.focusMinutes)
        }
    }

    private func adjustDuration(_ delta: Int) {
        selectedMinutes = max(5, min(120, selectedMinutes + delta))
    }

    private func refreshStats() {
        streak = session.currentStreak()
        todayMinutes = session.todayFocusMinutes()
        challenges.refresh()
        analytics.updateSnapshot()
    }

    private func startFocus() {
        guard let profile = activeProfile else { return }
        session.startFocus(
            profileName: profile.name ?? "Focus",
            accentHex: profile.accentHex ?? "5C6BFA",
            focusMinutes: selectedMinutes,
            breakMinutes: Int(profile.breakMinutes),
            isStrict: profile.isStrict,
            blockAll: profile.blockAllApps,
            allowedWebDomains: WebDomainList.parse(profile.allowedWebDomains ?? ""),
            block: profiles.block(for: profile),
            allow: profiles.allow(for: profile)
        )
    }
}
