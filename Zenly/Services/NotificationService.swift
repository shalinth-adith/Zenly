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

    // MARK: - Schedule start reminders

    /// Repeating reminder `leadMinutes` before a recurring schedule starts, one
    /// per selected weekday. Re-scheduling first clears this schedule's old
    /// reminders, so it's safe to call on every create/enable/edit.
    func scheduleStartReminders(scheduleID: UUID, title: String,
                                startHour: Int, startMinute: Int,
                                weekdays: Set<Int>, leadMinutes: Int = 15) {
        cancelStartReminders(scheduleID: scheduleID)
        guard !weekdays.isEmpty else { return }

        // Reminder time = start − lead; if it crosses midnight, fire the day before.
        var total = startHour * 60 + startMinute - leadMinutes
        var dayShift = 0
        if total < 0 { total += 24 * 60; dayShift = -1 }
        let rHour = total / 60, rMinute = total % 60

        for weekday in weekdays {
            var w = weekday + dayShift
            if w < 1 { w += 7 }
            if w > 7 { w -= 7 }

            let content = UNMutableNotificationContent()
            content.title = "Focus starting soon"
            content.body = "\(title) begins in \(leadMinutes) minutes."
            content.sound = .default

            var components = DateComponents()
            components.weekday = w
            components.hour = rHour
            components.minute = rMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(identifier: reminderID(scheduleID, weekday),
                                             content: content, trigger: trigger))
        }
    }

    func cancelStartReminders(scheduleID: UUID) {
        let ids = (1...7).map { reminderID(scheduleID, $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func reminderID(_ scheduleID: UUID, _ weekday: Int) -> String {
        "zenly.schedule.\(scheduleID.uuidString).reminder.\(weekday)"
    }

    private func add(_ id: String, _ content: UNNotificationContent, after seconds: TimeInterval) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
