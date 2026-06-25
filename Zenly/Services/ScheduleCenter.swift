//
//  ScheduleCenter.swift
//  Zenly
//
//  Wraps DeviceActivityCenter. Starting monitoring with a DeviceActivitySchedule
//  hands enforcement to the system: ZenlyMonitor.intervalDidStart/End applies and
//  clears the shields for that activity — even if the app is killed.
//
//  Note: DeviceActivitySchedule requires intervals of at least ~15 minutes, so
//  short sessions fall back to in-app blocking + a local notification only.
//

import Foundation
import DeviceActivity
import FamilyControls

extension DeviceActivityName {
    static let focusSession = Self("zenly.focus.session")
}

@MainActor
final class ScheduleCenter {
    static let shared = ScheduleCenter()

    private let center = DeviceActivityCenter()

    /// One-off timed session (e.g. a Pomodoro focus block). Kill-safe only when
    /// the duration meets the 15-minute schedule minimum.
    func startOneOff(activity: DeviceActivityName,
                     block: FamilyActivitySelection,
                     allow: FamilyActivitySelection,
                     blockAll: Bool,
                     allowedWebDomains: [String] = [],
                     durationMinutes: Int) {
        guard durationMinutes >= 15 else { return }
        ActivityShieldStore.set(block: block, allow: allow, blockAll: blockAll,
                                allowedWebDomains: allowedWebDomains, for: activity.rawValue)

        let calendar = Calendar.current
        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )
        do {
            try center.startMonitoring(activity, during: schedule)
        } catch {
            print("[Zenly] startMonitoring (one-off) failed for \(activity.rawValue): \(error)")
        }
    }

    /// Recurring schedule: monitors daily within the time-of-day window; the
    /// extension applies shields only on the weekdays in `weekdaysMask`.
    func startRecurring(activity: DeviceActivityName,
                        block: FamilyActivitySelection,
                        allow: FamilyActivitySelection,
                        blockAll: Bool,
                        start: DateComponents,
                        end: DateComponents,
                        weekdaysMask: Int) {
        ActivityShieldStore.set(block: block, allow: allow, blockAll: blockAll,
                                weekdaysMask: weekdaysMask, for: activity.rawValue)
        let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true)
        do {
            try center.startMonitoring(activity, during: schedule)
        } catch {
            print("[Zenly] startMonitoring (recurring) failed for \(activity.rawValue): \(error). " +
                  "Screen Time access is likely not granted.")
        }
    }

    func stop(_ activity: DeviceActivityName) {
        center.stopMonitoring([activity])
        ActivityShieldStore.remove(for: activity.rawValue)
    }

    func stopAll() {
        center.stopMonitoring()
    }
}
