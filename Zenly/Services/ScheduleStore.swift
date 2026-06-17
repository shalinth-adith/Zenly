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
        save()
        if enabled { startMonitoring(schedule) } else { stopMonitoring(schedule) }
    }

    func weekdaySummary(_ schedule: FocusSchedule) -> String {
        Self.summary(for: Self.weekdays(from: schedule.weekdaysMask))
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
    }

    private func stopMonitoring(_ schedule: FocusSchedule) {
        center.stop(activityName(schedule))
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
