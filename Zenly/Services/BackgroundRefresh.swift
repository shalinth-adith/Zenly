//
//  BackgroundRefresh.swift
//  Zenly
//
//  Registers a BGAppRefreshTask, the app's only chance to do anything while it
//  is suspended. It clears the Live Activity left behind by a session that ran
//  out with the phone locked. Best-effort (iOS schedules at its discretion);
//  the identifier is declared in BGTaskSchedulerPermittedIdentifiers.
//

import ActivityKit
import BackgroundTasks
import Foundation

enum BackgroundRefresh {
    static let identifier = "me.adithyan.shalinth.Zenly.refresh"

    /// Must be called before the app finishes launching (App.init).
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refreshTask)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        schedule() // reschedule the next refresh

        // A session that runs out while the phone is locked ends with this app
        // suspended, so nothing is left running to take its card off the Lock
        // Screen — the countdown just sits there at zero until the app is next
        // opened. Only the owning process can end a Live Activity, so this is
        // the one chance to do it without the user coming back first.
        //
        // Best-effort by nature: iOS grants these at its own discretion, so
        // this shortens the window rather than closing it. Opening the app
        // still clears the card immediately.
        guard let end = ActiveSessionInfo.scheduledEnd, end <= Date() else {
            task.setTaskCompleted(success: true)
            return
        }

        let sweep = Task {
            for activity in Activity<FocusActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            ActiveSessionInfo.clear()
            task.setTaskCompleted(success: true)
        }
        // iOS gives these tasks seconds, not minutes, and kills the app if the
        // deadline passes without a completion call.
        task.expirationHandler = { sweep.cancel() }
    }
}
