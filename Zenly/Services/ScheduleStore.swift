//
//  ScheduleStore.swift
//  Zenly
//
//  Owns recurring FocusSchedules (Core Data) and keeps their DeviceActivity
//  monitoring in sync. Each enabled schedule registers one daily monitoring
//  window; the extension applies shields only on the schedule's weekdays.
//

import Foundation
import CoreData
import DeviceActivity
import FamilyControls
import Observation

struct ScheduleDraft {
    var title = ""
    var startHour = 9
    var startMinute = 0
    var endHour = 17
    var endMinute = 0
    var weekdays: Set<Int> = [2, 3, 4, 5, 6] // Mon–Fri (1=Sun…7=Sat)
    var isStrict = false
    var blockAllApps = true
    var block = FamilyActivitySelection()
    var allow = FamilyActivitySelection()
    /// Optional profile this schedule is tied to — supplies the accent color and
    /// session name when the window auto-starts an in-app session.
    var profileName = ""
}

@Observable
@MainActor
final class ScheduleStore {
    private(set) var schedules: [FocusSchedule] = []

    private let context: NSManagedObjectContext
    private let center = ScheduleCenter.shared
    private let blocking = BlockingService()

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        fetch()
        reactivateAll()
    }

    func fetch() {
        let request = FocusSchedule.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSchedule.startHour, ascending: true)]
        schedules = (try? context.fetch(request)) ?? []
    }

    func draft(from schedule: FocusSchedule) -> ScheduleDraft {
        ScheduleDraft(
            title: schedule.title ?? "",
            startHour: Int(schedule.startHour),
            startMinute: Int(schedule.startMinute),
            endHour: Int(schedule.endHour),
            endMinute: Int(schedule.endMinute),
            weekdays: Self.weekdays(from: schedule.weekdaysMask),
            isStrict: schedule.isStrict,
            blockAllApps: schedule.blockAllApps,
            block: SelectionCodec.decode(schedule.blockSelectionData),
            allow: SelectionCodec.decode(schedule.allowSelectionData),
            profileName: schedule.profileName ?? ""
        )
    }

    func create(from draft: ScheduleDraft) {
        let schedule = FocusSchedule(context: context)
        schedule.id = UUID()
        schedule.isEnabled = true
        apply(draft, to: schedule)
        save()
        fetch()
        startMonitoring(schedule)
    }

    func update(_ schedule: FocusSchedule, with draft: ScheduleDraft) {
        stopMonitoring(schedule)
        apply(draft, to: schedule)
        save()
        fetch()
        if schedule.isEnabled { startMonitoring(schedule) }
    }

    func delete(_ schedule: FocusSchedule) {
        stopMonitoring(schedule)
        context.delete(schedule)
        save()
        fetch()
    }

    func setEnabled(_ schedule: FocusSchedule, _ enabled: Bool) {
        schedule.isEnabled = enabled
        save() // the row observes the schedule (@ObservedObject) and updates in place;
               // no fetch() here — re-fetching mid-tap rebuilds the list and reverts the toggle.
        if enabled { startMonitoring(schedule) } else { stopMonitoring(schedule) }
    }

    /// Re-register monitoring for every enabled schedule. Call after Screen Time
    /// access is granted — the initial `startMonitoring` is a silent no-op while
    /// unauthorized, so schedules created before consent must be re-armed.
    func rearmEnabled() {
        reactivateAll()
    }

    func weekdaySummary(_ schedule: FocusSchedule) -> String {
        Self.summary(for: Self.weekdays(from: schedule.weekdaysMask))
    }

    // MARK: - Glanceable status

    /// Live state of a schedule relative to `now`, for the Schedule cards.
    enum ScheduleStatus {
        case off                    // disabled
        case active(endsAt: Date)   // running right now
        case upcoming(at: Date)     // next start time
        case idle                   // enabled but no upcoming run found
    }

    func status(for schedule: FocusSchedule, now: Date = Date()) -> ScheduleStatus {
        guard schedule.isEnabled else { return .off }
        let days = Self.weekdays(from: schedule.weekdaysMask)
        guard !days.isEmpty else { return .idle }

        let cal = Calendar.current
        let sH = Int(schedule.startHour), sM = Int(schedule.startMinute)
        let eH = Int(schedule.endHour), eM = Int(schedule.endMinute)

        func date(_ dayOffset: Int, _ hour: Int, _ minute: Int) -> Date? {
            guard let base = cal.date(byAdding: .day, value: dayOffset, to: now) else { return nil }
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: base)
        }

        // Active right now? Handles windows that wrap past midnight (end ≤ start),
        // e.g. 22:00 → 06:00, whose post-midnight tail belongs to the PREVIOUS
        // day's weekday selection.
        let today = cal.component(.weekday, from: now)
        let overnight = (eH * 60 + eM) <= (sH * 60 + sM)
        if overnight {
            // Evening portion: started today, ends tomorrow.
            if days.contains(today),
               let start = date(0, sH, sM), let end = date(1, eH, eM),
               now >= start, now < end {
                return .active(endsAt: end)
            }
            // Early-morning portion: started yesterday, ends today.
            let yesterday = today == 1 ? 7 : today - 1
            if days.contains(yesterday),
               let start = date(-1, sH, sM), let end = date(0, eH, eM),
               now >= start, now < end {
                return .active(endsAt: end)
            }
        } else if days.contains(today),
                  let start = date(0, sH, sM), let end = date(0, eH, eM),
                  now >= start, now < end {
            return .active(endsAt: end)
        }

        // Next start within the coming week.
        for offset in 0...7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            let wd = cal.component(.weekday, from: day)
            guard days.contains(wd), let start = date(offset, sH, sM), start > now else { continue }
            return .upcoming(at: start)
        }
        return .idle
    }

    // MARK: - Auto-start queries

    /// The first enabled schedule whose focus window is active right now — the
    /// candidate to auto-start an in-app session for.
    func activeNow(_ now: Date = Date()) -> FocusSchedule? {
        schedules.first { schedule in
            if case .active = status(for: schedule, now: now) { return true }
            return false
        }
    }

    /// The enabled schedule whose window opens within `seconds` from now (the
    /// last-minute countdown target), plus its start Date — nil if none imminent.
    func startingSoon(_ now: Date = Date(), within seconds: TimeInterval = 60) -> (FocusSchedule, Date)? {
        for schedule in schedules where schedule.isEnabled {
            if case .upcoming(let at) = status(for: schedule, now: now) {
                let delta = at.timeIntervalSince(now)
                if delta > 0, delta <= seconds { return (schedule, at) }
            }
        }
        return nil
    }

    /// Whole minutes left until the active window closes (≥1), so an auto-started
    /// session runs for exactly the remaining window.
    func remainingMinutes(for schedule: FocusSchedule, now: Date = Date()) -> Int {
        guard case .active(let endsAt) = status(for: schedule, now: now) else { return 0 }
        return max(1, Int(endsAt.timeIntervalSince(now) / 60))
    }

    /// "8h" / "1h30" / "45m" length of the window.
    func durationText(for schedule: FocusSchedule) -> String {
        let raw = (Int(schedule.endHour) * 60 + Int(schedule.endMinute))
            - (Int(schedule.startHour) * 60 + Int(schedule.startMinute))
        let mins = raw > 0 ? raw : raw + 24 * 60
        let h = mins / 60, m = mins % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h\(m)"
    }

    /// What the schedule blocks, for the card subtitle.
    func blockingSummary(for schedule: FocusSchedule) -> String {
        if schedule.blockAllApps { return "Blocks all apps" }
        let sel = SelectionCodec.decode(schedule.blockSelectionData)
        let n = sel.applicationTokens.count + sel.categoryTokens.count + sel.webDomainTokens.count
        return n == 0 ? "Nothing blocked" : "\(n) app\(n == 1 ? "" : "s") blocked"
    }

    // MARK: - Weekday helpers

    static func mask(from weekdays: Set<Int>) -> Int16 {
        var mask = 0
        for day in weekdays { mask |= (1 << day) }
        return Int16(mask)
    }

    static func weekdays(from mask: Int16) -> Set<Int> {
        Set((1...7).filter { (Int(mask) & (1 << $0)) != 0 })
    }

    static func summary(for weekdays: Set<Int>) -> String {
        if weekdays == [2, 3, 4, 5, 6] { return "Weekdays" }
        if weekdays == [1, 7] { return "Weekends" }
        if weekdays.count == 7 { return "Every day" }
        let symbols = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return weekdays.sorted().map { symbols[$0] }.joined(separator: " ")
    }

    // MARK: - Private

    private func apply(_ draft: ScheduleDraft, to schedule: FocusSchedule) {
        schedule.title = draft.title
        schedule.startHour = Int16(draft.startHour)
        schedule.startMinute = Int16(draft.startMinute)
        schedule.endHour = Int16(draft.endHour)
        schedule.endMinute = Int16(draft.endMinute)
        schedule.weekdaysMask = Self.mask(from: draft.weekdays)
        schedule.isStrict = draft.isStrict
        schedule.blockAllApps = draft.blockAllApps
        schedule.blockSelectionData = SelectionCodec.encode(draft.block)
        schedule.allowSelectionData = SelectionCodec.encode(draft.allow)
        schedule.profileName = draft.profileName.isEmpty ? nil : draft.profileName
    }

    private func activityName(_ schedule: FocusSchedule) -> DeviceActivityName {
        DeviceActivityName("zenly.schedule.\(schedule.id?.uuidString ?? UUID().uuidString)")
    }

    private func startMonitoring(_ schedule: FocusSchedule) {
        var start = DateComponents()
        start.hour = Int(schedule.startHour)
        start.minute = Int(schedule.startMinute)
        var end = DateComponents()
        end.hour = Int(schedule.endHour)
        end.minute = Int(schedule.endMinute)

        center.startRecurring(
            activity: activityName(schedule),
            block: SelectionCodec.decode(schedule.blockSelectionData),
            allow: SelectionCodec.decode(schedule.allowSelectionData),
            blockAll: schedule.blockAllApps,
            start: start,
            end: end,
            weekdaysMask: Int(schedule.weekdaysMask)
        )

        // If the window is already open right now, apply the shields immediately.
        // iOS only fires the extension's intervalDidStart at the start boundary and
        // won't do so retroactively for an in-progress interval — so arming a
        // currently-active schedule (or relaunching mid-window) would otherwise not
        // block until tomorrow. This closes that gap. Reconcile (not startBlocking)
        // so composing with any OTHER already-active schedule instead of clobbering
        // it — the store entry was just written by center.startRecurring above.
        if case .active = status(for: schedule) {
            blocking.reconcile()
        }

        let displayTitle = schedule.title?.isEmpty == false ? schedule.title! : "Focus block"

        // A heads-up notification 15 min before the block (independent of Screen
        // Time access — only needs notification permission).
        NotificationService.shared.scheduleStartReminders(
            scheduleID: schedule.id ?? UUID(),
            title: displayTitle,
            startHour: Int(schedule.startHour),
            startMinute: Int(schedule.startMinute),
            weekdays: Self.weekdays(from: schedule.weekdaysMask)
        )

        // A notification AT the start time. iOS can't auto-launch the app from the
        // background, so this is the user's one tap into the running session;
        // opening the app triggers ScheduleAutoStart, which begins the session.
        NotificationService.shared.scheduleStartAlerts(
            scheduleID: schedule.id ?? UUID(),
            title: displayTitle,
            startHour: Int(schedule.startHour),
            startMinute: Int(schedule.startMinute),
            weekdays: Self.weekdays(from: schedule.weekdaysMask)
        )
    }

    private func stopMonitoring(_ schedule: FocusSchedule) {
        center.stop(activityName(schedule))
        // center.stop removed this schedule's shield entry; reconcile so that if
        // its window was active RIGHT NOW, the shields lift immediately (iOS does
        // not fire intervalDidEnd when monitoring is stopped) — or recompose if
        // another schedule still overlaps. Fixes apps staying blocked after a
        // disable/delete mid-window.
        blocking.reconcile()
        if let id = schedule.id {
            NotificationService.shared.cancelStartReminders(scheduleID: id)
            NotificationService.shared.cancelStartAlerts(scheduleID: id)
        }
    }

    private func reactivateAll() {
        for schedule in schedules where schedule.isEnabled {
            startMonitoring(schedule)
        }
    }

    private func save() {
        guard context.hasChanges else { return }
        do { try context.save() }
        catch { print("[Zenly] ScheduleStore save failed: \(error)") }
    }
}

