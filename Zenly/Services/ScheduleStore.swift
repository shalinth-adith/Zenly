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
}

@Observable
@MainActor
final class ScheduleStore {
    private(set) var schedules: [FocusSchedule] = []

    private let context: NSManagedObjectContext
    private let center = ScheduleCenter.shared

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
            allow: SelectionCodec.decode(schedule.allowSelectionData)
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

        // Active right now? (same-day windows)
        let today = cal.component(.weekday, from: now)
        if days.contains(today),
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

        // A heads-up notification 15 min before the block (independent of Screen
        // Time access — only needs notification permission).
        NotificationService.shared.scheduleStartReminders(
            scheduleID: schedule.id ?? UUID(),
            title: schedule.title?.isEmpty == false ? schedule.title! : "Focus block",
            startHour: Int(schedule.startHour),
            startMinute: Int(schedule.startMinute),
            weekdays: Self.weekdays(from: schedule.weekdaysMask)
        )
    }

    private func stopMonitoring(_ schedule: FocusSchedule) {
        center.stop(activityName(schedule))
        if let id = schedule.id {
            NotificationService.shared.cancelStartReminders(scheduleID: id)
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
