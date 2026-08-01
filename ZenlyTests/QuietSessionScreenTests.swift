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

    @Test func namesWhatIsBehindTheDoor() {
        #expect(ShieldMessage.title(subject: "Instagram") == "Instagram is behind this door.")
    }

    /// "It opens on its own in 16 minutes." The phrasing is the point: the door
    /// is on a timer, not a lock, and nothing is being asked of the user.
    @Test func saysTheDoorOpensByItself() {
        reset(); defer { reset() }
        ActiveSessionInfo.set(profileName: "Work", endsAt: Date().addingTimeInterval(16 * 60))

        let text = ShieldMessage.subtitle(custom: "")
        #expect(text.contains("opens on its own in 16 minutes"))
        #expect(text.contains("Nothing inside will have moved."))
        #expect(text.contains("Opens at"))
    }

    /// One minute, not "1 minutes".
    @Test func speaksTheLastMinuteProperly() {
        reset(); defer { reset() }
        ActiveSessionInfo.set(profileName: "Work", endsAt: Date().addingTimeInterval(40))
        #expect(ShieldMessage.subtitle(custom: "").contains("in 1 minute."))
    }

    /// With nothing running there is no honest number, so the screen keeps the
    /// half that is still true and drops the clock rather than inventing one.
    @Test func quotesNoTimeWithoutASession() {
        reset(); defer { reset() }
        let text = ShieldMessage.subtitle(custom: "")
        #expect(text.contains("Nothing inside will have moved."))
        #expect(!text.contains("opens on its own"))
        #expect(!text.contains("Opens at"))
    }

    /// An expired session is the same as no session — a door that has already
    /// opened must not still be announcing a time.
    @Test func ignoresASessionThatHasAlreadyEnded() {
        reset(); defer { reset() }
        ActiveSessionInfo.set(profileName: "Work", endsAt: Date().addingTimeInterval(-60))
        #expect(ActiveSessionInfo.endsAt == nil)
        #expect(!ShieldMessage.subtitle(custom: "").contains("Opens at"))
    }

    /// The user's own message is added to the screen, never in place of the
    /// lines that say when the door opens.
    @Test func addsACustomMessageWithoutDisplacingAnything() {
        reset(); defer { reset() }
        ActiveSessionInfo.set(profileName: "Work", endsAt: Date().addingTimeInterval(10 * 60))

        let text = ShieldMessage.subtitle(custom: "  You said 8pm.  ")
        #expect(text.contains("You said 8pm."))
        #expect(text.contains("opens on its own"))
        #expect(text.contains("Opens at"))
    }
}

// MARK: - Clearing up after a session that ended unattended

/// A session can run out while the phone is locked, which leaves the app
/// suspended with a Live Activity still on the Lock Screen and nothing running
/// to take it down. `BackgroundRefresh` sweeps it on its next window, and it
/// finds the lapsed session through `scheduledEnd`.
struct LapsedSessionTests {

    private func reset() { ActiveSessionInfo.clear() }

    /// The distinction the sweep depends on. `endsAt` goes nil the moment the
    /// session lapses — correct for the shield, useless for finding a card that
    /// still needs clearing — while `scheduledEnd` keeps reporting it.
    @Test func aLapsedSessionIsStillFindable() {
        reset(); defer { reset() }
        let ended = Date().addingTimeInterval(-90)
        ActiveSessionInfo.set(profileName: "Work", endsAt: ended)

        #expect(ActiveSessionInfo.endsAt == nil, "endsAt must not report a session that has run out")
        let scheduled = ActiveSessionInfo.scheduledEnd
        #expect(scheduled != nil, "The lapsed session is invisible, so its card can never be swept")
        #expect(abs((scheduled ?? .distantPast).timeIntervalSince(ended)) < 1)
    }

    /// The guard the sweep is behind: a session still running must be left alone.
    @Test func aRunningSessionIsNotTreatedAsLapsed() {
        reset(); defer { reset() }
        ActiveSessionInfo.set(profileName: "Work", endsAt: Date().addingTimeInterval(10 * 60))
        #expect((ActiveSessionInfo.scheduledEnd ?? .distantPast) > Date())
    }

    /// Nothing running, nothing to sweep.
    @Test func nothingIsReportedWhenNoSessionWasEverRecorded() {
        reset(); defer { reset() }
        #expect(ActiveSessionInfo.scheduledEnd == nil)
    }

    /// Pausing calls `clear()`, so a held session never looks lapsed — otherwise
    /// the sweep would tear down the card the user is about to resume from.
    @Test func aHeldSessionIsNotMistakenForALapsedOne() {
        reset(); defer { reset() }
        ActiveSessionInfo.set(profileName: "Work", endsAt: Date().addingTimeInterval(10 * 60))
        ActiveSessionInfo.clear()   // what pausing does
        #expect(ActiveSessionInfo.scheduledEnd == nil)
    }
}

