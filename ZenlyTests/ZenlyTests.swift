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

    // MARK: - Window length

    @Test func durationOfANormalWindow() {
        #expect(ScheduleStore.duration(startMinutes: 9 * 60, endMinutes: 17 * 60) == 480)
    }

    @Test func aWindowEndingBeforeItStartsRunsOvernight() {
        // 22:00 → 06:00 is eight hours, not minus sixteen.
        #expect(ScheduleStore.duration(startMinutes: 22 * 60, endMinutes: 6 * 60) == 480)
    }

    @Test func equalStartAndEndIsAFullDay() {
        // Callers must reject this before it gets here — the editor does, which
        // is what makes "That's no time at all" a blocking error.
        #expect(ScheduleStore.duration(startMinutes: 14 * 60, endMinutes: 14 * 60) == 1440)
    }

    // MARK: - Allowed-website parsing (profile editor, spec screen 11)

    @Test func realHostsAreAccepted() {
        for host in ["claude.ai", "docs.google.com", "a-b.co.uk", "x1.example.org"] {
            #expect(ProfileEditView.isValidDomain(host), "\(host) should be valid")
        }
    }

    @Test func thingsThatAreNotHostsAreRejected() {
        for junk in ["chatgpt,com", "chatgpt", "chat gpt.com", "-bad.com", "bad-.com",
                     ".com", "example.", "example.c", "example.12"] {
            #expect(!ProfileEditView.isValidDomain(junk), "\(junk) should be invalid")
        }
    }

    @Test func theCommaTypoIsRepaired() {
        #expect(ProfileEditView.repair("chatgpt,com") == "chatgpt.com")
    }

    @Test func schemesAndPathsAreStripped() {
        #expect(ProfileEditView.repair("https://docs.google.com/document/d/1") == "docs.google.com")
        #expect(ProfileEditView.repair("HTTP://Example.COM/path") == "example.com")
        // A stray space is itself worth offering to fix.
        #expect(ProfileEditView.repair("claude.ai ") == "claude.ai")
        // Nothing to change means nothing to offer.
        #expect(ProfileEditView.repair("claude.ai") == nil)
    }

    @Test func noRepairIsOfferedWhenTheGuessWouldBeWrong() {
        // "chatgpt" has nothing to fix into a host — better to say nothing than
        // to invent a top-level domain on the user's behalf.
        #expect(ProfileEditView.repair("chatgpt") == nil)
        #expect(ProfileEditView.repair("") == nil)
    }

    @Test func siteLabelsReadTheWayPeopleSayThem() {
        #expect(ProfileEditView.siteLabel("claude.ai") == "Claude")
        #expect(ProfileEditView.siteLabel("docs.google.com") == "Docs")
        #expect(ProfileEditView.siteLabel("www.notion.so") == "Notion")
    }

    @Test func readableListJoinsNaturally() {
        #expect(ProfileEditView.readableList([]) == "")
        #expect(ProfileEditView.readableList(["Claude"]) == "Claude")
        #expect(ProfileEditView.readableList(["Claude", "Docs"]) == "Claude and Docs")
        #expect(ProfileEditView.readableList(["Claude", "Docs", "Figma"])
                == "Claude, Docs and Figma")
    }
}

/// Schedule overlap detection — the data behind the Quiet spec's screen 18.
///
/// The interesting cases are the ones a per-day comparison gets wrong: a window
/// that runs past midnight into the next morning's window, and one that runs
/// past Saturday midnight into Sunday.
@MainActor
@Suite(.serialized)
struct ScheduleConflictTests {

    private func makeStore() -> ScheduleStore {
        ScheduleStore(context: PersistenceController(inMemory: true).container.viewContext)
    }

    private func draft(start: (Int, Int), end: (Int, Int),
                       days: Set<Int>, profile: String = "Work") -> ScheduleDraft {
        ScheduleDraft(title: "", startHour: start.0, startMinute: start.1,
                      endHour: end.0, endMinute: end.1,
                      weekdays: days, profileName: profile)
    }

