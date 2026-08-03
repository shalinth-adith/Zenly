//
//  EditProfileSheet.swift
//  Zenly
//
//  Quiet spec, screen 20c ("Profile · edit") — the editor reached from 20b's
//  "Edit", and the only place an *existing* profile's blocked apps can be
//  changed. `ProfileEditView` (screens 09–13) stays the creation flow, with its
//  deferred validation and its "profile added" confirmation; this is the shorter
//  settings-shaped screen the comp draws for editing something that already
//  exists, so it opens with everything already valid and saves in one tap.
//
//  Header is Cancel · "Edit profile" · Save rather than the creation flow's
//  pinned tone CTA, exactly as the comp has it: there is nothing to validate
//  into existence here, so there is no status line to carry.
//
//  Two rows deviate from the comp, both because the comp draws a filled-in
//  example rather than every state:
//
//  * "Block everything" — the comp shows "4 apps · Choose", which is the
//    blockAllApps == false state. Without a toggle there is no way back from
//    "everything" to a specific set, which is the exact dead end App Review hit.
//  * "Starts on its own" — schedules are a separate entity linked by profile
//    name, so when a profile has none the toggle has nothing to drive and the
//    row says so instead of lying with an off switch.
//

import CoreData
import FamilyControls
import SwiftUI

/// Session length rules shared by both profile editors, so the ceiling and the
/// step bands can't drift apart between the create and edit screens.
enum ProfileLength {
    /// The longest a session may run. The comp names four hours, but the shipped
    /// Sleep profile is an eight-hour block, so the ceiling is eight.
    static let ceiling = 480
    static let floor = 5

    /// Coarser steps as the number grows, so an eight-hour Sleep block isn't
    /// ninety taps away from twenty-five minutes.
    static func stepped(_ minutes: Int, by direction: Int) -> Int {
        let up: Int
        switch minutes {
        case ..<60:  up = 5
        case ..<240: up = 15
        default:     up = 30
        }
        // Stepping down from a boundary should use the lower band's step.
        let down: Int
        switch minutes {
        case ...60:  down = 5
        case ...240: down = 15
        default:     down = 30
        }
        return min(ceiling, max(floor, minutes + (direction > 0 ? up : -down)))
    }
}

struct EditProfileSheet: View {
    @Environment(ProfileStore.self) private var store
    @Environment(ScheduleStore.self) private var schedules
    @Environment(AuthorizationService.self) private var authorization
    @Environment(FocusSessionController.self) private var session
    @Environment(\.dismiss) private var dismiss

    let profile: FocusProfile

    @State private var draft: ProfileDraft
    @State private var showBlockPicker = false
    @State private var showAllowPicker = false
    @State private var editingLength: LengthField?
    @FocusState private var nameFocused: Bool

    private enum LengthField { case focus, breakTime }

    init(profile: FocusProfile) {
        self.profile = profile
        // Seeded from the object rather than from a passed-in draft: this sheet
        // is always editing something that exists, and re-reading here means a
        // change made elsewhere (a rename, a picker) can never be stale.
        _draft = State(initialValue: ProfileDraft(
            name: profile.name ?? "",
            iconName: profile.iconName ?? "",
            accentHex: profile.accentHex ?? "7C93E8",
            focusMinutes: Int(profile.focusMinutes),
            breakMinutes: Int(profile.breakMinutes),
            isStrict: profile.isStrict,
            blockAllApps: profile.blockAllApps,
            allowedWebDomains: profile.allowedWebDomains ?? "",
            block: SelectionCodec.decode(profile.blockSelectionData),
            allow: SelectionCodec.decode(profile.allowSelectionData)
        ))
    }

    private var tone: Color { Color(hex: draft.accentHex) }

    private var isRunning: Bool {
        session.phase == .focus && session.profileName == (profile.name ?? "")
    }

    var body: some View {
        ZStack {
            ZTheme.Palette.night.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        nameSection
                        lengthSection
                        blockingSection
                        scheduleSection
                        strictSection
                        runningNote
                    }
                    .padding(.horizontal, QuietMetrics.gutter)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .familyActivityPicker(isPresented: $showBlockPicker, selection: $draft.block)
        .familyActivityPicker(isPresented: $showAllowPicker, selection: $draft.allow)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Edit profile")
                .font(ZTheme.Font.body(15, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)

            HStack {
                Button("Cancel") { Haptics.light(); dismiss() }
                    .font(ZTheme.Font.body(15))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile-edit-cancel")

                Spacer(minLength: 0)

                Button("Save") { save() }
                    .font(ZTheme.Font.body(15, weight: .semibold))
                    .foregroundStyle(canSave ? tone : ZTheme.Palette.text(0.30))
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                    .accessibilityIdentifier("profile-edit-save")
            }
        }
        .padding(.horizontal, QuietMetrics.gutter)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: "Name")

