//
//  HomeView.swift
//  Zenly
//
//  The hub: pick the active profile, see today's streak, and start a focus
//  session. Presents the full-screen Session / Summary flow while one is active.
//
//  Redesign: the "calm focus universe" — drifting aurora, the breathing Focus
//  Orb, and frosted glass cards (Claude Design spec, Zenly.dc.html). All logic,
//  state, and bindings are unchanged; only the presentation layer was restyled.
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
            ZStack {
                ZenlyBackground()

                ScrollView {
                    VStack(spacing: ZTheme.Spacing.xl) {
                        header

                        if session.isActive && !showSession {
                            resumeBanner
                        }
                        if !authorization.isAuthorized {
                            permissionCard
                        }
                        if profiles.profiles.isEmpty {
                            emptyProfilesCard
                        } else {
                            profilePicker
                            orbSection
                        }
                        statsRow
                        goalCard
                        challengeCard
                        if freeBlock != nil { calendarCard }
                        soundSection
                        musicBar
                    }
                    .padding(.horizontal, ZTheme.Spacing.lg)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
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

    // MARK: - Header

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    private var header: some View {
        HStack {
            // Balance placeholder (keeps the greeting centered).
            Color.clear.frame(width: 44, height: 44)
            Spacer()
            VStack(spacing: 2) {
                Text(greeting)
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.5))
                Text("Ready to focus?")
                    .font(ZTheme.Font.display(20, weight: .bold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
            }
            Spacer()
            GlassIconButton(systemImage: "checklist") { showTasks = true }
                .accessibilityLabel("Tasks")
        }
        .padding(.top, 8)
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
            .font(ZTheme.Font.body(16, weight: .semibold))
            .foregroundStyle(.white)
            .padding()
            .background(
                LinearGradient(colors: [ZTheme.Palette.brandLight, Color(hex: session.accentHex)],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: ZTheme.Radius.chip, style: .continuous)
            )
            .shadow(color: Color(hex: session.accentHex).opacity(0.4), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.phase == .breakTime ? "Resume break timer" : "Resume focus timer")
        .accessibilityValue(session.timeString)
    }

    private var activeProfile: FocusProfile? { profiles.activeProfile }
    private var tint: Color { Color(hex: activeProfile?.accentHex ?? "1A3FA8") }

    // MARK: - Sections

    private var emptyProfilesCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(ZTheme.Palette.brandBright)
            Text("No focus profiles")
                .font(ZTheme.Font.display(17, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
            Text("Create a profile in the Profiles tab to start a focus session.")
                .font(ZTheme.Font.body(13))
                .foregroundStyle(ZTheme.Palette.text(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private var permissionCard: some View {
        VStack(spacing: 12) {
            Label("Screen Time access needed", systemImage: "hand.raised.fill")
                .font(ZTheme.Font.display(16, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
            Text("Zenly needs Screen Time access to block distracting apps during focus.")
                .font(ZTheme.Font.body(13))
                .foregroundStyle(ZTheme.Palette.text(0.6))
                .multilineTextAlignment(.center)
            Button("Grant Access") {
                Task { await authorization.requestAuthorization() }
            }
            .buttonStyle(.zenlyPrimary(tint: ZTheme.Palette.brand, height: 48))
        }
        .frame(maxWidth: .infinity)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: ZTheme.Radius.card, style: .continuous)
                .strokeBorder(ZTheme.Palette.streak.opacity(0.4), lineWidth: 1)
        )
    }

    private var profilePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ZTheme.Spacing.sm) {
                ForEach(profiles.profiles, id: \.objectID) { profile in
                    let isActive = profile.id == profiles.activeProfileID
                    SelectablePill(isSelected: isActive,
                                   tint: Color(hex: profile.accentHex ?? "1A3FA8")) {
                        profiles.setActive(profile)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: profile.iconName ?? "brain.head.profile")
                            Text(profile.name ?? "Untitled")
                        }
                    }
                    .frame(width: 132)
                    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var orbSection: some View {
        VStack(spacing: ZTheme.Spacing.lg) {
            FocusOrb(state: .idle, diameter: 212) {
                VStack(spacing: 4) {
                    Text("\(selectedMinutes)")
                        .font(ZTheme.Font.numeral(48, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("MINUTES")
                        .font(ZTheme.Font.body(12, weight: .semibold))
                        .tracking(2.5)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Focus duration")
            .accessibilityValue("\(selectedMinutes) minutes")

            durationStepper

            Button(action: startFocus) {
                Text("Start Focus")
            }
            .buttonStyle(.zenlyPrimary(tint: tint, height: 58))
            .disabled(activeProfile == nil || !authorization.isAuthorized || session.isActive)
            .opacity(activeProfile == nil || !authorization.isAuthorized || session.isActive ? 0.5 : 1)
        }
    }

    private var durationStepper: some View {
        HStack(spacing: ZTheme.Spacing.lg) {
            GlassIconButton(systemImage: "minus", size: 46, corner: 23) { adjustDuration(-5) }
                .accessibilityLabel("Decrease focus duration")
                .accessibilityValue("\(selectedMinutes) minutes")
            Text("session length")
                .font(ZTheme.Font.body(14, weight: .medium))
                .foregroundStyle(ZTheme.Palette.text(0.5))
                .frame(width: 110)
            GlassIconButton(systemImage: "plus", size: 46, corner: 23) { adjustDuration(5) }
                .accessibilityLabel("Increase focus duration")
                .accessibilityValue("\(selectedMinutes) minutes")
        }
    }

    private var statsRow: some View {
        HStack(spacing: ZTheme.Spacing.md) {
            StatTile(value: "\(streak)", label: "day streak",
                     systemImage: "flame.fill", color: ZTheme.Palette.streak)
            StatTile(value: "\(todayMinutes)", label: "min today",
                     systemImage: "clock.fill", color: ZTheme.Palette.teal)
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Daily Goal")
                    .font(ZTheme.Font.display(16, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Spacer()
                Text("\(todayMinutes) / \(dailyGoalMinutes) min")
                    .font(ZTheme.Font.body(14))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
            }
            ZenlyProgressBar(value: min(1, Double(todayMinutes) / Double(max(1, dailyGoalMinutes))))
            if todayMinutes >= dailyGoalMinutes {
                Label("Goal reached — nice work!", systemImage: "checkmark.circle.fill")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.teal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var challengeCard: some View {
        HStack(spacing: ZTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ZTheme.Palette.violet.opacity(0.18))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(ZTheme.Palette.violet.opacity(0.4), lineWidth: 1))
                    .frame(width: 44, height: 44)
                Image(systemName: challenges.challenge.systemImage)
                    .foregroundStyle(ZTheme.Palette.lavenderSoft)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Daily Challenge")
                    .font(ZTheme.Font.display(15, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text(challenges.challenge.title)
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
            }
            Spacer()
            if challenges.isComplete {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(ZTheme.Palette.teal)
            } else {
                Text("\(challenges.progress)/\(challenges.challenge.target)")
                    .font(ZTheme.Font.display(13, weight: .bold))
                    .foregroundStyle(ZTheme.Palette.lavenderSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Free time", systemImage: "calendar")
                .font(ZTheme.Font.display(15, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
            if let block = freeBlock {
                Text("You're free until \(block.end.formatted(date: .omitted, time: .shortened)) — \(block.minutes) min.")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.6))
                Button {
                    selectedMinutes = max(5, min(120, (block.minutes / 5) * 5))
                    startFocus()
                } label: {
                    Label("Start focus now", systemImage: "play.fill")
                }
                .buttonStyle(.zenlySecondary)
                .disabled(activeProfile == nil || !authorization.isAuthorized)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: ZTheme.Spacing.sm) {
            ZenlySectionHeader(title: "Ambient sound")
            HStack(spacing: ZTheme.Spacing.sm) {
                ForEach(AmbientSound.available) { sound in
                    let active = ambient.current == sound
                    SelectablePill(isSelected: active, height: 56) {
                        ambient.toggle(sound)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: sound.systemImage)
                            Text(sound.title).font(ZTheme.Font.body(13, weight: .semibold))
                        }
                    }
                    .accessibilityLabel(sound.title)
                    .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var musicBar: some View {
        HStack(spacing: ZTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [ZTheme.Palette.brand, ZTheme.Palette.violet],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .shadow(color: ZTheme.Palette.brand.opacity(0.5), radius: 10, y: 4)
                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(music.nowPlaying.isEmpty ? "Apple Music" : music.nowPlaying)
                    .font(ZTheme.Font.display(15, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                    .lineLimit(1)
                Text("Focus music")
                    .font(ZTheme.Font.body(12))
                    .foregroundStyle(ZTheme.Palette.text(0.5))
            }
            Spacer()
            Button { music.previous() } label: {
                Image(systemName: "backward.fill").foregroundStyle(ZTheme.Palette.text(0.7))
            }
            .accessibilityLabel("Previous track")
            Button { music.playPause() } label: {
                Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(.ultraThinMaterial)
                            .overlay(Circle().fill(ZTheme.Palette.glassFillRaised))
                            .overlay(Circle().strokeBorder(ZTheme.Palette.glassStrokeStrong, lineWidth: 1))
                            .environment(\.colorScheme, .dark)
                    )
            }
            .accessibilityLabel(music.isPlaying ? "Pause" : "Play")
            Button { music.next() } label: {
                Image(systemName: "forward.fill").foregroundStyle(ZTheme.Palette.text(0.7))
            }
            .accessibilityLabel("Next track")
        }
        .glassCard(padding: ZTheme.Spacing.md)
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
            accentHex: profile.accentHex ?? "1A3FA8",
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

/// A glowing periwinkle→violet progress bar used across the redesign.
struct ZenlyProgressBar: View {
    var value: Double
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [ZTheme.Palette.brand, ZTheme.Palette.violet],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(1, value)) * geo.size.width)
                    .shadow(color: ZTheme.Palette.brand.opacity(0.6), radius: 8)
            }
        }
        .frame(height: height)
    }
}