    @Test func sameDaySameHoursCollide() {
        let store = makeStore()
        store.create(from: draft(start: (9, 0), end: (17, 0), days: [2]))
        let found = store.conflicts(for: draft(start: (14, 0), end: (16, 0), days: [2]),
                                    excluding: nil)
        #expect(found.count == 1)
        #expect(found.first?.days == [2])
    }

    @Test func differentDaysDoNotCollide() {
        let store = makeStore()
        store.create(from: draft(start: (9, 0), end: (17, 0), days: [2]))
        #expect(store.conflicts(for: draft(start: (9, 0), end: (17, 0), days: [4]),
                                excluding: nil).isEmpty)
    }

    @Test func backToBackWindowsDoNotCollide() {
        // Half-open: a window ending at 17:00 leaves 17:00 free.
        let store = makeStore()
        store.create(from: draft(start: (9, 0), end: (17, 0), days: [2]))
        #expect(store.conflicts(for: draft(start: (17, 0), end: (19, 0), days: [2]),
                                excluding: nil).isEmpty)
    }

    @Test func anOvernightWindowCollidesWithTheNextMorning() {
        // Monday 22:00 → 06:00 runs into Tuesday, where a 05:00 window lives.
        let store = makeStore()
        store.create(from: draft(start: (22, 0), end: (6, 0), days: [2]))
        let found = store.conflicts(for: draft(start: (5, 0), end: (7, 0), days: [3]),
                                    excluding: nil)
        #expect(found.count == 1)
        #expect(found.first?.days == [3])
    }

    @Test func saturdayNightWrapsIntoSundayMorning() {
        let store = makeStore()
        store.create(from: draft(start: (23, 0), end: (2, 0), days: [7]))   // Sat night
        let found = store.conflicts(for: draft(start: (1, 0), end: (3, 0), days: [1]), // Sun
                                    excluding: nil)
        #expect(found.count == 1)
    }

    @Test func onlyTheCollidingDaysAreReported() {
        let store = makeStore()
        store.create(from: draft(start: (14, 0), end: (15, 0), days: [2, 4, 6]))
        let found = store.conflicts(for: draft(start: (14, 30), end: (16, 0), days: [3, 4, 5]),
                                    excluding: nil)
        #expect(found.first?.days == [4])   // only Wednesday is in both
    }

    @Test func aScheduleDoesNotCollideWithItself() {
        let store = makeStore()
        let existing = store.create(from: draft(start: (9, 0), end: (17, 0), days: [2]))
        #expect(store.conflicts(for: draft(start: (9, 0), end: (17, 0), days: [2]),
                                excluding: existing).isEmpty)
    }

    @Test func aDisabledScheduleIsNotInTheWay() {
        let store = makeStore()
        let existing = store.create(from: draft(start: (9, 0), end: (17, 0), days: [2]))
        store.setEnabled(existing, false)
        #expect(store.conflicts(for: draft(start: (9, 0), end: (17, 0), days: [2]),
                                excluding: nil).isEmpty)
    }

    // MARK: - How a schedule is named (comp 07 / 19)

    /// Held for the lifetime of the suite: a managed object whose context has
    /// been deallocated faults back to nil for every attribute, which would
    /// make these tests pass or fail for the wrong reason.
    private let namingContext = PersistenceController(inMemory: true).container.viewContext

    private func schedule(profile: String, title: String) -> FocusSchedule {
        let schedule = FocusSchedule(context: namingContext)
        schedule.id = UUID()
        schedule.profileName = profile.isEmpty ? nil : profile
        schedule.title = title
        return schedule
    }

    @Test func bothHalvesAreWrittenWhenTheyDiffer() {
        #expect(ScheduleStore.displayName(for: schedule(profile: "Work", title: "Deep focus"))
                == "Work · Deep focus")
    }

    @Test func aTitleThatRepeatsItsProfileIsWrittenOnce() {
        #expect(ScheduleStore.displayName(for: schedule(profile: "Work", title: "Work")) == "Work")
        #expect(ScheduleStore.displayName(for: schedule(profile: "Work", title: "work")) == "Work")
    }

    @Test func anUntitledScheduleIsItsProfile() {
        #expect(ScheduleStore.displayName(for: schedule(profile: "Work", title: "")) == "Work")
    }

    @Test func aScheduleWithNeitherFallsBackToSomethingSayable() {
        #expect(ScheduleStore.displayName(for: schedule(profile: "", title: "")) == "Focus block")
        #expect(ScheduleStore.displayName(for: schedule(profile: "", title: "Reading")) == "Reading")
    }

    @Test func anEmptyWindowIsNotReportedAsAClash() {
        // Same start and end is its own error, with its own message.
        let store = makeStore()
        store.create(from: draft(start: (9, 0), end: (17, 0), days: [2]))
        #expect(store.conflicts(for: draft(start: (14, 0), end: (14, 0), days: [2]),
                                excluding: nil).isEmpty)
    }

    @Test func noDaysMeansNothingToCollideWith() {
        let store = makeStore()
        store.create(from: draft(start: (9, 0), end: (17, 0), days: [2]))
        #expect(store.conflicts(for: draft(start: (9, 0), end: (17, 0), days: []),
                                excluding: nil).isEmpty)
    }
}

