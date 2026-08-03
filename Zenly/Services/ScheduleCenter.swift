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
    /// the duration meets the 15-minute schedule minimum — but *registered*
    /// either way. See below.
    func startOneOff(activity: DeviceActivityName,
                     block: FamilyActivitySelection,
                     allow: FamilyActivitySelection,
                     blockAll: Bool,
                     allowedWebDomains: [String] = [],
                     durationMinutes: Int) {
        let calendar = Calendar.current
        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let startMin = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let endMin = calendar.component(.hour, from: end) * 60 + calendar.component(.minute, from: end)

        // ALWAYS record the session, whatever its length.
        //
        // This used to sit behind the 15-minute guard below, and that was the
        // bug: `ShieldReconciler` derives the whole shield state from this store,
        // so a session too short to monitor registered nothing and read back as
        // "nothing is enforcing". The next reconcile — the five-minute door on
        // the block screen is the easy one to hit — then called
        // `clearAllSettings()` and silently unblocked the phone for the rest of
        // the session, while the countdown carried on as if it were working.
        //
        // Home offers five minutes as its shortest session, so this was reachable
        // in two taps.
        ActivityShieldStore.set(block: block, allow: allow, blockAll: blockAll,
                                allowedWebDomains: allowedWebDomains,
                                startMinutes: startMin, endMinutes: endMin,
                                absoluteWindow: (now, end),
                                for: activity.rawValue)

        // The 15-minute floor is Apple's, and it applies only to handing the
        // session to the system. Below it we keep in-app blocking plus the local
        // notification: the shields are already up, and the app clears them when
        // the timer ends. The cost is that a sub-15-minute session killed by iOS
        // isn't torn down until the next launch, where `restoreIfNeeded` finishes
        // it — the same bound that has always applied.
        guard durationMinutes >= 15 else { return }

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
        let startMin = (start.hour ?? 0) * 60 + (start.minute ?? 0)
        let endMin = (end.hour ?? 0) * 60 + (end.minute ?? 0)
        ActivityShieldStore.set(block: block, allow: allow, blockAll: blockAll,
                                weekdaysMask: weekdaysMask,
                                startMinutes: startMin, endMinutes: endMin,
                                for: activity.rawValue)
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
