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

    /// The name shown in the greeting, set by the user in Settings › You.
    @AppStorage("userDisplayName", store: AppGroup.defaults) private var userName = ""

    @State private var selectedMinutes = 25
    @State private var showSession = false

    var body: some View {
        NavigationStack {
            ZStack {
                ZenlyBackground()

                // A single, non-scrolling focus screen (Quiet comp 01): profile
                // row up top, the breathing halo orb as the hero balanced by
                // spacers, then the "Begin focus" CTA and the streak footer.
                GeometryReader { proxy in
                    VStack(spacing: ZTheme.Spacing.lg) {
                        header

                        if session.isActive && !showSession {
                            resumeBanner
                        }
                        if !authorization.isAuthorized {
                            permissionCard
                        }

                        if profiles.profiles.isEmpty {
                            Spacer(minLength: 0)
                            emptyProfilesCard
                            Spacer(minLength: 0)
                        } else {
                            profilePicker
                            Spacer(minLength: 0)
                            orbSection(diameter: orbDiameter(for: proxy.size.height))
                            Spacer(minLength: 0)
                            beginSection
                            streakFooter
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, ZTheme.Spacing.lg)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await prepare() }
            .onChange(of: session.phase) { oldPhase, newPhase in
                switch newPhase {
                case .idle:
                    showSession = false
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
        // Quiet spec: a single soft greeting line — no bold headline competing
        // for attention. Includes the user's name when they've set one.
        Text(userName.isEmpty ? greeting : "\(greeting), \(userName)")
            .font(ZTheme.Font.body(15))
            .foregroundStyle(ZTheme.Palette.text(0.55))
            .frame(maxWidth: .infinity)
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
            .font(ZTheme.Font.body(16, weight: .medium))
            .foregroundStyle(Color(hex: "0A0B0E"))
            .padding()
            .background(
                ZTheme.tone(forHex: session.accentHex),
                in: RoundedRectangle(cornerRadius: ZTheme.Radius.chip, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.phase == .breakTime ? "Resume break timer" : "Resume focus timer")
        .accessibilityValue(session.timeString)
    }

    private var activeProfile: FocusProfile? { profiles.activeProfile }
    /// The single accent — the active profile's Quiet tone.
    private var tint: Color { ZTheme.tone(forHex: activeProfile?.accentHex) }

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
            Text("Zen-ly needs Screen Time access to block distracting apps during focus.")
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

    /// Quiet-spec profile selector: centered text labels, each with a small
    /// tone dot beneath the active one. No pills, no icons — the name is enough,
    /// and the single coloured dot is the only bright mark. Drag still reorders.
    private var profilePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 28) {
                ForEach(profiles.profiles, id: \.objectID) { profile in
                    let isActive = profile.id == profiles.activeProfileID
                    let tone = ZTheme.tone(forHex: profile.accentHex)
                    Button {
                        Haptics.light()
                        profiles.setActive(profile)
                    } label: {
                        VStack(spacing: 7) {
                            Text(profile.name ?? "Untitled")
                                .font(ZTheme.Font.body(15, weight: isActive ? .medium : .regular))
                                .foregroundStyle(isActive ? ZTheme.Palette.textPrimary
                                                          : ZTheme.Palette.text(0.5))
                                .lineLimit(1)
                                .fixedSize()
                            Circle()
                                .fill(isActive ? tone : .clear)
                                .frame(width: 5, height: 5)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .animation(ZTheme.Motion.smooth, value: isActive)
                    .accessibilityLabel(profile.name ?? "Untitled")
                    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
                    // Long-press to drag a label onto another to reorder; the new
                    // order persists via FocusProfile.sortIndex (ProfileStore.move).
                    .draggable(profile.id?.uuidString ?? "")
                    .dropDestination(for: String.self) { items, _ in
                        guard let raw = items.first,
                              let draggedID = UUID(uuidString: raw),
                              let targetID = profile.id else { return false }
                        profiles.move(id: draggedID, before: targetID)
                        return true
                    }
                }
            }
            .padding(.vertical, 2)
            // Each profile label is a snap target.
            .scrollTargetLayout()
        }
        // Snap so a name always lands whole at the leading edge — a label never
        // rests sliced mid-letter, and there's no fade dimming the active one.
        // The parent column's horizontal padding supplies the resting gutter.
        .scrollTargetBehavior(.viewAligned)
    }

    /// Shrink the hero orb on shorter screens so the non-scrolling layout fits
    /// (e.g. iPhone SE) without changing its look on larger devices.
    private func orbDiameter(for availableHeight: CGFloat) -> CGFloat {
        max(150, min(212, availableHeight * 0.28))
    }

    private func orbSection(diameter: CGFloat) -> some View {
        VStack(spacing: ZTheme.Spacing.lg) {
            // The tone halo breathes softly behind large, thin ink numerals —
            // the number is neutral; only the halo carries the profile's colour.
            FocusOrb(state: .idle, diameter: diameter, ringTint: tint,
                     living: false, breathes: true) {
                VStack(spacing: 8) {
                    Text("\(selectedMinutes)")
                        .font(ZTheme.Font.numeral(min(86, diameter * 0.4), weight: .regular))
                        .foregroundStyle(ZTheme.Palette.textPrimary)
                    Text("MINUTES")
                        .font(ZTheme.Font.body(11, weight: .regular))
                        .tracking(3)
                        .foregroundStyle(ZTheme.Palette.text(0.55))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Focus duration")
            .accessibilityValue("\(selectedMinutes) minutes")

            durationStepper
        }
    }

    /// The one bright action, pinned near the bottom of the screen.
    private var beginSection: some View {
        Button(action: startFocus) {
            Text("Begin focus")
        }
        .buttonStyle(.zenlyPrimary(tint: tint, height: 56))
        .disabled(activeProfile == nil || !authorization.isAuthorized || session.isActive)
        .opacity(activeProfile == nil || !authorization.isAuthorized || session.isActive ? 0.45 : 1)
    }

    /// "N-day streak · M min today" — the quiet stat line beneath the CTA.
    private var streakFooter: some View {
        Text("\(analytics.streak())-day streak · \(analytics.todayMinutes()) min today")
            .font(ZTheme.Font.body(13))
            .foregroundStyle(ZTheme.Palette.text(0.45))
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            .accessibilityLabel("\(analytics.streak()) day streak, \(analytics.todayMinutes()) minutes today")
    }

    private var durationStepper: some View {
        HStack(spacing: ZTheme.Spacing.lg) {
            GlassIconButton(systemImage: "minus", size: 46, corner: 23) { adjustDuration(-5) }
                .accessibilityLabel("Decrease focus duration")
                .accessibilityValue("\(selectedMinutes) minutes")
            Text("session\nlength")
                .font(ZTheme.Font.body(14))
                .foregroundStyle(ZTheme.Palette.text(0.5))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 90)
            GlassIconButton(systemImage: "plus", size: 46, corner: 23) { adjustDuration(5) }
                .accessibilityLabel("Increase focus duration")
                .accessibilityValue("\(selectedMinutes) minutes")
        }
    }

    // MARK: - Actions

    private func prepare() async {
        authorization.refresh() // pick up persisted Screen Time approval
        await NotificationService.shared.requestAuthorization()
        NotificationService.shared.scheduleDailyChallengeReminder()
        syncDuration()
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

/// A quiet progress bar: a hairline track with a flat tone fill (no glow).
struct ZenlyProgressBar: View {
    var value: Double
    var height: CGFloat = 8
    var tint: Color = ZTheme.Palette.tone

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(ZTheme.Palette.glassStroke)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}
