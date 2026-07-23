//
//  NotificationService.swift
//  Zenly
//
//  Local notifications for session end, break end, and daily break reminders.
//  Focus/break ends use UNTimeIntervalNotificationTrigger; the recurring break
//  reminder uses UNCalendarNotificationTrigger.
//

import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let focusEndID = "zenly.focus.end"
    private let breakEndID = "zenly.break.end"
    private let breakReminderID = "zenly.break.reminder"
    private let challengeReminderID = "zenly.challenge.reminder"
    private let challengeDoneID = "zenly.challenge.done"

    /// Install as the notification-center delegate. Without a delegate, iOS
    /// silently drops any notification that arrives while the app is in the
    /// foreground — schedule start reminders/alerts included. Call once at
    /// app startup (ZenlyApp.init).
    func activate() {
        center.delegate = self
    }

    /// Present notifications while the app is foregrounded. Session-end and
    /// break-end stay silent in-app (the summary screen already covers them);
    /// everything else — schedule reminders/alerts, daily nudges, challenge
    /// notifications — banners like it does from the background.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let id = notification.request.identifier
        if id == focusEndID || id == breakEndID { return [] }
        return [.banner, .sound, .list]
    }

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

    /// Fires when a break ends. `focusedToday` picks the message: if the user has
    /// focused today, nudge them back into a session; if somehow not, nudge them
    /// to start one.
    func scheduleBreakEnd(after seconds: TimeInterval, focusedToday: Bool) {
        let content = UNMutableNotificationContent()
        if focusedToday {
            content.title = "Break over"
            content.body = "Ready for another focus session?"
        } else {
            content.title = "Ready to focus?"
            content.body = "You haven't focused yet today — start a session."
        }
        content.sound = .default
        add(breakEndID, content, after: seconds)
    }

    /// The daily nudge at a fixed time. Content depends on whether the user has
    /// focused today: focused → suggest a break; not yet → suggest starting a
    /// session. Scheduled NON-repeating for the next occurrence (a repeating
    /// trigger would freeze one message forever) and re-armed on every app
    /// foreground + after each completed session so it reflects the day's state.
    func scheduleDailyReminder(hour: Int, minute: Int, focusedToday: Bool) {
        let content = UNMutableNotificationContent()
        if focusedToday {
            content.title = "Time for a break"
            content.body = "You've focused today — step away for a few minutes to recharge."
        } else {
            content.title = "Ready to focus?"
            content.body = "You haven't focused yet today. Start a session."
        }
        content.sound = .default

        let next = Self.nextOccurrence(hour: hour, minute: minute)
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: next)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: breakReminderID, content: content, trigger: trigger))
    }

    /// Re-arm the daily reminder after a session completes (now definitely
    /// "focused today"), so its message flips to the break nudge even if the app
    /// isn't reopened before the reminder time. Reads the settings from the App
    /// Group; no-op when the reminder is disabled.
    func refreshDailyReminderAfterSession() {
        let d = AppGroup.defaults
        guard d.bool(forKey: "breakReminderEnabled") else { return }
        let hour = d.object(forKey: "breakReminderHour") as? Int ?? 15
        let minute = d.object(forKey: "breakReminderMinute") as? Int ?? 0
        scheduleDailyReminder(hour: hour, minute: minute, focusedToday: true)
    }

    /// The next Date matching hour:minute — later today if still ahead, else tomorrow.
    private static func nextOccurrence(hour: Int, minute: Int) -> Date {
        let cal = Calendar.current
        let now = Date()
        if let today = cal.date(bySettingHour: hour, minute: minute, second: 0, of: now), today > now {
            return today
        }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow) ?? tomorrow
    }

    func cancelDailyBreakReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [breakReminderID])
    }

    /// Morning nudge that a fresh daily challenge is waiting.
    func scheduleDailyChallengeReminder(hour: Int = 9, minute: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = "New daily challenge"
        content.body = "Open Zen-ly to see today's focus challenge."
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

    /// Minutes-before-start the heads-up reminders fire: a 15-min warning and a
    /// 1-min final warning. Each lead gets its own notification ID per weekday so
    /// they coexist instead of overwriting one another.
    private static let reminderLeads = [15, 1]

    /// Repeating heads-up reminders before a recurring schedule starts, one per
    /// selected weekday per lead time. Re-scheduling first clears this schedule's
    /// old reminders, so it's safe to call on every create/enable/edit.
    func scheduleStartReminders(scheduleID: UUID, title: String,
                                startHour: Int, startMinute: Int,
                                weekdays: Set<Int>) {
        cancelStartReminders(scheduleID: scheduleID)
        guard !weekdays.isEmpty else { return }

        for lead in Self.reminderLeads {
            // Reminder time = start − lead; if it crosses midnight, fire the day before.
            var total = startHour * 60 + startMinute - lead
            var dayShift = 0
            if total < 0 { total += 24 * 60; dayShift = -1 }
            let rHour = total / 60, rMinute = total % 60

            for weekday in weekdays {
                var w = weekday + dayShift
                if w < 1 { w += 7 }
                if w > 7 { w -= 7 }

                let content = UNMutableNotificationContent()
                content.title = "Focus starting soon"
                content.body = "\(title) begins in \(lead) minute\(lead == 1 ? "" : "s")."
                content.sound = .default
                content.interruptionLevel = .timeSensitive

                var components = DateComponents()
                components.weekday = w
                components.hour = rHour
                components.minute = rMinute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                center.add(UNNotificationRequest(identifier: reminderID(scheduleID, weekday, lead),
                                                 content: content, trigger: trigger))
            }
        }
    }

    func cancelStartReminders(scheduleID: UUID) {
        var ids = Self.reminderLeads.flatMap { lead in
            (1...7).map { reminderID(scheduleID, $0, lead) }
        }
        // Also clear any pre-existing reminders saved under the legacy (lead-less) id.
        ids.append(contentsOf: (1...7).map { "zenly.schedule.\(scheduleID.uuidString).reminder.\($0)" })
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Fires AT the schedule's start time, one per selected weekday. iOS can't
    /// launch the app unattended, so this is the user's tap into the session:
    /// opening Zenly runs ScheduleAutoStart, which begins the focus session.
    func scheduleStartAlerts(scheduleID: UUID, title: String,
                             startHour: Int, startMinute: Int, weekdays: Set<Int>) {
        cancelStartAlerts(scheduleID: scheduleID)
        guard !weekdays.isEmpty else { return }

        for weekday in weekdays {
            let content = UNMutableNotificationContent()
            content.title = "Focus block starting"
            content.body = "\(title) is starting now — open Zen-ly to begin."
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            var components = DateComponents()
            components.weekday = weekday
            components.hour = startHour
            components.minute = startMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(identifier: startID(scheduleID, weekday),
                                             content: content, trigger: trigger))
        }
    }

    func cancelStartAlerts(scheduleID: UUID) {
        let ids = (1...7).map { startID(scheduleID, $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func reminderID(_ scheduleID: UUID, _ weekday: Int, _ lead: Int) -> String {
        "zenly.schedule.\(scheduleID.uuidString).reminder.\(lead).\(weekday)"
    }

    private func startID(_ scheduleID: UUID, _ weekday: Int) -> String {
        "zenly.schedule.\(scheduleID.uuidString).start.\(weekday)"
    }

    private func add(_ id: String, _ content: UNNotificationContent, after seconds: TimeInterval) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