// MARK: - Auto-start

/// Converts "a schedule's window is active right now" into a real in-app focus
/// session — the same flow as tapping Start Focus. Runs only while the app is in
/// the foreground (iOS forbids self-launch from the background); the start-time
/// notification covers the backgrounded case by prompting the user to open the app.
enum ScheduleAutoStart {
    @MainActor
    static func run(schedules: ScheduleStore,
                    session: FocusSessionController,
                    profiles: ProfileStore) {
        // Don't interrupt a session the user is already in.
        guard session.phase == .idle,
              let schedule = schedules.activeNow(),
              let id = schedule.id,
              !ScheduleAutoStartLog.didStart(id) else { return }

        let minutes = schedules.remainingMinutes(for: schedule)
        guard minutes >= 1 else { return }

        // Mark before starting so a manual "end early" doesn't re-trigger while the
        // window is still open, and so the 30s watcher fires only once per window.
        ScheduleAutoStartLog.markStarted(id)

        let profile = profiles.profiles.first { $0.name == schedule.profileName }
        let name = schedule.title?.isEmpty == false
            ? schedule.title!
            : (schedule.profileName?.isEmpty == false ? schedule.profileName! : "Focus block")

        session.startFocus(
            profileName: name,
            accentHex: profile?.accentHex ?? "1A3FA8",
            focusMinutes: minutes,
            breakMinutes: 0,
            isStrict: schedule.isStrict,
            blockAll: schedule.blockAllApps,
            allowedWebDomains: [],
            block: SelectionCodec.decode(schedule.blockSelectionData),
            allow: SelectionCodec.decode(schedule.allowSelectionData)
        )
    }
}