/// Distraction-attempt accounting — the data behind the "N distractions blocked
/// this week" row on Insights (TC-6.3).
///
/// `DistractionLog` persists to the shared App Group defaults, so these tests
/// touch process-wide state: the suite is `.serialized` and each test clears the
/// keys before and after itself.
@MainActor
@Suite(.serialized)
struct DistractionLogTests {

    private func reset() {
        for key in ["distractionCounts", "distractionEvents", "distractionLastAttempt"] {
            AppGroup.defaults.removeObject(forKey: key)
        }
    }

    @Test func recordsAnAttemptForToday() {
        reset(); defer { reset() }
        #expect(DistractionLog.today() == 0)
        DistractionLog.recordAttempt()
        #expect(DistractionLog.today() == 1)
    }

    @Test func rapidRepeatsAreDeduped() {
        reset(); defer { reset() }
        // iOS can ask for the shield configuration several times per app open;
        // anything inside the 1.5s window must count once.
        let now = Date()
        DistractionLog.recordAttempt(on: now)
        DistractionLog.recordAttempt(on: now.addingTimeInterval(0.3))
        DistractionLog.recordAttempt(on: now.addingTimeInterval(0.9))
        #expect(DistractionLog.today() == 1)
    }

    @Test func attemptsOutsideTheDedupeWindowBothCount() {
        reset(); defer { reset() }
        let now = Date()
        DistractionLog.recordAttempt(on: now)
        DistractionLog.recordAttempt(on: now.addingTimeInterval(5))
        #expect(DistractionLog.today() == 2)
    }

    @Test func perDayCountsAreKeptSeparately() {
        reset(); defer { reset() }
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        DistractionLog.recordAttempt(on: yesterday)
        DistractionLog.recordAttempt(on: today.addingTimeInterval(10))
        #expect(DistractionLog.count(on: yesterday) == 1)
        #expect(DistractionLog.count(on: today) == 1)
    }

    @Test func sessionWindowAttributionIsInclusive() {
        reset(); defer { reset() }
        let start = Date()
        DistractionLog.recordAttempt(on: start.addingTimeInterval(30))
        DistractionLog.recordAttempt(on: start.addingTimeInterval(90))
        DistractionLog.recordAttempt(on: start.addingTimeInterval(600)) // outside
        #expect(DistractionLog.count(from: start, to: start.addingTimeInterval(120)) == 2)
    }

    /// The Insights row sums `weeklyStats().attempts`; this is that fold.
    @Test func weeklyStatsFoldInTodaysAttempts() {
        reset(); defer { reset() }
        let context = PersistenceController(inMemory: true).container.viewContext
        let analytics = AnalyticsService(history: SessionHistory(context: context))

        #expect(analytics.weeklyStats().reduce(0) { $0 + $1.attempts } == 0)

        let now = Date()
        DistractionLog.recordAttempt(on: now)
        DistractionLog.recordAttempt(on: now.addingTimeInterval(5))

        let stats = analytics.weeklyStats()
        #expect(stats.reduce(0) { $0 + $1.attempts } == 2)
        // weeklyStats() is oldest-first, so today is the last entry — which is
        // what AnalyticsView reads for "today".
        #expect(stats.last?.attempts == 2)
    }
}
