//
//  ShortSessionShieldTests.swift
//  ZenlyTests
//
//  Guards the fix for the second half of Apple's rejection of 1.0 (35): "The app
//  failed to block other apps after turning on Focus."
//
//  `ShieldReconciler` derives the entire shield state from `ActivityShieldStore`
//  and clears everything when it finds no active entry. `ScheduleCenter` used to
//  skip writing that entry for sessions under fifteen minutes — the DeviceActivity
//  floor — so a five-minute session registered nothing, and the next reconcile
//  (the block screen's five-minute door is the easy one to reach) silently
//  unblocked the phone while the countdown carried on.
//
//  These tests are on the store rather than on the reconciler because
//  `ManagedSettingsStore` does nothing outside a Screen Time-authorized device.
//  What is checkable — and what actually broke — is whether a live session
//  reports itself as enforcing.
//

import Testing
import FamilyControls
import Foundation
@testable import Zenly

@MainActor
struct ShortSessionShieldTests {

    /// Swift Testing builds a fresh suite value per test and runs them in
    /// parallel, and `ActivityShieldStore` is one shared App Group defaults
    /// suite — so a shared key would have the tests overwriting each other's
    /// windows. One key per test instance keeps them independent.
    private let activity = "test.zenly.focus.session.\(UUID().uuidString)"

    private func clear() { ActivityShieldStore.remove(for: activity) }

    /// Register a one-off exactly the way `ScheduleCenter.startOneOff` does.
    private func register(start: Date, minutes: Int) {
        let calendar = Calendar.current
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        ActivityShieldStore.set(
            block: FamilyActivitySelection(),
            allow: FamilyActivitySelection(),
            blockAll: true,
            startMinutes: calendar.component(.hour, from: start) * 60
                + calendar.component(.minute, from: start),
            endMinutes: calendar.component(.hour, from: end) * 60
                + calendar.component(.minute, from: end),
            absoluteWindow: (start, end),
            for: activity)
    }

    // MARK: - The bug

    /// A five-minute session — the shortest Home offers — must report itself as
    /// enforcing. When it did not, `ShieldReconciler` cleared every shield.
    @Test func aFiveMinuteSessionIsActiveWhileItRuns() {
        clear(); defer { clear() }
        let start = Date()
        register(start: start, minutes: 5)

        #expect(ActivityShieldStore.isActive(activity, now: start))
        #expect(ActivityShieldStore.isActive(activity, now: start.addingTimeInterval(60)))
        #expect(ActivityShieldStore.isActive(activity, now: start.addingTimeInterval(4 * 60 + 59)))
        #expect(ActivityShieldStore.activeActivitiesNow(start.addingTimeInterval(60))
            .contains(activity))
    }

    @Test func aSessionStopsBeingActiveWhenItsTimeIsUp() {
        clear(); defer { clear() }
        let start = Date()
        register(start: start, minutes: 5)

        #expect(!ActivityShieldStore.isActive(activity, now: start.addingTimeInterval(5 * 60)))
        #expect(!ActivityShieldStore.isActive(activity, now: start.addingTimeInterval(6 * 60)))
    }

    /// A session is not yet enforcing before it begins.
    ///
    /// The second expectation is at the exact instant the window opens, which
    /// only holds because the window is stored as `timeIntervalSinceReferenceDate`
    /// — a `Date` round-tripped through `timeIntervalSince1970` comes back off by
    /// ~100ns and this fails.
    @Test func aSessionIsNotActiveBeforeItStarts() {
        clear(); defer { clear() }
        let start = Date().addingTimeInterval(600)
        register(start: start, minutes: 25)

        #expect(!ActivityShieldStore.isActive(activity, now: start.addingTimeInterval(-1)))
        #expect(ActivityShieldStore.isActive(activity, now: start))
    }

    // MARK: - Why the window is absolute rather than time-of-day

    /// Judged by minutes-since-midnight, an entry left behind by a killed app
    /// comes back to life at the same clock time the next day and re-shields a
    /// session that ended yesterday. The absolute window is what prevents that.
    @Test func anAbandonedSessionDoesNotComeBackTomorrow() {
        clear(); defer { clear() }
        let start = Date()
        register(start: start, minutes: 25)

        let tomorrow = start.addingTimeInterval(24 * 60 * 60 + 60)
        #expect(!ActivityShieldStore.isActive(activity, now: tomorrow))
    }

    /// The edges are exact, not rounded to the minute. A session started at
    /// 09:49:59 used to stop counting as active at 09:54:00 — nearly a minute
    /// early — because both ends were truncated to minutes-since-midnight.
    @Test func theWindowEdgesAreExactRatherThanRoundedToTheMinute() {
        clear(); defer { clear() }
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 3
        components.hour = 9; components.minute = 49; components.second = 59
        let start = Calendar.current.date(from: components)!
        register(start: start, minutes: 5)

        // 09:54:30 — inside the real window, outside the truncated one.
        #expect(ActivityShieldStore.isActive(activity, now: start.addingTimeInterval(4 * 60 + 31)))
    }

    // MARK: - Recurring schedules keep the weekday rules

    /// A recurring schedule passes no absolute window, so it must still be judged
    /// by its weekday mask and daily window — and must repeat tomorrow.
    @Test func aRecurringScheduleStillRepeatsDaily() {
        let recurring = "test.zenly.recurring.\(UUID().uuidString)"
        ActivityShieldStore.remove(for: recurring)
        defer { ActivityShieldStore.remove(for: recurring) }

        ActivityShieldStore.set(block: FamilyActivitySelection(),
                                allow: FamilyActivitySelection(),
                                blockAll: true,
                                weekdaysMask: 0,          // every day
                                startMinutes: 9 * 60,
                                endMinutes: 17 * 60,
                                for: recurring)

        func at(_ hour: Int, _ minute: Int, dayOffset: Int = 0) -> Date {
            var c = DateComponents()
            c.year = 2026; c.month = 8; c.day = 3 + dayOffset
            c.hour = hour; c.minute = minute
            return Calendar.current.date(from: c)!
        }

        #expect(ActivityShieldStore.isActive(recurring, now: at(10, 0)))
        #expect(!ActivityShieldStore.isActive(recurring, now: at(18, 0)))
        // Unlike a one-off, this one is supposed to come back tomorrow.
        #expect(ActivityShieldStore.isActive(recurring, now: at(10, 0, dayOffset: 1)))
    }
}
