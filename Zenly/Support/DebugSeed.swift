//
//  DebugSeed.swift
//  Zenly
//
//  DEBUG-only launch hooks that make the screens which need *state* possible to
//  look at on a Simulator.
//
//  Three of the Quiet comp's screens cannot be reached there under their own
//  power. 03 (App paused) is drawn by iOS from inside the shield extension and
//  needs a Screen Time shield, which Simulator will not grant. 05 (Insights)
//  needs a week of completed sessions. 04 / 04b need a session that has run and
//  finished. Without a way in, the only screens anyone ever sees while building
//  are the empty ones.
//
//  Everything here is gated twice: the file is compiled out of Release entirely,
//  and each hook is inert unless its launch argument is passed. Nothing writes
//  to Core Data unless asked.
//
//  Every seeded row carries the `demoMarker` in its note, so the rows say on
//  screen that they are demo data and the seeder can recognise its own work.
//

#if DEBUG

import CoreData
import Foundation

enum DebugSeed {

    /// Prefixed onto every seeded note. Visible on screen on purpose: a history
    /// row that looks exactly like real history is how fake data gets mistaken
    /// for a bug report.
    static let demoMarker = "Demo"

    // MARK: - Launch arguments

    /// `ZenlyPreviewShield Instagram` — stand screen 03 up as the app's root.
    ///
    /// No leading dash: NSUserDefaults parses `-key value` pairs out of the
    /// argument list, so a lone `-flag` corrupts the defaults around it.
    static var shieldPreviewSubject: String? {
        argument(after: "ZenlyPreviewShield")
    }

    /// `ZenlyPreviewBlockScreen Instagram` — stand screen 03 (the block screen)
    /// up as the app's root. iOS draws the real one and Simulator cannot raise
    /// a shield at all, so this is the only way to look at it while building.
    static var blockScreenPreviewSubject: String? {
        argument(after: "ZenlyPreviewBlockScreen")
    }

    /// The value following `flag`, defaulting to "Instagram".
    private static func argument(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let next = arguments.index(after: index)
        guard next < arguments.count else { return "Instagram" }
        let value = arguments[next]
        return value.hasPrefix("-") ? "Instagram" : value
    }

    /// `ZenlySeedDemoHistory` — fill this calendar week with focus sessions so
    /// Insights renders its populated state instead of its first-run state.
    static var wantsDemoHistory: Bool {
        ProcessInfo.processInfo.arguments.contains("ZenlySeedDemoHistory")
    }

    /// `ZenlySeedManyProfiles` — add enough profiles that Home's switcher row
    /// stops fitting and has to scroll.
    ///
    /// The row spreads to fill the width while the names fit and overflows once
    /// they don't (`QuietSpreadRow`). The second half of that is unreachable on
    /// a default install, which ships four short names — so without this the
    /// only way to see the scrolling state is to sit and create profiles by
    /// hand, which nobody does, which is how that state goes unlooked-at.
    static var wantsManyProfiles: Bool {
        ProcessInfo.processInfo.arguments.contains("ZenlySeedManyProfiles")
    }

    /// The block screen quotes a running session ("Back at 7:43 · 16 minutes")
    /// and goes quiet when there isn't one. Previewing it against an empty App
    /// Group would therefore show the screen with its last line missing — the
    /// one line the person standing in front of it is waiting to read. So the
    /// preview puts a session there first.
    ///
    /// Sixteen minutes because that is what the comp shows.
    static func primeShieldPreviewSession() {
        guard shieldPreviewSubject != nil || blockScreenPreviewSubject != nil else { return }
        ActiveSessionInfo.set(profileName: "Work",
                              endsAt: Date().addingTimeInterval(16 * 60))
    }

    // MARK: - Seeding

    /// Four more profiles, so Home's switcher has eight names and must scroll.
    ///
    /// Idempotent, like the history seed: names carry the `demoMarker` so a
    /// relaunch inside one test does not keep adding to the row.
    @MainActor
    static func seedManyProfilesIfRequested(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    ) {
        guard wantsManyProfiles else { return }

        let request = FocusProfile.fetchRequest()
        request.predicate = NSPredicate(format: "name BEGINSWITH %@", demoMarker)
        request.fetchLimit = 1
        guard ((try? context.count(for: request)) ?? 0) == 0 else { return }

        let existing = (try? context.count(for: FocusProfile.fetchRequest())) ?? 0
        let plan = [("Reading", "D6A85C", 45), ("Writing", "7C93E8", 90),
                    ("Practice", "7FBE9A", 30), ("Wind down", "9B8AD6", 20)]

        for (index, entry) in plan.enumerated() {
            let profile = FocusProfile(context: context)
            profile.id = UUID()
            profile.name = "\(demoMarker) \(entry.0)"
            profile.accentHex = entry.1
            profile.focusMinutes = Int16(entry.2)
            profile.breakMinutes = 5
            profile.sortIndex = Int16(existing + index)
        }

        try? context.save()
    }

    /// A week of completed sessions shaped like the comp's chart: a clear best
    /// day, a couple of thin ones, and today part-way up.
    ///
    /// Idempotent — re-running against an already-seeded store does nothing, so
    /// a relaunch inside one test does not double the totals.
    @MainActor
    static func seedDemoHistoryIfRequested(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    ) {
        guard wantsDemoHistory, !isSeeded(in: context) else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start
        else { return }

        // dayOffset, minutes, profile, what it was. Days after today are left
        // out — a chart with the future already filled in is one nobody believes.
        let plan: [(Int, Int, String, String)] = [
            (0, 56,  "Work",  "Inbox"),
            (1, 80,  "Study", "Reading"),
            (2, 43,  "Gym",   "Workout"),
            (3, 110, "Work",  "Deep focus"),
            (4, 93,  "Work",  "Deep focus"),
            (5, 33,  "Study", "Notes"),
            (6, 17,  "Sleep", "Wind down")
        ]

        let todayOffset = calendar.dateComponents([.day], from: weekStart, to: today).day ?? 0

        for (offset, minutes, profile, what) in plan where offset <= todayOffset {
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart),
                  let started = calendar.date(byAdding: .hour, value: 9, to: day),
                  let ended = calendar.date(byAdding: .minute, value: minutes, to: started)
            else { continue }

            let session = FocusSession(context: context)
            session.id = UUID()
            session.profileName = profile
            session.plannedMinutes = Int16(minutes)
            session.completedMinutes = Int16(minutes)
            session.kind = "focus"
            session.wasCompleted = true
            session.endedEarly = false
            session.startedAt = started
            session.endedAt = ended
            session.note = "\(demoMarker) · \(what)"
        }

        try? context.save()
    }

    private static func isSeeded(in context: NSManagedObjectContext) -> Bool {
        let request = FocusSession.fetchRequest()
        request.predicate = NSPredicate(format: "note BEGINSWITH %@", demoMarker)
        request.fetchLimit = 1
        return ((try? context.count(for: request)) ?? 0) > 0
    }
}

#endif
