//
//  QuietSessionScreens.swift
//  ZenlyUITests
//
//  Walks the Quiet spec's session and insights screens — 03 (App paused),
//  04 (Complete), 04b (Ended early), 05 (Insights) and 06 (Insights · first
//  run) — and writes a PNG per state, so the built screens can be compared
//  against the comp without driving the simulator by hand.
//
//  Same conventions as `QuietEditorScreens`: shots go to $QUIET_SHOT_DIR when
//  set, otherwise NSTemporaryDirectory(), and are attached to the result bundle
//  either way.
//
//  Two of these need the app let past Screen Time, which Simulator will never
//  grant, so the suite passes `ZenlyUITestBypassScreenTime` (a DEBUG-only flag
//  in AuthorizationService). Screen 03 is not a SwiftUI view at all — iOS draws
//  it inside the ZenlyShield extension — so it is captured through the DEBUG
//  preview that is built from the extension's own ribbon bitmap and strings.
//
//  These are slow on purpose. 04 requires a focus session to actually run out
//  (the floor is five minutes) and 04b requires one to have genuinely elapsed,
//  because the point of both screens is the number in the middle. Faking the
//  clock would only prove the layout, which is the part that was never in doubt.
//

import XCTest

final class QuietSessionScreens: XCTestCase {

    /// The shortest session Home offers.
    private let minimumSessionMinutes = 5

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    // MARK: - Capture

    private var shotDirectory: URL {
        let raw = ProcessInfo.processInfo.environment["QUIET_SHOT_DIR"]
            ?? NSTemporaryDirectory().appending("quiet-shots")
        let url = URL(fileURLWithPath: raw)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? shot.pngRepresentation.write(to: shotDirectory.appendingPathComponent("\(name).png"))
    }

