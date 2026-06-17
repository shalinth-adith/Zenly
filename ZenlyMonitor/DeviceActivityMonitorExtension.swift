//
//  DeviceActivityMonitorExtension.swift
//  ZenlyMonitor
//
//  DeviceActivityMonitor principal class. Phase 1 stub: the schedule-driven
//  apply/remove-shield logic is implemented in Phase 2 (recurring schedules,
//  Pomodoro windows). Wired to iOS via NSExtensionPrincipalClass in Info.plist.
//

import DeviceActivity

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Phase 2: apply shields for the schedule that just began.
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Phase 2: clear shields when the schedule window closes.
    }
}
