//
//  QuietSessionScreenTests.swift
//  ZenlyTests
//
//  The logic behind the Quiet spec's screens 03 (App paused), 04b (Ended early)
//  and 05 (Insights) — the parts that are decisions rather than layout, and so
//  can be checked without a simulator.
//
//  Screens 04 and 04b's *appearance* is covered by `QuietSessionScreens` in the
//  UI tests; what is here is the arithmetic those screens display, which is
//  where the comp's numbers actually come from.
//

import Testing
import CoreData
import CoreGraphics
import Foundation
import UIKit
@testable import Zenly

// MARK: - 04b · the ring's clock

struct SessionSummaryClockTests {

    private func summary(completedSeconds: Int,
                         plannedMinutes: Int = 25) -> SessionSummary {
        SessionSummary(profileName: "Work",
                       accentHex: "7C93E8",
                       plannedMinutes: plannedMinutes,
                       completedMinutes: completedSeconds / 60,
                       completedSeconds: completedSeconds,
                       wasCompleted: false,
                       endedEarly: true,
                       streak: 3)
    }

    /// The comp's own label.
    @Test func rendersMinutesAndSeconds() {
        #expect(summary(completedSeconds: 144).clock == "2:24")
    }

    /// Seconds are always two digits — "2:4" is not a time.
    @Test func padsSecondsToTwoDigits() {
        #expect(summary(completedSeconds: 124).clock == "2:04")
        #expect(summary(completedSeconds: 60).clock == "1:00")
    }

    /// A session abandoned almost immediately still gets a real number rather
    /// than the "<1" placeholder the screen used to show.
    @Test func showsSubMinuteSessionsHonestly() {
        #expect(summary(completedSeconds: 41).clock == "0:41")
        #expect(summary(completedSeconds: 0).clock == "0:00")
    }

    @Test func rollsPastAnHour() {
        #expect(summary(completedSeconds: 3725, plannedMinutes: 90).clock == "62:05")
    }
}

// MARK: - 05 · the calendar week

/// Insights draws a calendar week, not a rolling 7-day window: the comp's chart
/// runs M T W T F S S with today highlighted wherever it falls, and every number
/// around it says "this week".
@MainActor
struct CalendarWeekAnalyticsTests {

    private func makeContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).container.viewContext
    }

    @discardableResult
    private func addSession(_ context: NSManagedObjectContext,
                            on day: Date,
                            minutes: Int) -> FocusSession {
        let session = FocusSession(context: context)
        session.id = UUID()
        session.kind = "focus"
        session.wasCompleted = true
        session.completedMinutes = Int16(minutes)
        session.startedAt = day
        try? context.save()
        return session
    }

    private var weekStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    }

    private func analytics(_ context: NSManagedObjectContext) -> AnalyticsService {
        AnalyticsService(history: SessionHistory(context: context))
    }

    @Test func returnsSevenDaysStartingAtTheStartOfTheWeek() {
        let service = analytics(makeContext())
        let stats = service.calendarWeekStats()

        #expect(stats.count == 7)
        #expect(Calendar.current.isDate(stats[0].date, inSameDayAs: weekStart))
        #expect(stats.contains { Calendar.current.isDateInToday($0.date) })
    }

    /// Days are in order, one apart — the chart reads left to right as the week
    /// does.
    @Test func daysRunForwardsWithoutGaps() {
        let stats = analytics(makeContext()).calendarWeekStats()
        for (earlier, later) in zip(stats, stats.dropFirst()) {
            let gap = Calendar.current.dateComponents([.day], from: earlier.date, to: later.date).day
            #expect(gap == 1)
        }
    }

    /// A session earlier today lands on today's bar and nowhere else.
    @Test func creditsMinutesToTheirOwnDay() {
        let context = makeContext()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        addSession(context, on: calendar.date(byAdding: .hour, value: 9, to: today) ?? today,
                   minutes: 40)

        let stats = analytics(context).calendarWeekStats()
        let todayStat = stats.first { calendar.isDateInToday($0.date) }
        #expect(todayStat?.focusMinutes == 40)
        #expect(stats.filter { $0.focusMinutes > 0 }.count == 1)
    }

    /// Last week's sessions are excluded from this week and counted as last
    /// week's — that is the whole "+1.1 h vs last week" line.
    @Test func splitsThisWeekFromLastWeek() {
        let context = makeContext()
        let calendar = Calendar.current
        let lastWeekDay = calendar.date(byAdding: .day, value: -2, to: weekStart) ?? weekStart
        addSession(context, on: calendar.date(byAdding: .hour, value: 10, to: lastWeekDay) ?? lastWeekDay,
                   minutes: 66)

        let service = analytics(context)
        #expect(service.calendarWeekStats().allSatisfy { $0.focusMinutes == 0 })
        #expect(service.previousCalendarWeekMinutes() == 66)
        #expect(service.calendarWeekSessionCount() == 0)
    }

    /// A session on the exact boundary belongs to the week it starts.
    @Test func countsTheFirstMomentOfTheWeekAsThisWeek() {
        let context = makeContext()
        addSession(context, on: weekStart, minutes: 25)

        let service = analytics(context)
        #expect(service.calendarWeekSessionCount() == 1)
        #expect(service.previousCalendarWeekMinutes() == 0)
    }
}

// MARK: - 03 · the block screen's words