/// Shows the last-minute Dynamic Island / Live Activity countdown to a scheduled
/// window's start. Foreground-only (a Live Activity can't be *started* in the
/// background without a push server) — but once started, iOS keeps the timer
/// ticking natively even after the app backgrounds, so it counts down to 0:00 on
/// its own. When the window opens, `ScheduleAutoStart` begins the session, whose
/// Live Activity replaces this one (shared `LiveActivityManager`).
enum ScheduleCountdown {
    @MainActor
    static func run(schedules: ScheduleStore,
                    session: FocusSessionController,
                    profiles: ProfileStore) {
        // Don't compete with a running session's own Live Activity.
        guard session.phase == .idle,
              let (schedule, startsAt) = schedules.startingSoon() else { return }

        let profile = profiles.profiles.first { $0.name == schedule.profileName }
        let name = schedule.title?.isEmpty == false
            ? schedule.title!
            : (schedule.profileName?.isEmpty == false ? schedule.profileName! : "Focus block")

        LiveActivityManager.shared.startUpcoming(
            title: name,
            accentHex: profile?.accentHex ?? "1A3FA8",
            startsAt: Date(),
            endsAt: startsAt
        )
    }
}

/// Per-occurrence guard so a window auto-starts at most once per day. Keyed by
/// schedule id + calendar day in the shared App Group.
enum ScheduleAutoStartLog {
    static func didStart(_ id: UUID, on date: Date = Date()) -> Bool {
        AppGroup.defaults.bool(forKey: key(id, date))
    }

    static func markStarted(_ id: UUID, on date: Date = Date()) {
        AppGroup.defaults.set(true, forKey: key(id, date))
    }

    private static func key(_ id: UUID, _ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "autostart.\(id.uuidString).\(formatter.string(from: date))"
    }
}