            HStack(spacing: 12) {
                TextField("Name", text: $draft.name)
                    .textFieldStyle(.plain)
                    .font(ZTheme.Font.display(17, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                    .tint(tone)
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .accessibilityIdentifier("profile-edit-name")
            }
            .padding(.vertical, 14)
            QuietHairline(color: ZTheme.Palette.glassFill)

            if let duplicate = duplicateProfile {
                QuietHelper(text: "You already have a \(duplicate.name ?? "") profile.",
                            color: ZTheme.Palette.alert)
            } else if trimmedName.isEmpty {
                QuietHelper(text: "A profile needs a name.", color: ZTheme.Palette.alert)
            }
        }
    }

    // MARK: - Length

    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: "Length", topPadding: QuietMetrics.sectionGap)

            lengthRow(title: "Focus",
                      value: "\(draft.focusMinutes) min",
                      field: .focus)
            if editingLength == .focus {
                QuietStepperRow(
                    value: "\(draft.focusMinutes) min",
                    canDecrement: draft.focusMinutes > ProfileLength.floor,
                    canIncrement: draft.focusMinutes < ProfileLength.ceiling,
                    onDecrement: { draft.focusMinutes = ProfileLength.stepped(draft.focusMinutes, by: -1) },
                    onIncrement: { draft.focusMinutes = ProfileLength.stepped(draft.focusMinutes, by: 1) })
                    .padding(.bottom, 14)
                QuietHairline(color: ZTheme.Palette.glassFill)
            }

            lengthRow(title: "Break",
                      value: draft.breakMinutes > 0 ? "\(draft.breakMinutes) min" : "None",
                      field: .breakTime)
            if editingLength == .breakTime {
                QuietStepperRow(
                    value: draft.breakMinutes > 0 ? "\(draft.breakMinutes) min" : "None",
                    canDecrement: draft.breakMinutes > 0,
                    canIncrement: draft.breakMinutes < 30,
                    onDecrement: { draft.breakMinutes = max(0, draft.breakMinutes - 5) },
                    onIncrement: { draft.breakMinutes = min(30, draft.breakMinutes + 5) })
                    .padding(.bottom, 14)
                QuietHairline(color: ZTheme.Palette.glassFill)
            }

            if draft.focusMinutes >= ProfileLength.ceiling {
                QuietHelper(text: "Eight hours is the longest a session can run.",
                            color: ZTheme.Palette.warn)
            }
        }
        .animation(ZTheme.Motion.smooth, value: editingLength)
    }

    /// The comp draws a chevron on these rows. Rather than push a screen for a
    /// single number, tapping reveals the stepper in place — the same move the
    /// schedule editor already makes for its time wheel.
    private func lengthRow(title: String, value: String, field: LengthField) -> some View {
        VStack(spacing: 0) {
            Button {
                Haptics.light()
                nameFocused = false
                editingLength = editingLength == field ? nil : field
            } label: {
                HStack(spacing: 15) {
                    Text(title)
                        .font(ZTheme.Font.body(15))
                        .foregroundStyle(ZTheme.Palette.textPrimary)
                    Spacer(minLength: 0)
                    Text(value)
                        .font(ZTheme.Font.body(15))
                        .monospacedDigit()
                        .foregroundStyle(ZTheme.Palette.text(0.55))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ZTheme.Palette.text(0.30))
                        .rotationEffect(.degrees(editingLength == field ? 90 : 0))
                }
                .padding(.vertical, 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if editingLength != field { QuietHairline(color: ZTheme.Palette.glassFill) }
        }
    }

    // MARK: - Blocked apps

    private var blockCount: Int {
        draft.block.applicationTokens.count
            + draft.block.categoryTokens.count
            + draft.block.webDomainTokens.count
    }

    private var blockingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: "Blocked apps", topPadding: QuietMetrics.sectionGap)

            QuietToggleRow(title: "Block everything",
                           subtitle: "Except the apps you allow",
                           isOn: $draft.blockAllApps,
                           tone: tone)
            QuietHairline(color: ZTheme.Palette.glassFill)

            if !draft.blockAllApps {
                chooseRow(title: countLabel(blockCount, noun: "app", zero: "No apps chosen"),
                          identifier: "profile-edit-choose-blocked") { showBlockPicker = true }
                QuietHairline(color: ZTheme.Palette.glassFill)
            }

            chooseRow(title: countLabel(draft.allow.applicationTokens.count,
                                        noun: "app", zero: "None chosen"),
                      subtitle: draft.blockAllApps ? "Allowed apps" : "Always allowed",
                      identifier: "profile-edit-choose-allowed") { showAllowPicker = true }
            QuietHairline(color: ZTheme.Palette.glassFill)

            if !authorization.isAuthorized {
                QuietHelper(text: "Screen Time access is off, so these choices can\u{2019}t be enforced yet.",
                            color: ZTheme.Palette.warn)
            }
        }
        .animation(ZTheme.Motion.smooth, value: draft.blockAllApps)
    }

    private func countLabel(_ count: Int, noun: String, zero: String = "None") -> String {
        count == 0 ? zero : "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    /// The comp's "4 apps … Choose ›" row.
    private func chooseRow(title: String,
                           subtitle: String? = nil,
                           identifier: String,
                           action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            nameFocused = false
            action()
        } label: {
            HStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 2) {
                    if let subtitle {
                        Text(subtitle)
                            .font(ZTheme.Font.body(12))
                            .foregroundStyle(ZTheme.Palette.text(0.55))
                    }
                    Text(title)
                        .font(ZTheme.Font.body(15))
                        .foregroundStyle(ZTheme.Palette.textPrimary)
                }
                Spacer(minLength: 0)
                Text("Choose")
                    .font(ZTheme.Font.body(15))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.text(0.30))
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Schedule

    private var profileSchedules: [FocusSchedule] {
        schedules.schedules.filter { ($0.profileName ?? "") == (profile.name ?? "") }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        QuietFieldLabel(text: "Schedule", topPadding: QuietMetrics.sectionGap)

        if profileSchedules.isEmpty {
            QuietHelper(text: "No schedule yet. Add one from the Schedule tab to have this profile start on its own.")
                .padding(.bottom, 4)
        } else {
            ForEach(profileSchedules, id: \.objectID) { schedule in
                VStack(spacing: 0) {
                    HStack(spacing: 15) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Starts on its own")
                                .font(ZTheme.Font.body(15))
                                .foregroundStyle(ZTheme.Palette.textPrimary)
                            Text("\(schedules.weekdaySummary(schedule)) · \(startTime(schedule))")
                                .font(ZTheme.Font.body(12))
                                .foregroundStyle(ZTheme.Palette.text(0.55))
                        }
                        Spacer(minLength: 0)
                        Toggle("", isOn: Binding(
                            get: { schedule.isEnabled },
                            set: { schedules.setEnabled(schedule, $0) }))
                            .labelsHidden()
                            .tint(tone)
                            .accessibilityLabel("Start \(schedule.title ?? "") on its own")
                    }
                    .padding(.vertical, 15)
                    QuietHairline(color: ZTheme.Palette.glassFill)
                }
            }
        }
    }

    private func startTime(_ schedule: FocusSchedule) -> String {
        ScheduleEditView.timeText(Int(schedule.startHour) * 60 + Int(schedule.startMinute))
    }

    // MARK: - Strict

    private var strictSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: "Strict mode", topPadding: QuietMetrics.sectionGap)
            QuietToggleRow(title: "Hold me to it",
                           subtitle: "No early exit once a session starts",
                           isOn: $draft.isStrict,
                           tone: tone)
            QuietHairline(color: ZTheme.Palette.glassFill)
        }
    }

    // MARK: - Running note

    @ViewBuilder
    private var runningNote: some View {
        if isRunning {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(ZTheme.Palette.text(0.30))
                    .padding(.top, 1)
                Text("\(profile.name ?? "This profile") is in session. Changes to length and blocked apps apply from the next session.")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 22)
        }
    }

    // MARK: - Save

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespaces)
    }

    /// A different profile that already owns this name.
    private var duplicateProfile: FocusProfile? {
        guard !trimmedName.isEmpty else { return nil }
        return store.profiles.first {
            $0.objectID != profile.objectID
                && ($0.name ?? "").caseInsensitiveCompare(trimmedName) == .orderedSame
        }
    }

    private var canSave: Bool { !trimmedName.isEmpty && duplicateProfile == nil }

    private func save() {
        guard canSave else { return }
        let previousName = profile.name ?? ""
        draft.name = trimmedName

        store.update(profile, with: draft)

        // Schedules point at a profile by name, so a rename has to carry them
        // across or the profile silently stops starting on its own.
        if previousName != trimmedName {
            schedules.renameProfile(from: previousName, to: trimmedName)
        }

        // A live session keeps enforcing what it started with — the note above
        // says so — but a change made while idle should be the truth right away.
        //
        // Gated on `session.isActive`, not on this profile running: reconciling
        // mid-session recomputes shields from the registered activities, and a
        // session under fifteen minutes registers none (see
        // `ScheduleCenter.startOneOff`), so it would lift shields that are
        // supposed to be up — even for a profile this sheet never touched.
        if !session.isActive { session.reapplyEnforcement() }

        Haptics.success()
        dismiss()
    }
}
