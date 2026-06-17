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
    private let challengeReminderID = "zenly.challenge.reminder"
    private let challengeDoneID = "zenly.challenge.done"

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

    /// Morning nudge that a fresh daily challenge is waiting.
    func scheduleDailyChallengeReminder(hour: Int = 9, minute: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = "New daily challenge"
        content.body = "Open Zenly to see today's focus challenge."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: challengeReminderID, content: content, trigger: trigger))
    }

    func notifyChallengeComplete(title: String) {
        let content = UNMutableNotificationContent()
        content.title = "Challenge complete 🎉"
        content.body = title
        content.sound = .default
        add(challengeDoneID, content, after: 1)
    }

    func cancelSession() {
        center.removePendingNotificationRequests(withIdentifiers: [focusEndID, breakEndID])
    }

    private func add(_ id: String, _ content: UNNotificationContent, after seconds: TimeInterval) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