/// `ShieldMessage` renders in another process with no access to the app, so its
/// only inputs are the subject iOS hands it and whatever the app last left in
/// the App Group. These check it never says something untrue about either.
@MainActor
@Suite(.serialized)
struct ShieldMessageTests {

    private func reset() { ActiveSessionInfo.clear() }

    @Test func namesWhatIsPaused() {
        reset(); defer { reset() }
        let text = ShieldMessage.subtitle(subject: "Instagram", custom: "")
        #expect(text.contains("Instagram"))
    }

    /// With a session running, the screen says when the app comes back — the
    /// comp's "Back at 7:43".
    @Test func saysWhenTheAppComesBack() {
        reset(); defer { reset() }
        ActiveSessionInfo.set(profileName: "Work", endsAt: Date().addingTimeInterval(16 * 60))

        let text = ShieldMessage.subtitle(subject: "Instagram", custom: "")
        #expect(text.contains("Back at"))
        #expect(text.contains("16 minutes"))
    }

    /// With nothing running, it says nothing about time rather than quoting a
    /// countdown that has already expired.
    @Test func staysSilentAboutTimeWithNoSession() {
        reset(); defer { reset() }
        let text = ShieldMessage.subtitle(subject: "Instagram", custom: "")
        #expect(!text.contains("Back at"))
        #expect(!text.contains("minutes"))
    }

    /// An expired session is the same as no session.
    @Test func ignoresASessionThatHasAlreadyEnded() {
        reset(); defer { reset() }
        ActiveSessionInfo.set(profileName: "Work", endsAt: Date().addingTimeInterval(-60))
        #expect(ActiveSessionInfo.endsAt == nil)
        #expect(!ShieldMessage.subtitle(subject: "Instagram", custom: "").contains("Back at"))
    }

    /// The user's own message is added to the screen, never in place of the
    /// line that names the app or the line that gives the time back.
    @Test func addsACustomMessageWithoutDisplacingAnything() {
        reset(); defer { reset() }
        ActiveSessionInfo.set(profileName: "Work", endsAt: Date().addingTimeInterval(10 * 60))

        let text = ShieldMessage.subtitle(subject: "Reddit", custom: "  You said 8pm.  ")
        #expect(text.contains("Reddit"))
        #expect(text.contains("You said 8pm."))
        #expect(text.contains("Back at"))
    }

    @Test func headlineIsTheCompsSentence() {
        #expect(ShieldMessage.title() == "Your place is kept.")
    }
}

// MARK: - 03 · the ribbon

/// The ribbon is a full-screen backdrop, not an icon: iOS aspect-fits the icon
/// slot into roughly 100 × 100 points, which shrank the comp's 302pt ribbon to
/// 94pt on device with its name reduced to texture. `backgroundColor` accepts a
/// pattern image and has no such box.
struct ShieldRibbonTests {

    private let screen = CGSize(width: 393, height: 852)

    /// The backdrop is the size of the screen it is painting, so the pattern
    /// never repeats inside the shield.
    @Test func fillsTheScreenItIsGiven() throws {
        let image = try #require(
            ShieldRibbon.backdrop(subject: "Instagram", tone: .systemBlue, screen: screen))
        #expect(image.size == screen)
    }

    /// Every device size it is asked for, so a wider or taller phone still gets
    /// a backdrop rather than a fallback.
    @Test(arguments: [CGSize(width: 320, height: 568),   // SE
                      CGSize(width: 393, height: 852),   // 15 / 16 / 17
                      CGSize(width: 440, height: 956)])  // Pro Max
    func drawsAtAnyScreenSize(_ size: CGSize) throws {
        let image = try #require(
            ShieldRibbon.backdrop(subject: "Instagram", tone: .systemBlue, screen: size))
        #expect(image.size == size)
    }

    /// A degenerate size returns nil rather than a zero-pixel image, so the
    /// shield falls back to its flat background instead of coming up blank.
    @Test func refusesAnEmptyScreen() {
        #expect(ShieldRibbon.backdrop(subject: "Instagram",
                                      tone: .systemBlue,
                                      screen: .zero) == nil)
    }

    /// A name too long to sit inside the 302pt drop is dropped rather than
    /// shrunk or clipped; the ribbon itself still renders.
    @Test func stillDrawsWhenTheNameCannotFit() {
        let long = String(repeating: "verylongappname", count: 6)
        #expect(ShieldRibbon.backdrop(subject: long, tone: .systemBlue, screen: screen) != nil)
    }

    @Test func drawsWithNoSubjectAtAll() {
        #expect(ShieldRibbon.backdrop(subject: nil, tone: .systemBlue, screen: screen) != nil)
        #expect(ShieldRibbon.backdrop(subject: "   ", tone: .systemBlue, screen: screen) != nil)
    }

    /// The spacer exists only to hold the title down the screen, so it must be
    /// the size of the slot and completely invisible.
    @Test func theTitleSpacerIsTransparent() throws {
        let spacer = try #require(ShieldRibbon.titleSpacer())
        #expect(spacer.size == CGSize(width: 100, height: 100))

        let cgImage = try #require(spacer.cgImage)
        // Start from opaque white and draw with `.copy`, so the source's alpha
        // replaces the buffer instead of compositing over it — the default
        // blend would leave the white behind and pass no matter what.
        var pixel: [UInt8] = [255, 255, 255, 255]
        let context = try #require(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setBlendMode(.copy)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        #expect(pixel[3] == 0, "The title spacer must not paint anything")
    }
}
