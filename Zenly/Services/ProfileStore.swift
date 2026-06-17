//
//  ProfileStore.swift
//  Zenly
//
//  Owns FocusProfiles (Core Data) and the active-profile selection. Seeds the
//  three default profiles (Work / Study / Gym) on first launch. A profile
//  bundles a block/allow selection, strict mode, and focus/break lengths — the
//  unit a focus session is started from.
//

import Foundation
import CoreData
import FamilyControls
import Observation

/// Editable representation of a profile, used by the edit screen.
struct ProfileDraft {
    var name: String = ""
    var iconName: String = "brain.head.profile"
    var accentHex: String = "5C6BFA"
    var focusMinutes: Int = 25
    var breakMinutes: Int = 5
    var isStrict: Bool = false
    var blockAllApps: Bool = true
    var block = FamilyActivitySelection()
    var allow = FamilyActivitySelection()
}

@Observable
@MainActor
final class ProfileStore {
    private(set) var profiles: [FocusProfile] = []

    var activeProfileID: UUID? {
        didSet { AppGroup.defaults.set(activeProfileID?.uuidString, forKey: activeKey) }
    }

    private let context: NSManagedObjectContext
    private let activeKey = "activeProfileID"

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        if let stored = AppGroup.defaults.string(forKey: activeKey) {
            activeProfileID = UUID(uuidString: stored)
        }
        seedDefaultsIfNeeded()
        fetch()
    }

    var activeProfile: FocusProfile? {
        profiles.first { $0.id == activeProfileID } ?? profiles.first
    }

    func fetch() {
        let request = FocusProfile.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusProfile.sortIndex, ascending: true)]
        profiles = (try? context.fetch(request)) ?? []
        if activeProfileID == nil { activeProfileID = profiles.first?.id }
    }

    func setActive(_ profile: FocusProfile) {
        activeProfileID = profile.id
    }

    func block(for profile: FocusProfile) -> FamilyActivitySelection {
        SelectionCodec.decode(profile.blockSelectionData)
    }

    func allow(for profile: FocusProfile) -> FamilyActivitySelection {
        SelectionCodec.decode(profile.allowSelectionData)
    }

    func draft(from profile: FocusProfile) -> ProfileDraft {
        ProfileDraft(
            name: profile.name ?? "",
            iconName: profile.iconName ?? "brain.head.profile",
            accentHex: profile.accentHex ?? "5C6BFA",
            focusMinutes: Int(profile.focusMinutes),
            breakMinutes: Int(profile.breakMinutes),
            isStrict: profile.isStrict,
            blockAllApps: profile.blockAllApps,
            block: SelectionCodec.decode(profile.blockSelectionData),
            allow: SelectionCodec.decode(profile.allowSelectionData)
        )
    }

    @discardableResult
    func create(from draft: ProfileDraft) -> FocusProfile {
        let profile = FocusProfile(context: context)
        profile.id = UUID()
        profile.createdAt = Date()
        profile.sortIndex = Int16(profiles.count)
        apply(draft, to: profile)
        save()
        fetch()
        return profile
    }

    func update(_ profile: FocusProfile, with draft: ProfileDraft) {
        apply(draft, to: profile)
        save()
        fetch()
    }

    func delete(_ profile: FocusProfile) {
        let wasActive = profile.id == activeProfileID
        context.delete(profile)
        save()
        fetch()
        if wasActive { activeProfileID = profiles.first?.id }
    }

    // MARK: - Private

    private func apply(_ draft: ProfileDraft, to profile: FocusProfile) {
        profile.name = draft.name
        profile.iconName = draft.iconName
        profile.accentHex = draft.accentHex
        profile.focusMinutes = Int16(draft.focusMinutes)
        profile.breakMinutes = Int16(draft.breakMinutes)
        profile.isStrict = draft.isStrict
        profile.blockAllApps = draft.blockAllApps
        profile.blockSelectionData = SelectionCodec.encode(draft.block)
        profile.allowSelectionData = SelectionCodec.encode(draft.allow)
    }

    private func save() {
        guard context.hasChanges else { return }
        do { try context.save() }
        catch { print("[Zenly] ProfileStore save failed: \(error)") }
    }

    private func seedDefaultsIfNeeded() {
        let request = FocusProfile.fetchRequest()
        let count = (try? context.count(for: request)) ?? 0
        guard count == 0 else { return }

        let defaults: [ProfileDraft] = [
            ProfileDraft(name: "Work", iconName: "briefcase.fill", accentHex: "5C6BFA",
                         focusMinutes: 25, breakMinutes: 5),
            ProfileDraft(name: "Study", iconName: "book.fill", accentHex: "34C759",
                         focusMinutes: 50, breakMinutes: 10),
            ProfileDraft(name: "Gym", iconName: "dumbbell.fill", accentHex: "FF9F0A",
                         focusMinutes: 60, breakMinutes: 0)
        ]

        for (index, draft) in defaults.enumerated() {
            let profile = FocusProfile(context: context)
            profile.id = UUID()
            profile.createdAt = Date()
            profile.sortIndex = Int16(index)
            apply(draft, to: profile)
        }
        save()
    }
}
