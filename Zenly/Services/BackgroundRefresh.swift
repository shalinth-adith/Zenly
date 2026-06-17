//
//  BackgroundRefresh.swift
//  Zenly
//
//  Registers a BGAppRefreshTask so the app can periodically re-evaluate calendar
//  free blocks in the background. Best-effort (iOS schedules at its discretion);
//  the identifier is declared in BGTaskSchedulerPermittedIdentifiers.
//

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
        // Lightweight placeholder for calendar re-evaluation; kept fast so the
        // task always completes within its window.
        task.setTaskCompleted(success: true)
    }
}
