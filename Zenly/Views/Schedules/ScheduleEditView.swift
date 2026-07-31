//
//  ScheduleEditView.swift
//  Zenly
//
//  Create or edit a recurring schedule — the Quiet spec's screens 16–18
//  (Zenly Quiet.dc.html: "New schedule · live", "Saved with nothing chosen",
//  "Times that don't work").
//
//  Same shape as ProfileEditView: QuietForm primitives, deferred validation,
//  and a pinned status line above the single tone CTA. Three time problems get
//  their own treatment, exactly as the comp does — an empty window is an error
//  with a one-tap end time, an overnight window is simply explained and left
//  alone, and an overlap with an existing schedule offers the two repairs a
//  person would actually reach for.
//

import SwiftUI
import CoreData
import FamilyControls

/// What the schedule list should say after a save, and how to put it back.
struct ScheduleSaveOutcome {
    let schedule: FocusSchedule
    /// Non-nil when the editor changed something on the user's behalf.
    let note: String?
    let undo: (() -> Void)?
}

struct ScheduleEditView: View {
    @Environment(ScheduleStore.self) private var store
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dismiss) private var dismiss

    let schedule: FocusSchedule?
    var onSaved: ((ScheduleSaveOutcome) -> Void)? = nil

    @State private var draft: ScheduleDraft
    @State private var validation = QuietValidation()
    @State private var editingTime: TimeField?
    @State private var showBlockPicker = false
    @State private var showAllowPicker = false
    /// The draft as it stood before a one-tap repair, so the list's Undo can
    /// put the schedule back the way the user actually typed it.
    @State private var draftBeforeRepair: ScheduleDraft?
    @State private var repairNote: String?
    @FocusState private var titleFocused: Bool

    enum TimeField: String, Identifiable {
        case start, end
        var id: String { rawValue }
    }

    private let weekdaySymbols: [(day: Int, label: String)] = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")
    ]

    init(schedule: FocusSchedule?,
         draft: ScheduleDraft,
         onSaved: ((ScheduleSaveOutcome) -> Void)? = nil) {
        self.schedule = schedule
        self.onSaved = onSaved
        var seeded = draft
        // A new schedule starts with nothing chosen, so the comp's "pick the
        // days / and which profile" state is reachable.
        if schedule == nil { seeded.weekdays = [] }
        _draft = State(initialValue: seeded)
    }

    private var selectedProfile: FocusProfile? {
        profiles.profiles.first { ($0.name ?? "") == draft.profileName }
    }

    private var tone: Color {
        ZTheme.tone(forHex: selectedProfile?.accentHex ?? profiles.activeProfile?.accentHex)
    }

    var body: some View {
        NavigationStack {
            QuietEditorScaffold(
                title: schedule == nil ? "New schedule" : "Edit schedule",
                cancelTitle: "Cancel",
                status: status,
                statusIsAlert: statusIsAlert,
                ctaTitle: schedule == nil ? "Add to schedule" : "Save changes",
                ctaIdentifier: "schedule-save",
                isReady: isReady,
                tone: tone,
                onCancel: { dismiss() },
                onSubmit: submit
            ) {
                titleSection
                timeSection
                conflictSection
                daysSection
                profileSection
                blockingSection
                strictSection
            }
            .toolbar(.hidden, for: .navigationBar)
            .familyActivityPicker(isPresented: $showBlockPicker, selection: $draft.block)
            .familyActivityPicker(isPresented: $showAllowPicker, selection: $draft.allow)
        }
        .onAppear { if schedule == nil { titleFocused = true } }
    }

    // MARK: Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: "Title")
            QuietTextField(placeholder: draft.profileName.isEmpty ? "Untitled" : draft.profileName,
                           text: $draft.title)
                .focused($titleFocused)
                .submitLabel(.done)
                .accessibilityIdentifier("schedule-title")
            QuietHelper(text: draft.title.trimmingCharacters(in: .whitespaces).isEmpty
                        ? "Fine as it is — a title was never needed."
                        : "Optional — left blank, it takes the profile\u{2019}s name.")
        }
    }

    // MARK: Time

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: sameTime ? "Time · same start and end" : "Time",
                            color: sameTime ? ZTheme.Palette.alert : ZTheme.Palette.text(0.30),
                            topPadding: QuietMetrics.sectionGap)
                .padding(.bottom, 2)

            timeRow("Starts", field: .start,
                    minutes: startMinutes,
                    isAlert: false)
            if editingTime == .start { timeWheel(for: .start) }
            QuietHairline(color: ZTheme.Palette.glassFill)

            timeRow("Ends", field: .end,
                    minutes: endMinutes,
                    isAlert: sameTime)
            if editingTime == .end { timeWheel(for: .end) }
            QuietHairline(color: sameTime ? ZTheme.Palette.alert : ZTheme.Palette.glassStroke)

            if sameTime {
                QuietHelperRow(text: "That\u{2019}s no time at all.",
                               color: ZTheme.Palette.alert,
                               actionTitle: "End at \(Self.timeText(suggestedEndMinutes))",
                               tone: tone) { setEnd(to: suggestedEndMinutes) }
            } else if isOvernight {
                QuietHelper(text: "Read as overnight — it ends the next morning. Nothing to fix.",
                            color: ZTheme.Palette.text(0.55))
            } else {
                QuietHelper(text: "\(windowLengthText) — and yours to change.")
            }
        }
    }

    private func timeRow(_ label: String, field: TimeField, minutes: Int, isAlert: Bool) -> some View {
        Button {
            Haptics.light()
            editingTime = editingTime == field ? nil : field
            titleFocused = false
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(ZTheme.Font.body(15))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
                Spacer(minLength: 0)
                Text(Self.timeText(minutes))
                    .font(ZTheme.Font.numeral(19))
                    .foregroundStyle(isAlert ? ZTheme.Palette.alert
                                     : editingTime == field ? tone
                                     : ZTheme.Palette.textPrimary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 15)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("schedule-\(field.rawValue)")
        .accessibilityValue(Self.timeText(minutes))
    }

    /// Tapping a time row opens the wheel inline, so the flat row of the comp
    /// survives while the picker stays the one iOS users already know.
    private func timeWheel(for field: TimeField) -> some View {
        DatePicker("",
                   selection: Binding(
                       get: { Self.date(from: field == .start ? startMinutes : endMinutes) },
                       set: { newValue in
                           let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                           if field == .start {
                               draft.startHour = parts.hour ?? 9
                               draft.startMinute = parts.minute ?? 0
                           } else {
                               draft.endHour = parts.hour ?? 17
                               draft.endMinute = parts.minute ?? 0
                           }
                       }),
                   displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .tint(tone)
    }

    // MARK: Conflicts (screen 18)

    @ViewBuilder
    private var conflictSection: some View {
        if let conflict = conflicts.first {
            VStack(alignment: .leading, spacing: 0) {
                QuietHairline().padding(.top, 26)
                QuietFieldLabel(text: "Overlaps something you have",
                                color: ZTheme.Palette.warn,
                                topPadding: 26)
                    .padding(.bottom, 12)

                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.timeText(Int(conflict.schedule.startHour) * 60
                                           + Int(conflict.schedule.startMinute), withMeridiem: false))
                            .font(ZTheme.Font.numeral(15))
                            .foregroundStyle(ZTheme.Palette.textPrimary)
                        Text(Self.meridiem(Int(conflict.schedule.startHour)))
                            .font(ZTheme.Font.body(11))
                            .tracking(0.9)
                            .foregroundStyle(ZTheme.Palette.text(0.30))
                    }
                    .frame(width: 58, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(conflictTitle(conflict))
                            .font(ZTheme.Font.display(15, weight: .semibold))
                            .foregroundStyle(ZTheme.Palette.textPrimary)
                        Text("\(store.weekdaySummary(conflict.schedule)) · until \(Self.timeText(conflict.existingEndMinutes))")
                            .font(ZTheme.Font.body(12))
                            .foregroundStyle(ZTheme.Palette.text(0.55))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 14)

                QuietHelper(text: conflictExplanation(conflict), color: ZTheme.Palette.warn)

                HStack(spacing: 8) {
                    repairButton("Start at \(Self.timeText(conflict.existingEndMinutes))") {
                        moveStart(to: conflict.existingEndMinutes)
                    }
                    if conflict.days.count == 1, let day = conflict.days.first {
                        repairButton("Skip \(Self.dayName(day))") { skip(day) }
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    private func repairButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.light(); action() }) {
            Text(title)
                .font(ZTheme.Font.display(14, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: QuietMetrics.tileRadius, style: .continuous)
                        .fill(ZTheme.Palette.glassFill)
                )
        }
        .buttonStyle(.plain)
    }

    private func conflictTitle(_ conflict: ScheduleStore.ScheduleConflict) -> String {
        ScheduleStore.displayName(for: conflict.schedule)
    }

    private func conflictExplanation(_ conflict: ScheduleStore.ScheduleConflict) -> String {
        let base = "Two sessions can\u{2019}t hold the same hour."
        let days = conflict.days.sorted().map(Self.dayName)
        switch days.count {
        case 1:  return "\(base) \(days[0]) is the only day they collide."
        case 2:  return "\(base) They collide on \(days[0]) and \(days[1])."
        default: return "\(base) They collide on \(days.count) of the days you picked."
        }
    }

    // MARK: Days

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: "Days",
                            color: validation.labelColor(draft.weekdays.isEmpty),
                            topPadding: QuietMetrics.sectionGap)
                .padding(.bottom, 14)

            HStack(spacing: 7) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, item in
                    QuietChip(title: item.label,
                              isSelected: draft.weekdays.contains(item.day),
                              tone: tone,
                              restingFill: validation.emptyFill(draft.weekdays.isEmpty),
                              height: 44,
                              expands: true) {
                        if draft.weekdays.contains(item.day) {
                            draft.weekdays.remove(item.day)
                        } else {
                            draft.weekdays.insert(item.day)
                        }
                    }
                    .accessibilityLabel(Self.dayName(item.day))
                }
            }

            if validation.flags(draft.weekdays.isEmpty) {
                QuietHelperRow(text: "Pick the days this should repeat.",
                               color: ZTheme.Palette.alert,
                               actionTitle: "Weekdays",
                               tone: tone) { draft.weekdays = [2, 3, 4, 5, 6] }
            } else {
                QuietHelper(text: draft.weekdays.isEmpty
                            ? "Tap the days it should repeat."
                            : "Repeats \(ScheduleStore.summary(for: draft.weekdays).lowercased()).")
            }
        }
    }

    // MARK: Profile

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: "Profile",
                            color: validation.labelColor(draft.profileName.isEmpty),
                            topPadding: QuietMetrics.sectionGap)
                .padding(.bottom, 12)

            QuietFlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(profiles.profiles, id: \.objectID) { profile in
                    let name = profile.name ?? ""
                    QuietChip(title: name,
                              isSelected: draft.profileName == name,
                              tone: ZTheme.tone(forHex: profile.accentHex),
                              restingFill: validation.emptyFill(draft.profileName.isEmpty)) {
                        select(profile)
                    }
                }
            }

            if validation.flags(draft.profileName.isEmpty) {
                QuietHelper(text: "And which profile it should run.", color: ZTheme.Palette.alert)
            } else {
                QuietHelper(text: draft.profileName.isEmpty
                            ? "The profile decides what gets blocked."
                            : "Runs with your \(draft.profileName) blocking.")
            }
        }
    }

    // MARK: Blocking / strict

    private var blockingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: "Blocking", topPadding: QuietMetrics.sectionGap)
                .padding(.bottom, 2)

            QuietToggleRow(title: "Block everything",
                           subtitle: "Except the apps you allow",
                           isOn: $draft.blockAllApps,
                           tone: tone)
            QuietHairline(color: ZTheme.Palette.glassFill)

            if !draft.blockAllApps {
                QuietDisclosureRow(title: "Blocked apps & sites",
                                   value: countText(blockCount)) { showBlockPicker = true }
                QuietHairline(color: ZTheme.Palette.glassFill)
            }

            QuietDisclosureRow(title: draft.blockAllApps ? "Allowed apps" : "Always allowed",
                               value: countText(draft.allow.applicationTokens.count)) {
                showAllowPicker = true
            }
        }
        .animation(ZTheme.Motion.smooth, value: draft.blockAllApps)
    }

    private var strictSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: "Strict mode", topPadding: QuietMetrics.sectionGap)
                .padding(.bottom, 2)
            QuietToggleRow(title: "Hold me to it",
                           subtitle: "A short delay before a session can end early",
                           isOn: $draft.isStrict,
                           tone: tone)
        }
    }

    // MARK: - Derived state

    private var startMinutes: Int { draft.startHour * 60 + draft.startMinute }
    private var endMinutes: Int { draft.endHour * 60 + draft.endMinute }
    private var sameTime: Bool { startMinutes == endMinutes }
    private var isOvernight: Bool { endMinutes < startMinutes }

    private var windowLengthText: String {
        let mins = ScheduleStore.duration(startMinutes: startMinutes, endMinutes: endMinutes)
        let h = mins / 60, m = mins % 60
        if h == 0 { return "\(m) minutes" }
        if m == 0 { return h == 1 ? "One hour" : "\(h) hours" }
        return "\(h)h \(m)m"
    }

    /// End the window after the chosen profile's own session length — the
    /// repair the comp offers when start and end are the same.
    private var suggestedEndMinutes: Int {
        let length = Int(selectedProfile?.focusMinutes ?? 25)
        return (startMinutes + max(5, length)) % (24 * 60)
    }

    private var conflicts: [ScheduleStore.ScheduleConflict] {
        guard !sameTime, !draft.weekdays.isEmpty else { return [] }
        return store.conflicts(for: draft, excluding: schedule)
    }

    private var isReady: Bool {
        !draft.weekdays.isEmpty && !draft.profileName.isEmpty && !sameTime && conflicts.isEmpty
    }

    /// A clash and an empty window are shown as soon as they exist, not held
    /// back until the user presses the CTA — both are already spelled out on
    /// screen with a repair beside them, so the footer would be lying if it
    /// still read "Days and a profile is all it takes".
    private var statusIsAlert: Bool {
        !isReady && (validation.hasTriedToSave || sameTime || !conflicts.isEmpty)
    }

    private var status: String {
        guard statusIsAlert else {
            return isReady ? "Ready when you are" : "Days and a profile is all it takes"
        }
        let missing = (draft.weekdays.isEmpty ? 1 : 0) + (draft.profileName.isEmpty ? 1 : 0)
        if missing == 0 && sameTime { return "The end time needs a nudge" }
        if missing == 0 && !conflicts.isEmpty {
            return "One clash to settle, and it\u{2019}s yours to pick"
        }
        return missing == 2 ? "Two choices left — days, then profile" : "One choice left, just above"
    }

    private var blockCount: Int {
        draft.block.applicationTokens.count
            + draft.block.categoryTokens.count
            + draft.block.webDomainTokens.count
    }

    private func countText(_ count: Int) -> String { count == 0 ? "None" : "\(count)" }

    // MARK: - Actions

    /// Choosing a profile also adopts its blocking, which is what "runs with
    /// your Work blocking" means. The Blocking section below stays editable, so
    /// a schedule can still diverge from its profile afterwards.
    private func select(_ profile: FocusProfile) {
        draft.profileName = profile.name ?? ""
        draft.blockAllApps = profile.blockAllApps
        draft.block = SelectionCodec.decode(profile.blockSelectionData)
        draft.allow = SelectionCodec.decode(profile.allowSelectionData)
        draft.isStrict = profile.isStrict
        editingTime = nil
    }

    private func setEnd(to minutes: Int) {
        draft.endHour = minutes / 60
        draft.endMinute = minutes % 60
    }

    private func moveStart(to minutes: Int) {
        rememberForUndo("Moved to \(Self.timeText(minutes)) to clear the clash.")
        let length = ScheduleStore.duration(startMinutes: startMinutes, endMinutes: endMinutes)
        draft.startHour = minutes / 60
        draft.startMinute = minutes % 60
        let newEnd = (minutes + length) % (24 * 60)
        setEnd(to: newEnd)
    }

    private func skip(_ day: Int) {
        rememberForUndo("\(Self.dayName(day)) left out to clear the clash.")
        draft.weekdays.remove(day)
    }

    /// Only the first repair is remembered — it's what the toast will offer to
    /// undo, and stacking them would put the schedule back somewhere the user
    /// never saw.
    private func rememberForUndo(_ note: String) {
        if draftBeforeRepair == nil { draftBeforeRepair = draft }
        repairNote = note
    }

    private func submit() {
        guard isReady else {
            validation.flagMissingFields()
            Haptics.light()
            return
        }
        // A blank title stays blank. The list writes the profile's name in its
        // place at display time, which keeps following the profile if it is
        // ever renamed — and leaves room for "Work · Deep focus" when the user
        // does give the schedule a name of its own.
        draft.title = draft.title.trimmingCharacters(in: .whitespaces)

        let saved: FocusSchedule
        if let schedule {
            store.update(schedule, with: draft)
            saved = schedule
        } else {
            saved = store.create(from: draft)
        }

        let undo: (() -> Void)?
        if let previous = draftBeforeRepair {
            undo = { [store] in store.update(saved, with: previous) }
        } else {
            undo = nil
        }
        onSaved?(ScheduleSaveOutcome(schedule: saved, note: repairNote, undo: undo))
        dismiss()
    }

    // MARK: - Formatting

    static func timeText(_ minutes: Int, withMeridiem: Bool = true) -> String {
        let normalized = ((minutes % (24 * 60)) + 24 * 60) % (24 * 60)
        let hour24 = normalized / 60
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let clock = String(format: "%d:%02d", hour12, normalized % 60)
        return withMeridiem ? "\(clock) \(meridiem(hour24))" : clock
    }

    static func meridiem(_ hour24: Int) -> String { hour24 < 12 ? "AM" : "PM" }

    static func dayName(_ weekday: Int) -> String {
        ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][weekday]
    }

    private static func date(from minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60,
                              minute: minutes % 60,
                              second: 0,
                              of: Date()) ?? Date()
    }
}
