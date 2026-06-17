//
//  NotificationService.swift
//  Zenly
//
//  Local notifications for session end, break end, and daily break reminders.
//  Focus/break ends use UNTimeIntervalNotificationTrigger; the recurring break
//  reminder uses UNCalendarNotificationTrigger.
//

import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let focusEndID = "zenly.focus.end"
    private let breakEndID = "zenly.break.end"
    private let breakReminderID = "zenly.break.reminder"

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func scheduleFocusEnd(after seconds: TimeInterval, profileName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Focus complete"
        content.body = "Your \(profileName) session is done — nice work."
        content.sound = .default
        add(focusEndID, content, after: seconds)
    }

    func scheduleBreakEnd(after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Break over"
        content.body = "Ready for another focus session?"
        content.sound = .default
        add(breakEndID, content, after: seconds)
    }

    /// Recurring daily break reminder at a fixed time of day.
    func scheduleDailyBreakReminder(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Time for a break"
        content.body = "Step away for a few minutes to recharge."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: breakReminderID, content: content, trigger: trigger))
    }

    func cancelDailyBreakReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [breakReminderID])
    }

    func cancelSession() {
        center.removePendingNotificationRequests(withIdentifiers: [focusEndID, breakEndID])
    }

    private func add(_ id: String, _ content: UNNotificationContent, after seconds: TimeInterval) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
