//
//  ProfileEditView.swift
//  Zenly
//
//  Create or edit a focus profile — the Quiet spec's screens 09–13
//  (Zenly Quiet.dc.html: "New profile · live", "Saved with nothing entered",
//  "Entries that don't work", "Couldn't save", "Saved").
//
//  Built from QuietForm primitives rather than a SwiftUI `Form`: a flat sheet
//  with a 28pt gutter, uppercase tracked labels, a helper line under every
//  field, and a pinned footer holding the status line above the single tone CTA.
//
//  Validation is deferred — nothing turns alert until you press the CTA with
//  something missing (the spec's `npTried`). Beyond the two required fields the
//  screen also catches a duplicate name, a session length past the ceiling, and
//  a website that isn't one, each with a one-tap repair.
//

import SwiftUI
import FamilyControls

struct ProfileEditView: View {
    @Environment(ProfileStore.self) private var store
    @Environment(AuthorizationService.self) private var authorization
    @Environment(FocusSessionController.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// nil = creating a new profile.
    let profile: FocusProfile?
    /// Called when the user chooses "Put it on the schedule" from the saved
    /// screen. Presenters that can open a schedule editor wire this up; the
    /// rest leave it nil and the button just closes the sheet.
    var onScheduleRequested: ((FocusProfile) -> Void)? = nil

    /// The profile currently being edited. Starts as `profile` but can change:
    /// the duplicate-name repair ("Open that one") switches this editor over to
    /// the profile that already owns the name instead of stranding the user.
    @State private var target: FocusProfile?
    @State private var draft: ProfileDraft
    @State private var domains: [String]
    @State private var domainEntry = ""
    @State private var validation = QuietValidation()
    @State private var showBlockPicker = false
    @State private var showAllowPicker = false
    @State private var showBlockedSave = false
    @State private var savedProfile: FocusProfile?
    @FocusState private var nameFocused: Bool

    init(profile: FocusProfile?,
         draft: ProfileDraft,
         onScheduleRequested: ((FocusProfile) -> Void)? = nil) {
        self.profile = profile
        self.onScheduleRequested = onScheduleRequested
        _target = State(initialValue: profile)

        var seeded = draft
        // A new profile starts with no icon chosen, so the comp's "pick one"
        // state is reachable. Editing keeps whatever the profile already has.
        if profile == nil { seeded.iconName = "" }
        _draft = State(initialValue: seeded)
        _domains = State(initialValue: Self.parseDomains(seeded.allowedWebDomains))
    }

    private let iconOptions = [
        "briefcase.fill", "book.fill", "dumbbell.fill", "brain.head.profile",
        "laptopcomputer", "pencil.and.ruler.fill", "leaf.fill", "moon.fill"
    ]
    // Quiet-spec tones: periwinkle, amber, green, purple, plus two calm extras.
    private let accentOptions = ["7C93E8", "D6A85C", "7FBE9A", "9B8AD6", "C98D9E", "78B4B4"]

    /// The longest a session may run. The comp names four hours, but the
    /// shipped Sleep profile is an eight-hour block, so the ceiling is eight —
    /// the clamp behaviour and copy shape follow the comp exactly.
    private let focusCeiling = 480

    private var tone: Color { Color(hex: draft.accentHex) }

    var body: some View {
        NavigationStack {
            Group {
                if let savedProfile {
                    ProfileSavedView(profile: savedProfile,
                                     summary: savedSummary,
                                     onStart: { start(savedProfile) },
                                     onSchedule: { schedule(savedProfile) })
                } else {
                    editor
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .familyActivityPicker(isPresented: $showBlockPicker, selection: $draft.block)
            .familyActivityPicker(isPresented: $showAllowPicker, selection: $draft.allow)
            .sheet(isPresented: $showBlockedSave) { blockedSaveSheet }
        }
        .onAppear { if target == nil { nameFocused = true } }
    }

    // MARK: - The editor (screens 09 · 10 · 11)

    private var editor: some View {
        QuietEditorScaffold(
            title: target == nil ? "New profile" : "Edit profile",
            cancelTitle: "Cancel",
            status: status,
            statusIsAlert: statusIsAlert,
            ctaTitle: target == nil ? "Create profile" : "Save changes",
            ctaIdentifier: "profile-save",
            isReady: isReady,
            tone: tone,
            onCancel: { dismiss() },
            onSubmit: submit
        ) {
            nameSection
            iconSection
            accentSection
            lengthSection
            websitesSection
            blockingSection
            strictSection
        }
    }

    // MARK: Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: "Name", color: validation.labelColor(!hasName))
            QuietTextField(placeholder: "Deep work",
                           text: $draft.name,
                           lineColor: nameLineColor)
                .focused($nameFocused)
                .submitLabel(.done)
                .accessibilityIdentifier("profile-name")

            if let duplicate = duplicateProfile {
                QuietHelperRow(text: "You already have a \(duplicate.name ?? "") profile.",
                               color: ZTheme.Palette.alert,
                               actionTitle: "Open that one",
                               tone: tone) { switchTo(duplicate) }
            } else if validation.flags(!hasName) {
                QuietHelper(text: "Give it a name — two words is plenty.",
                            color: ZTheme.Palette.alert)
            } else {
                QuietHelper(text: "Something you\u{2019}ll recognise in a hurry.")
            }
        }
    }

    private var nameLineColor: Color {
        (duplicateProfile != nil || validation.flags(!hasName))
            ? ZTheme.Palette.alert : ZTheme.Palette.glassStroke
    }

    // MARK: Icon

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: "Icon",
                            color: validation.labelColor(!hasIcon),
                            topPadding: QuietMetrics.sectionGap)
                .padding(.bottom, 12)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                      spacing: 8) {
                ForEach(iconOptions, id: \.self) { icon in
                    let isSelected = draft.iconName == icon
                    Button { Haptics.light(); draft.iconName = icon } label: {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(isSelected ? tone : ZTheme.Palette.text(0.55))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: QuietMetrics.tileRadius,
                                                 style: .continuous)
                                    .fill(isSelected ? tone.opacity(0.16)
                                          : validation.emptyFill(!hasIcon))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(icon.replacingOccurrences(of: ".", with: " ")) icon")
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .animation(ZTheme.Motion.smooth, value: draft.iconName)

            QuietHelper(text: validation.flags(!hasIcon)
                        ? "Pick one — it\u{2019}s how you\u{2019}ll spot this profile in a hurry."
                        : "Shown on the focus screen and in your schedule.",
                        color: validation.flags(!hasIcon)
                        ? ZTheme.Palette.alert : ZTheme.Palette.text(0.30))
        }
    }

    // MARK: Accent

    private var accentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: "Accent", topPadding: QuietMetrics.sectionGap)
                .padding(.bottom, 14)

            HStack(spacing: 14) {
                ForEach(accentOptions, id: \.self) { hex in
                    let isSelected = draft.accentHex.caseInsensitiveCompare(hex) == .orderedSame
                    Button { Haptics.light(); draft.accentHex = hex } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 26, height: 26)
                            .padding(3)
                            .overlay {
                                Circle()
                                    .strokeBorder(isSelected ? ZTheme.Palette.textPrimary : .clear,
                                                  lineWidth: 1.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Accent colour")
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .animation(ZTheme.Motion.smooth, value: draft.accentHex)

            QuietHelper(text: "The one bright colour this profile is allowed.")
        }
    }

    // MARK: Session length

    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: "Session length", topPadding: QuietMetrics.sectionGap)
                .padding(.bottom, 12)

            QuietStepperRow(value: "\(draft.focusMinutes) min",
                            canDecrement: draft.focusMinutes > 5,
                            canIncrement: draft.focusMinutes < focusCeiling,
                            onDecrement: { draft.focusMinutes = stepped(draft.focusMinutes, by: -1) },
                            onIncrement: { draft.focusMinutes = stepped(draft.focusMinutes, by: 1) })
            QuietHairline().padding(.top, 12)

            if draft.focusMinutes >= focusCeiling {
                QuietHelper(text: "Eight hours is the longest a session can run. Held at \(focusCeiling).",
                            color: ZTheme.Palette.warn)
            } else {
                QuietHelper(text: "How long a session runs when you start this profile.")
            }

            QuietFieldLabel(text: "Break", topPadding: QuietMetrics.sectionGap)
                .padding(.bottom, 12)
            QuietStepperRow(value: draft.breakMinutes > 0 ? "\(draft.breakMinutes) min" : "None",
                            canDecrement: draft.breakMinutes > 0,
                            canIncrement: draft.breakMinutes < 30,
                            onDecrement: { draft.breakMinutes = max(0, draft.breakMinutes - 5) },
                            onIncrement: { draft.breakMinutes = min(30, draft.breakMinutes + 5) })
            QuietHairline().padding(.top, 12)
            QuietHelper(text: draft.breakMinutes > 0
                        ? "Offered when the session finishes."
                        : "No break — the session simply ends.")
        }
    }

    /// Coarser steps as the number grows, so an eight-hour Sleep block isn't
    /// ninety taps away from twenty-five minutes.
    private func stepped(_ minutes: Int, by direction: Int) -> Int {
        let size: Int
        switch minutes {
        case ..<60:   size = 5
        case ..<240:  size = 15
        default:      size = 30
        }
        // Stepping down from a boundary should use the lower band's step.
        let downSize: Int
        switch minutes {
        case ...60:   downSize = 5
        case ...240:  downSize = 15
        default:      downSize = 30
        }
        let delta = direction > 0 ? size : -downSize
        return min(focusCeiling, max(5, minutes + delta))
    }

    // MARK: Allowed websites

    private var websitesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuietFieldLabel(text: "Allowed websites",
                            color: validation.flags(!badDomains.isEmpty)
                            ? ZTheme.Palette.alert : ZTheme.Palette.text(0.30),
                            topPadding: QuietMetrics.sectionGap)
                .padding(.bottom, 12)

            if !domains.isEmpty {
                QuietFlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(domains, id: \.self) { domain in
                        domainChip(domain)
                    }
                }
                .padding(.bottom, 10)
            }

            TextField("Add a website", text: $domainEntry)
                .textFieldStyle(.plain)
                .font(ZTheme.Font.body(15))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .tint(tone)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .submitLabel(.done)
                .accessibilityIdentifier("profile-domain-entry")
                .onSubmit(commitDomainEntry)
                .padding(.bottom, 9)
            QuietHairline()

            if let bad = badDomains.first, let fix = Self.repair(bad) {
                QuietHelperRow(text: Self.domainProblem(bad),
                               color: ZTheme.Palette.alert,
                               actionTitle: "Use \(fix)",
                               tone: tone) { replace(bad, with: fix) }
            } else if let bad = badDomains.first {
                QuietHelper(text: Self.domainProblem(bad), color: ZTheme.Palette.alert)
            } else if domains.isEmpty {
                QuietHelper(text: "Leave this empty and the whole web stays open.")
            } else {
                QuietHelper(text: "During focus, Safari is held to just these. Tap one to remove it.")
            }
        }
    }

    private func domainChip(_ domain: String) -> some View {
        let isBad = !Self.isValidDomain(domain)
        return Button { Haptics.light(); domains.removeAll { $0 == domain } } label: {
            Text(domain)
                .font(ZTheme.Font.body(13))
                .foregroundStyle(isBad ? ZTheme.Palette.alert : ZTheme.Palette.textPrimary)
                .underline(isBad)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isBad ? ZTheme.Palette.alertSoft : ZTheme.Palette.glassFill)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(domain)")
    }

    // MARK: Blocking

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

    // MARK: - Couldn't save (screen 12)

    private var blockedSaveSheet: some View {
        QuietBlockedSaveSheet(
            eyebrow: "Couldn\u{2019}t save",
            title: "Blocking apps needs iOS\u{2019}s permission",
            message: "Screen Time access is off, so Zen-ly can\u{2019}t hold apps back yet. Everything you typed is kept.",
            primaryTitle: "Allow in Settings",
            secondaryTitle: "Save it without blocking",
            tone: tone,
            onPrimary: requestAccess,
            onSecondary: saveWithoutBlocking
        )
    }

    private func requestAccess() {
        Task {
            await authorization.requestAuthorization()
            if authorization.isAuthorized {
                showBlockedSave = false
                persist()
            } else if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
        }
    }

    private func saveWithoutBlocking() {
        draft.blockAllApps = false
        draft.block = FamilyActivitySelection()
        showBlockedSave = false
        persist()
    }

    // MARK: - Saved (screen 13)

    private var savedSummary: String {
        let minutes = "\(draft.focusMinutes) minutes"
        let valid = domains.filter(Self.isValidDomain)
        if !valid.isEmpty {
            return "\(minutes), everything blocked but \(Self.readableList(valid.map(Self.siteLabel)))."
        }
        if draft.blockAllApps {
            return "\(minutes) with everything else held back."
        }
        return blockCount > 0
            ? "\(minutes), blocking the \(blockCount) app\(blockCount == 1 ? "" : "s") you picked."
            : "\(minutes), with nothing blocked yet."
    }

    private func start(_ profile: FocusProfile) {
        session.startFocus(profileName: profile.name ?? draft.name,
                           accentHex: draft.accentHex,
                           focusMinutes: draft.focusMinutes,
                           breakMinutes: draft.breakMinutes,
                           isStrict: draft.isStrict,
                           blockAll: draft.blockAllApps,
                           allowedWebDomains: domains.filter(Self.isValidDomain),
                           block: draft.block,
                           allow: draft.allow)
        store.setActive(profile)
        dismiss()
    }

    private func schedule(_ profile: FocusProfile) {
        dismiss()
        onScheduleRequested?(profile)
    }

    // MARK: - Validation

    private var hasName: Bool { !draft.name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var hasIcon: Bool { !draft.iconName.isEmpty }

    /// A different profile that already owns this name. Live, not deferred —
    /// the comp shows it the moment the collision exists, because the user can
    /// act on it (open that one) rather than only being told off.
    private var duplicateProfile: FocusProfile? {
        let trimmed = draft.name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return store.profiles.first {
            $0.objectID != target?.objectID
                && ($0.name ?? "").caseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    private var badDomains: [String] { domains.filter { !Self.isValidDomain($0) } }

    private var isReady: Bool {
        hasName && hasIcon && duplicateProfile == nil && badDomains.isEmpty
    }

    /// A duplicate name and a broken website are shown as soon as they exist —
    /// both are already spelled out on screen with a repair beside them, so the
    /// footer must agree rather than still reading "a name and an icon".
    private var statusIsAlert: Bool {
        !isReady && (validation.hasTriedToSave
                     || duplicateProfile != nil
                     || !badDomains.isEmpty)
    }

    /// The footer sentence. Counts what is *missing* separately from what needs
    /// a *fix*, because the comp words them differently (09/10 vs 11).
    private var status: String {
        guard statusIsAlert else {
            if isReady { return "Ready when you are" }
            return "A name and an icon is all it takes"
        }
        let missing = (hasName ? 0 : 1) + (hasIcon ? 0 : 1)
        let fixes = (duplicateProfile == nil ? 0 : 1) + (badDomains.isEmpty ? 0 : 1)

        if missing > 0 && fixes == 0 {
            return missing == 2 ? "Two things left, both above" : "One thing left, just above"
        }
        if fixes > 0 && missing == 0 {
            return fixes == 2 ? "Two entries need a small fix" : "One entry needs a small fix"
        }
        return "A few things above still need you"
    }

    // MARK: - Actions

    private func submit() {
        commitDomainEntry()
        guard isReady else {
            validation.flagMissingFields()
            Haptics.light()
            return
        }
        // Screen 12: blocking was asked for but iOS hasn't granted the access
        // that makes it possible. Nothing is discarded — the draft stays put.
        if wantsBlocking && !authorization.isAuthorized {
            showBlockedSave = true
            return
        }
        persist()
    }

    private var wantsBlocking: Bool { draft.blockAllApps || blockCount > 0 }

    private func persist() {
        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
        draft.allowedWebDomains = domains.filter(Self.isValidDomain).joined(separator: ", ")

        if let target {
            store.update(target, with: draft)
            dismiss()
        } else {
            let created = store.create(from: draft)
            savedProfile = created          // screen 13 replaces the editor
        }
    }

    private func switchTo(_ profile: FocusProfile) {
        target = profile
        draft = store.draft(from: profile)
        domains = Self.parseDomains(draft.allowedWebDomains)
        domainEntry = ""
        validation = QuietValidation()
        nameFocused = false
    }

    private func commitDomainEntry() {
        let entry = domainEntry.trimmingCharacters(in: .whitespaces)
        guard !entry.isEmpty else { return }
        if !domains.contains(entry) { domains.append(entry) }
        domainEntry = ""
    }

    private func replace(_ domain: String, with fixed: String) {
        guard let index = domains.firstIndex(of: domain) else { return }
        if domains.contains(fixed) {
            domains.remove(at: index)
        } else {
            domains[index] = fixed
        }
    }

    // MARK: - Helpers

    private var blockCount: Int {
        draft.block.applicationTokens.count
            + draft.block.categoryTokens.count
            + draft.block.webDomainTokens.count
    }

    private func countText(_ count: Int) -> String {
        count == 0 ? "None" : "\(count)"
    }

    // MARK: Domain parsing

    static func parseDomains(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// A host, and nothing else: labels of letters/digits/hyphens joined by dots,
    /// with at least one dot and an alphabetic last label.
    static func isValidDomain(_ candidate: String) -> Bool {
        let host = candidate.trimmingCharacters(in: .whitespaces).lowercased()
        guard !host.isEmpty, host.count <= 253 else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        guard let last = labels.last, last.count >= 2,
              last.allSatisfy({ $0.isLetter }) else { return false }
        return labels.allSatisfy { label in
            !label.isEmpty && label.count <= 63
                && label.first != "-" && label.last != "-"
                && label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        }
    }

    /// Why this entry isn't a website — specific where we can be.
    static func domainProblem(_ candidate: String) -> String {
        if candidate.contains(",") { return "That comma makes it not a website." }
        if candidate.contains(" ") { return "A website can\u{2019}t have a space in it." }
        if !candidate.contains(".") { return "That\u{2019}s missing its ending — .com, .ai, and so on." }
        return "That isn\u{2019}t a website Zen-ly can recognise."
    }

    /// The comp's one-tap repair: fix the obvious typo if the result is a real
    /// host, otherwise offer nothing rather than a wrong guess.
    static func repair(_ candidate: String) -> String? {
        var fixed = candidate.trimmingCharacters(in: .whitespaces).lowercased()
        for prefix in ["https://", "http://"] where fixed.hasPrefix(prefix) {
            fixed.removeFirst(prefix.count)
        }
        if let slash = fixed.firstIndex(of: "/") { fixed = String(fixed[fixed.startIndex..<slash]) }
        fixed = fixed
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
        while fixed.hasPrefix(".") { fixed.removeFirst() }
        while fixed.hasSuffix(".") { fixed.removeLast() }
        guard fixed != candidate, isValidDomain(fixed) else { return nil }
        return fixed
    }

    /// "claude.ai" → "Claude", "docs.google.com" → "Docs" — the name a person
    /// would say, for the saved screen's one-line summary.
    static func siteLabel(_ domain: String) -> String {
        let labels = domain.split(separator: ".")
        guard let first = labels.first else { return domain }
        let name = (first == "www" && labels.count > 1) ? labels[1] : first
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    static func readableList(_ items: [String]) -> String {
        switch items.count {
        case 0:  return ""
        case 1:  return items[0]
        case 2:  return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + " and \(items.last!)"
        }
    }
}

// MARK: - Saved (screen 13)

/// The confirmation the comp shows after a profile is created: an eyebrow, the
/// new profile's icon inside its own halo, one plain sentence about what it
/// will do, and the two things worth doing next.
private struct ProfileSavedView: View {
    let profile: FocusProfile
    let summary: String
    let onStart: () -> Void
    let onSchedule: () -> Void

    private var tone: Color { ZTheme.tone(forHex: profile.accentHex) }
    private var name: String { profile.name ?? "" }

    var body: some View {
        ZStack {
            ZenlyBackground()

            VStack(spacing: 0) {
                Text("PROFILE ADDED")
                    .font(ZTheme.Font.body(11))
                    .tracking(3.08)
                    .foregroundStyle(ZTheme.Palette.text(0.30))
                    .padding(.top, 40)

                Spacer(minLength: 0)

                // The halo and the sentence read as one object in the middle of
                // the screen, the way the comp centres them together.
                ZStack {
                    Circle()
                        .fill(ZTheme.orbHalo(tone: tone, diameter: 150))
                        .frame(width: 150, height: 150)
                    Image(systemName: profile.iconName ?? "circle")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(tone)
                }
                .frame(width: 168, height: 168)

                VStack(spacing: 8) {
                    Text("\(name) is ready")
                        .font(ZTheme.Font.display(22, weight: .semibold))
                        .foregroundStyle(ZTheme.Palette.textPrimary)
                    Text(summary)
                        .font(ZTheme.Font.body(14))
                        .foregroundStyle(ZTheme.Palette.text(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 250)
                }
                .padding(.top, 4)

                Spacer(minLength: 0)

                VStack(spacing: 4) {
                    Button("Start a \(name) session") { onStart() }
                        .buttonStyle(QuietCTAStyle(tone: tone, isReady: true))
                        .accessibilityIdentifier("profile-saved-start")
                    Button("Put it on the schedule") { Haptics.light(); onSchedule() }
                        .font(ZTheme.Font.body(14))
                        .foregroundStyle(ZTheme.Palette.text(0.55))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 16)
        }
    }
}