// MARK: - 03 · the door

/// The door is what made this screen buildable. `ShieldConfiguration.icon` is
/// aspect-fit into a box measured on device at roughly 80 points; the ribbon it
/// replaced hung off the top edge at 302pt tall and never fitted, while a door
/// is centred and compact — the shape the slot actually is.
struct ShieldDoorTests {

    /// Square, to match the box. A taller canvas is aspect-fit *down*, which is
    /// exactly how the ribbon ended up 12pt wide on device.
    @Test func fillsTheIconBox() throws {
        let image = try #require(ShieldDoor.icon(tone: .systemBlue))
        #expect(image.size.width == image.size.height, "The canvas must stay square")
    }


    /// Small enough for the extension's budget. A shield extension killed for
    /// allocating too much is not reported — iOS silently substitutes its own
    /// default screen.
    @Test func staysWithinTheExtensionsBudget() throws {
        let image = try #require(ShieldDoor.icon(tone: .systemBlue))
        let cgImage = try #require(image.cgImage)
        #expect(cgImage.width * cgImage.height * 4 < 1_000_000)
    }

    /// The seam has to actually paint the tone. An empty canvas passes every
    /// other automated check identically to a working one.
    @Test func paintsTheSeamInTheTone() throws {
        let image = try #require(ShieldDoor.icon(tone: .systemBlue))
        #expect(try alpha(of: image, atFractionAcross: 0.5, down: 0.5) > 200,
                "The seam is not solid at the centre of the door")
    }

    /// It is a *seam*: bright down the middle, dark to either side. Without
    /// this, a canvas flooded with tone would pass.
    @Test func isALineRatherThanAWash() throws {
        let image = try #require(ShieldDoor.icon(tone: .systemBlue))
        let centre = try alpha(of: image, atFractionAcross: 0.5, down: 0.5)
        let offToTheSide = try alpha(of: image, atFractionAcross: 0.28, down: 0.5)
        #expect(centre > offToTheSide * 2,
                "Centre \(centre) vs side \(offToTheSide) — that is a wash, not a seam")
    }

    /// `linear-gradient(to bottom, transparent, tone 18%, tone 82%, transparent)`
    /// — the light fades out at both ends rather than stopping.
    @Test func fadesOutAtBothEnds() throws {
        let image = try #require(ShieldDoor.icon(tone: .systemBlue))
        let middle = try alpha(of: image, atFractionAcross: 0.5, down: 0.5)
        let top = try alpha(of: image, atFractionAcross: 0.5, down: 0.06)
        let bottom = try alpha(of: image, atFractionAcross: 0.5, down: 0.94)
        #expect(top < middle, "The seam does not fade at the top")
        #expect(bottom < middle, "The seam does not fade at the bottom")
    }

    /// Alpha of one pixel, addressed as a fraction of the image.
    private func alpha(of image: UIImage,
                       atFractionAcross across: Double,
                       down: Double) throws -> Int {
        let cgImage = try #require(image.cgImage)
        let x = Int(Double(cgImage.width) * across)
        let y = Int(Double(cgImage.height) * down)

        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = try #require(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setBlendMode(.copy)
        context.draw(cgImage, in: CGRect(x: -x, y: -(cgImage.height - y - 1),
                                         width: cgImage.width, height: cgImage.height))
        return Int(pixel[3])
    }
}

// MARK: - 03b · the ribbon, where it fits

/// The ribbon now belongs to the in-app confirmation, which owns its surface —
/// so it is drawn at the comp's own 44 x 302 with nothing clamping it.
struct ShieldRibbonTests {

    @Test func drawsTheCompsGeometry() throws {
        let image = try #require(ShieldRibbon.comp(subject: "Instagram", tone: .systemBlue))
        #expect(image.size.width == ShieldRibbon.compCanvasWidth)   // 44 + 40 each side
        #expect(image.size.height == 342)                           // 302 + 40 for the glow
    }

    /// A name too long for the drop is dropped rather than shrunk or clipped;
    /// the ribbon itself still renders.
    @Test func stillDrawsWhenTheNameCannotFit() {
        let long = String(repeating: "verylongappname", count: 6)
        #expect(ShieldRibbon.comp(subject: long, tone: .systemBlue) != nil)
    }

    @Test func drawsWithNoSubjectAtAll() {
        #expect(ShieldRibbon.comp(subject: nil, tone: .systemBlue) != nil)
        #expect(ShieldRibbon.comp(subject: "   ", tone: .systemBlue) != nil)
    }
}
