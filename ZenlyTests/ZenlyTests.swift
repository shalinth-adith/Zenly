//
//  ZenlyTests.swift
//  ZenlyTests
//
//  Unit tests for Zenly's pure logic + Core Data-backed services, using an
//  in-memory store (no device / ScreenTime required).
//

import Testing
import CoreData
import FamilyControls
@testable import Zenly

@MainActor
struct ZenlyTests {

    // MARK: - Helpers

    private func makeContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).container.viewContext
    }

    @discardableResult
    private func addSession(_ context: NSManagedObjectContext,
                            dayOffset: Int,
                            minutes: Int = 25,
                            kind: String = "focus",
                            completed: Bool = true) -> FocusSession {
        let session = FocusSession(context: context)
        session.id = UUID()
        session.kind = kind
        session.wasCompleted = completed
        session.completedMinutes = Int16(minutes)
        session.startedAt = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())
        try? context.save()
        return session
    }

    // MARK: - Weekday mask (ScheduleStore)

    @Test func weekdayMaskRoundTrips() {
        let days: Set<Int> = [2, 4, 6]
        let mask = ScheduleStore.mask(from: days)
        #expect(ScheduleStore.weekdays(from: mask) == days)
    }

    @Test func weekdayMaskEmpty() {
        #expect(ScheduleStore.weekdays(from: 0).isEmpty)
    }

    @Test func weekdaySummaryLabels() {
        #expect(ScheduleStore.summary(for: [2, 3, 4, 5, 6]) == "Weekdays")
        #expect(ScheduleStore.summary(for: [1, 7]) == "Weekends")
        #expect(ScheduleStore.summary(for: Set(1...7)) == "Every day")
    }

    // MARK: - Streak (SessionHistory)

    @Test func streakCountsConsecutiveDays() {
        let context = makeContext()
        let history = SessionHistory(context: context)
        addSession(context, dayOffset: 0)
        addSession(context, dayOffset: 1)
        addSession(context, dayOffset: 2)
        #expect(history.currentStreak() == 3)
    }

    @Test func streakBreaksOnGap() {
        let context = makeContext()
        let history = SessionHistory(context: context)
        addSession(context, dayOffset: 0)   // today
        addSession(context, dayOffset: 3)   // gap on days 1 & 2
        #expect(history.currentStreak() == 1)
    }

    @Test func streakIsZeroWithNoCompletedSessions() {
        let context = makeContext()
        let history = SessionHistory(context: context)
        addSession(context, dayOffset: 0, completed: false)
        #expect(history.currentStreak() == 0)
    }

    @Test func todayFocusMinutesSumsOnlyToday() {
        let context = makeContext()
        let history = SessionHistory(context: context)
        addSession(context, dayOffset: 0, minutes: 25)
        addSession(context, dayOffset: 0, minutes: 15)
        addSession(context, dayOffset: 1, minutes: 30) // yesterday, excluded
        #expect(history.todayFocusMinutes() == 40)
    }

    @Test func breakSessionsDoNotCountAsFocus() {
        let context = makeContext()
        let history = SessionHistory(context: context)
        addSession(context, dayOffset: 0, minutes: 5, kind: "break")
        #expect(history.todayFocusMinutes() == 0)
        #expect(history.currentStreak() == 0)
    }

    // MARK: - Analytics

    @Test func productivityScoreZeroWithNoData() {
        let context = makeContext()
        let analytics = AnalyticsService(history: SessionHistory(context: context))
        #expect(analytics.productivityScore() == 0)
    }

    @Test func productivityScoreInRange() {
        let context = makeContext()
        for offset in 0..<5 { addSession(context, dayOffset: offset, minutes: 60) }
        let analytics = AnalyticsService(history: SessionHistory(context: context))
        let score = analytics.productivityScore()
        #expect(score > 0)
        #expect(score <= 100)
    }

    @Test func weeklyStatsAlwaysSevenDays() {
        let context = makeContext()
        let analytics = AnalyticsService(history: SessionHistory(context: context))
        #expect(analytics.weeklyStats().count == 7)
    }

    // MARK: - Insights wiring (weekly focus / sessions / vs-last-week)

    @Test func weeklyFocusSumsCompletedCurrentWeekOnly() {
        let context = makeContext()
        addSession(context, dayOffset: 0, minutes: 25)
        addSession(context, dayOffset: 2, minutes: 35)
        addSession(context, dayOffset: 3, minutes: 30, completed: false) // ended early, excluded
        addSession(context, dayOffset: 9, minutes: 60)                   // last week, excluded
        let analytics = AnalyticsService(history: SessionHistory(context: context))
        #expect(analytics.weeklyStats().reduce(0) { $0 + $1.focusMinutes } == 60)
    }

    @Test func weekSessionCountCountsCurrentWindowOnly() {
        let context = makeContext()
        addSession(context, dayOffset: 0)
        addSession(context, dayOffset: 6)                    // window edge, included
        addSession(context, dayOffset: 7)                    // previous week, excluded
        addSession(context, dayOffset: 1, completed: false)  // ended early, excluded
        let analytics = AnalyticsService(history: SessionHistory(context: context))
        #expect(analytics.weekSessionCount() == 2)
    }

    @Test func previousWeekMinutesCoversDays7To13() {
        let context = makeContext()
        addSession(context, dayOffset: 7, minutes: 40)   // included
        addSession(context, dayOffset: 13, minutes: 20)  // included (window edge)
        addSession(context, dayOffset: 14, minutes: 60)  // older, excluded
        addSession(context, dayOffset: 3, minutes: 25)   // current week, excluded
        let analytics = AnalyticsService(history: SessionHistory(context: context))
        #expect(analytics.previousWeekMinutes() == 60)
    }

    @Test func todaySessionsCountsOnlyTodayCompleted() {
        let context = makeContext()
        addSession(context, dayOffset: 0)
        addSession(context, dayOffset: 0)
        addSession(context, dayOffset: 0, completed: false) // excluded
        addSession(context, dayOffset: 1)                   // yesterday, excluded
        let analytics = AnalyticsService(history: SessionHistory(context: context))
        #expect(analytics.todaySessions() == 2)
    }

    // MARK: - Achievements

    @Test func firstFocusBadgeAwardedAfterSession() {
        let context = makeContext()
        let history = SessionHistory(context: context)
        let service = AchievementService(context: context, history: history)

        #expect(service.isEarned("first_focus") == false)
        addSession(context, dayOffset: 0)
        let newly = service.evaluate()
        #expect(newly.contains { $0.id == "first_focus" })
        #expect(service.isEarned("first_focus"))
    }

    @Test func evaluateIsIdempotent() {
        let context = makeContext()
        let history = SessionHistory(context: context)
        let service = AchievementService(context: context, history: history)
        addSession(context, dayOffset: 0)
        _ = service.evaluate()
        let secondPass = service.evaluate()
        #expect(secondPass.isEmpty) // nothing new the second time
    }

    // MARK: - Daily challenge

    @Test func challengeTitlesReadable() {
        #expect(DailyChallenge(dateKey: "d", kind: .minutes, target: 60).title == "Focus for 60 minutes today")
        #expect(DailyChallenge(dateKey: "d", kind: .sessions, target: 3).title == "Complete 3 focus sessions")
        #expect(DailyChallenge(dateKey: "d", kind: .longSession, target: 25).title == "Complete a 25-minute session")
    }

    // MARK: - Selection codec

    @Test func selectionCodecRoundTripsEmpty() {
        let selection = FamilyActivitySelection()
        let data = SelectionCodec.encode(selection)
        #expect(data != nil)
        let decoded = SelectionCodec.decode(data)
        #expect(decoded.applicationTokens.isEmpty)
        #expect(decoded.categoryTokens.isEmpty)
    }

    @Test func selectionCodecDecodesNilToEmpty() {
        #expect(SelectionCodec.decode(nil).applicationTokens.isEmpty)
    }

    // MARK: - Badge catalog integrity

    @Test func badgeIDsAreUnique() {
        let ids = BadgeCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