    // MARK: - Launch

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += arguments
        app.launch()
        return app
    }

    private func launchToHome(_ extra: [String] = []) -> XCUIApplication {
        let app = launch(["ZenlyUITestBypassScreenTime"] + extra)
        let tabBar = app.tabBars.firstMatch
        if !tabBar.waitForExistence(timeout: 6) {
            app.tap()                       // skip the splash
            if !tabBar.waitForExistence(timeout: 4) { completeOnboardingIfPresent(app) }
        }
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Never reached the main tab bar")
        endAnyRunningSession(app)
        return app
    }

    /// Walks the 5-page onboarding.
    ///
    /// Driven by "tap whatever forward action is currently on screen" rather
    /// than a fixed script, because the permission page changes shape depending
    /// on authorization: granted turns "Grant Screen Time Access" into a
    /// disabled "Access Granted" and "Maybe later" into "Continue". Under the
    /// Screen Time bypass we always get the granted variant.
    private func completeOnboardingIfPresent(_ app: XCUIApplication) {
        guard button(app, "Get Started").waitForExistence(timeout: 4) else { return }
        let forward = ["Get Started", "Next", "Continue", "Maybe later", "Start Focusing"]
        for _ in 0..<14 {
            if app.tabBars.firstMatch.exists { return }
            let moved = forward.contains { tapIfHittable(app, $0) }
            if !moved { usleep(400_000) }
        }
    }

    private func button(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// A paged `TabView` keeps its off-screen pages in the tree, so two buttons
    /// with the same label can coexist — take the one actually on screen.
    @discardableResult
    private func tapIfHittable(_ app: XCUIApplication, _ label: String,
                               timeout: TimeInterval = 0.6) -> Bool {
        let matches = app.buttons.matching(NSPredicate(format: "label == %@", label))
        guard matches.firstMatch.waitForExistence(timeout: timeout) else { return false }
        for index in 0..<matches.count {
            let element = matches.element(boundBy: index)
            if element.exists && element.isHittable && element.isEnabled {
                element.tap()
                return true
            }
        }
        return false
    }

    /// A schedule whose window covers "now" auto-starts a session, whose
    /// full-screen cover hides everything else. Clear it before capturing.
    private func endAnyRunningSession(_ app: XCUIApplication) {
        let hold = app.descendants(matching: .any)["session-hold-to-end"].firstMatch
        guard hold.waitForExistence(timeout: 2) else { return }
        hold.press(forDuration: 3.8)
        let leave = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'all for now' OR label ==[c] 'Done'")).firstMatch
        if leave.waitForExistence(timeout: 5) { leave.tap() }
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 8)
    }

    /// Starts a focus session at the shortest length Home allows and returns
    /// once the session screen is up.
    private func startShortestSession(_ app: XCUIApplication,
                                      _ file: StaticString = #filePath,
                                      _ line: UInt = #line) {
        let decrease = app.descendants(matching: .any)["Decrease focus duration"].firstMatch
        XCTAssertTrue(decrease.waitForExistence(timeout: 10),
                      "Home never became interactive", file: file, line: line)
        // The stepper clamps at 5; over-tapping is harmless and avoids
        // depending on whatever the profile's default happens to be.
        for _ in 0..<30 where decrease.isHittable { decrease.tap() }

        let begin = button(app, "Begin focus")
        XCTAssertTrue(begin.waitForExistence(timeout: 5), "No Begin focus button",
                      file: file, line: line)
        XCTAssertTrue(begin.isEnabled,
                      "Begin focus is disabled — the Screen Time bypass did not take",
                      file: file, line: line)
        begin.tap()

        let hold = app.descendants(matching: .any)["session-hold-to-end"].firstMatch
        XCTAssertTrue(hold.waitForExistence(timeout: 10), "Session screen never appeared",
                      file: file, line: line)
    }

    // MARK: - 03 · App paused

    /// The block screen, rendered from the shield extension's own ribbon bitmap
    /// and `ShieldMessage` strings.
    ///
    /// This is the real `AppPausedView`, not a mock: in the app it comes up on
    /// the session screen when you return after a shield stopped you, which is
    /// the comp's screen 03 on the one surface that can hold it. The launch
    /// argument only stands it up without a shield having fired, which Simulator
    /// cannot produce.
    ///
    /// The *system* shield is a different screen and deliberately not covered
    /// here — iOS assembles it in another process from a `ShieldConfiguration`,
    /// and nothing about that is observable from a test.
    func testAppPausedScreen() {
        let app = launch(["ZenlyPreviewBlockScreen", "Instagram"])
        let screen = app.descendants(matching: .any)["block-screen-preview"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "Block screen never appeared")

        XCTAssertTrue(app.staticTexts["Instagram is behind this door."].exists,
                      "The comp's headline is missing")

        // "It opens on its own in N minutes." — the phrasing is the screen's
        // argument, not decoration: the door is on a timer, not a lock. With no
        // artwork left, these two sentences are the entire screen.
        let opens = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'opens on its own'")).firstMatch
        XCTAssertTrue(opens.exists, "The screen never says the door opens by itself")

        capture(app, "03-app-paused")
    }

    // MARK: - 03b · Back to focus

    /// The in-app confirmation, where the ribbon lives now. This is the real
    /// `AppPausedView`: in the app it comes up on the session screen when you
    /// return after tapping "Back to focus", and hands you back to the timer on
    /// its own. The launch argument only stands it up without a shield having
    /// fired, which Simulator cannot produce.
    func testBackToFocusScreen() {
        let app = launch(["ZenlyPreviewShield", "Instagram"])
        let screen = app.descendants(matching: .any)["app-paused"].firstMatch
        XCTAssertTrue(screen.waitForExistence(timeout: 10), "Back-to-focus screen never appeared")

        XCTAssertTrue(app.staticTexts["Instagram is bookmarked."].exists,
                      "The comp's headline is missing")

        // The comp's eyebrow, in its own place above the headline — the thing
        // the system shield has to give up for want of a slot.
        let eyebrow = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'IN SESSION'")).firstMatch
        XCTAssertTrue(eyebrow.exists, "The tracked 'IN SESSION' eyebrow is missing")

        let returning = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'Returning to your session'")).firstMatch
        XCTAssertTrue(returning.exists, "The screen never promises to hand you back")

        capture(app, "03b-back-to-focus")
    }

    // MARK: - 04b · Ended early

    /// Runs a real session for a couple of minutes and ends it, so the ring's
    /// clock is a real elapsed time.
    func testEndedEarlyScreen() {
        let app = launchToHome()
        startShortestSession(app)

        // Long enough that the comp's m:ss reads like the comp's own "2:24".
        Thread.sleep(forTimeInterval: 145)

        let hold = app.descendants(matching: .any)["session-hold-to-end"].firstMatch
        XCTAssertTrue(hold.waitForExistence(timeout: 5), "Hold-to-end control vanished")
        hold.press(forDuration: 3.8)

        let tryShorter = app.buttons["summary-try-shorter"]
        XCTAssertTrue(tryShorter.waitForExistence(timeout: 12),
                      "Ended-early summary never appeared")
        capture(app, "04b-ended-early")

        // The ring's number is the whole argument of the screen. Its rendered
        // text is "2:30"; its accessibility label is the spoken expansion of the
        // same `completedSeconds` (VoiceOver would otherwise read the glyphs as
        // a time of day), and the label is what a UI test can actually read.
        // `SessionSummaryClockTests` covers the "2:30" formatting itself.
        let clock = app.descendants(matching: .any)["summary-elapsed-clock"].firstMatch
        XCTAssertTrue(clock.exists, "The ended-early ring has no elapsed-time label")
        XCTAssertTrue(clock.label.contains("second") || clock.label.contains("minute"),
                      "The ring is not reporting seconds — got \"\(clock.label)\"")

        button(app, "That\u{2019}s all for now").tap()
    }

    // MARK: - 04 · Complete

    /// Runs a session all the way out. Slow by nature — the floor is five
    /// minutes and the screen only exists once the timer reaches zero.
    func testCompleteScreen() {
        let app = launchToHome()
        startShortestSession(app)

        let done = app.buttons["summary-done"]
        let deadline = Date().addingTimeInterval(Double(minimumSessionMinutes) * 60 + 90)
        while !done.exists && Date() < deadline { Thread.sleep(forTimeInterval: 5) }

        XCTAssertTrue(done.waitForExistence(timeout: 30),
                      "Completion summary never appeared")
        XCTAssertTrue(app.staticTexts["A calm, unbroken session."].exists,
                      "The comp's completion line is missing")
        XCTAssertTrue(app.staticTexts["How did it feel?"].exists,
                      "The rating prompt is missing")
        capture(app, "04-complete")

        // Rate it, so the shot shows the filled dots the comp draws. Badges
        // unlocked on this session are inserted above the dots after `onAppear`,
        // which moves them mid-tap, so tap until the dot actually reports
        // selected rather than assuming the first one landed.
        let fourth = app.buttons["summary-rating-4"]
        XCTAssertTrue(fourth.waitForExistence(timeout: 5), "The 5-dot rating row is missing")
        var rated = false
        for _ in 0..<4 {
            if fourth.isHittable { fourth.tap() }
            usleep(600_000)
            if app.buttons["summary-rating-4"].isSelected { rated = true; break }
        }
        XCTAssertTrue(rated, "Tapping a rating dot never selected it — the target is too small")
        capture(app, "04-complete-rated")

        done.tap()
    }

    // MARK: - 05 / 06 · Insights

    /// First run: no sessions, so Insights shows the comp's empty state.
    func testInsightsFirstRunScreen() {
        let app = launchToHome()
        app.tabBars.buttons["Insights"].tap()

        let call = app.descendants(matching: .any)["insights-begin-first-focus"].firstMatch
        if !call.waitForExistence(timeout: 6) {
            // The store already has history from an earlier run in this
            // simulator. Skipping is honest; asserting would be a lie about
            // what was captured.
            capture(app, "06-insights-first-run-UNAVAILABLE")
            XCTFail("Insights is not in its first-run state — reset the simulator "
                    + "(xcrun simctl erase) to capture screen 06")
            return
        }
        XCTAssertTrue(app.staticTexts["Your focus story starts here"].exists)
        capture(app, "06-insights-first-run")
    }

    /// Populated: a seeded calendar week, so the chart, the rows and the goals
    /// all have something to draw.
    func testInsightsPopulatedScreen() {
        let app = launchToHome(["ZenlySeedDemoHistory"])
        app.tabBars.buttons["Insights"].tap()

        let hours = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'hours this week'")).firstMatch
        XCTAssertTrue(hours.waitForExistence(timeout: 8),
                      "Insights never rendered its weekly total")
        capture(app, "05-insights-top")

        let versus = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'vs last week' OR label CONTAINS[c] 'Same as last week'"))
            .firstMatch
        XCTAssertTrue(versus.exists, "The vs-last-week delta is missing")

        app.swipeUp()
        capture(app, "05-insights-goals")

        XCTAssertTrue(app.staticTexts["Current streak"].exists,
                      "The Goals section never reached Current streak")
    }
}
