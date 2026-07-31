//
//  QuietEditorScreens.swift
//  ZenlyUITests
//
//  Walks the Quiet spec's editor screens (Zenly Quiet.dc.html, 09–13 and 16–19)
//  and writes a PNG per state, so the built screens can be compared against the
//  comp without driving the simulator by hand.
//
//  Screenshots go to $QUIET_SHOT_DIR when set, otherwise NSTemporaryDirectory().
//  They are also attached to the result bundle.
//

import XCTest

final class QuietEditorScreens: XCTestCase {

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

    // MARK: - Navigation helpers

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let tabBar = app.tabBars.firstMatch
        if !tabBar.waitForExistence(timeout: 6) {
            app.tap()                       // skip the splash
            if !tabBar.waitForExistence(timeout: 4) {
                completeOnboardingIfPresent(app)
            }
        }
        _ = tabBar.waitForExistence(timeout: 10)
        return app
    }

    /// Walks the 5-page onboarding if it is showing (fresh install).
    private func completeOnboardingIfPresent(_ app: XCUIApplication) {
        guard named(app, "Get Started").waitForExistence(timeout: 4) else { return }
        for label in ["Get Started", "Next", "Next", "Maybe later", "Start Focusing"] {
            tapHittable(app, label)
        }
    }

    private func named(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// A paged TabView keeps off-screen pages in the tree, so several buttons
    /// with the same label can coexist — take the one actually on screen.
    @discardableResult
    private func tapHittable(_ app: XCUIApplication, _ label: String,
                             timeout: TimeInterval = 6) -> Bool {
        let matches = app.buttons.matching(NSPredicate(format: "label == %@", label))
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for index in 0..<matches.count {
                let element = matches.element(boundBy: index)
                guard element.exists else { continue }
                let frame = element.frame
                guard frame.width > 1, frame.height > 1, element.isHittable else { continue }
                element.tap()
                return true
            }
            usleep(200_000)
        }
        return false
    }

    /// Taps an element, scrolling it into view first if something (usually the
    /// keyboard) is covering it. Never falls back to a blind coordinate tap —
    /// that lands on whatever is on top, which in an editor means typing a
    /// stray letter into the field you just filled in.
    private func tap(_ element: XCUIElement, timeout: TimeInterval = 6) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        var attempts = 0
        while !element.isHittable && attempts < 4 {
            XCUIApplication().swipeUp()
            attempts += 1
        }
        guard element.isHittable else { return false }
        element.tap()
        return true
    }

    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement, tries: Int = 8) {
        var attempts = 0
        while !element.exists && attempts < tries {
            app.swipeUp()
            attempts += 1
        }
    }

    // MARK: - 09 → 13 · the profile editor

    func testProfileEditorScreens() throws {
        let app = launch()
        XCTAssertTrue(tap(app.tabBars.buttons["Schedule"]), "Schedule tab missing")

        let newProfile = app.buttons["new-profile"]
        scrollTo(app, newProfile)
        XCTAssertTrue(tap(newProfile), "New profile button missing")

        let nameField = app.textFields["profile-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 6), "Profile editor did not open")
        capture(app, "09-new-profile-live")

        // 10 · pressing the CTA with nothing entered flags what's missing.
        let save = app.buttons["profile-save"]
        XCTAssertTrue(tap(save), "Save missing")
        capture(app, "10-nothing-entered")

        // 11 · a name that already belongs to another profile.
        nameField.tap()
        nameField.typeText("Work")
        capture(app, "11-duplicate-name")

        // Clear it and enter something new, then pick an icon.
        nameField.press(forDuration: 1.2)
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 2) { selectAll.tap() }
        nameField.typeText("Learning")

        let icon = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'book'")).firstMatch
        XCTAssertTrue(tap(icon), "Icon grid missing")
        capture(app, "09b-ready-to-save")

        // 12 · blocking was asked for but Screen Time is unavailable (always the
        // case on Simulator, which is exactly the state the comp draws).
        XCTAssertTrue(tap(save), "Save missing")
        let blockedTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'permission'")).firstMatch
        if blockedTitle.waitForExistence(timeout: 4) {
            capture(app, "12-couldnt-save")
            let without = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'without blocking'")).firstMatch
            XCTAssertTrue(tap(without), "No way past the permission sheet")
        }

        // 13 · the confirmation.
        let ready = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'is ready'")).firstMatch
        XCTAssertTrue(ready.waitForExistence(timeout: 6), "Saved confirmation did not appear")
        capture(app, "13-saved")
    }

    // MARK: - 16 → 19 · the schedule editor

    func testScheduleEditorScreens() throws {
        let app = launch()
        XCTAssertTrue(tap(app.tabBars.buttons["Schedule"]), "Schedule tab missing")

        let addSchedule = app.buttons["add-schedule"]
        scrollTo(app, addSchedule)
        XCTAssertTrue(tap(addSchedule), "Add schedule missing")

        let titleField = app.textFields["schedule-title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 6), "Schedule editor did not open")
        capture(app, "16-new-schedule-live")

        // 17 · pressing the CTA with nothing chosen.
        let save = app.buttons["schedule-save"]
        XCTAssertTrue(tap(save), "Save missing")
        capture(app, "17-nothing-chosen")

        // Complete it: a title of its own, a day, and a profile — so the list
        // row can show the comp's full "Work · Deep focus" form.
        titleField.tap()
        titleField.typeText("Deep focus\n")   // return closes the keyboard
        XCTAssertTrue(tap(app.buttons["Monday"]), "Day row missing")
        XCTAssertTrue(tap(app.buttons["Work"]), "Profile row missing")
        capture(app, "16b-ready-to-save")

        XCTAssertTrue(tap(save), "Save missing")

        // 19 · the new row wears the tone wash and the NEW label, and is named
        // the way the comp names it.
        XCTAssertTrue(app.staticTexts["NEW"].waitForExistence(timeout: 6),
                      "The just-added schedule is not marked")
        XCTAssertTrue(app.staticTexts["Work · Deep focus"].exists,
                      "The row does not carry both the profile and the title")
        capture(app, "19-added")

        // 18 · a second schedule on the same day at the same hour collides.
        scrollTo(app, addSchedule)
        XCTAssertTrue(tap(addSchedule), "Add schedule missing the second time")
        _ = titleField.waitForExistence(timeout: 6)
        XCTAssertTrue(tap(app.buttons["Monday"]), "Day row missing")
        XCTAssertTrue(tap(app.buttons["Work"]), "Profile row missing")

        let clash = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'same hour'")).firstMatch
        XCTAssertTrue(clash.waitForExistence(timeout: 5),
                      "Two schedules in the same hour were not reported as a clash")
        capture(app, "18-times-that-dont-work")

        // Leave nothing behind: a saved 9-to-5 schedule collides with the next
        // test's, and one covering "now" auto-starts a session over the UI.
        _ = tap(app.buttons["quiet-cancel"])
        deleteFirstSchedule(app)
    }

    private func deleteFirstSchedule(_ app: XCUIApplication) {
        let row = app.staticTexts["NEW"].exists
            ? app.staticTexts["NEW"]
            : app.staticTexts.matching(NSPredicate(format: "label == 'Work'")).firstMatch
        guard row.waitForExistence(timeout: 4) else { return }
        row.press(forDuration: 1.0)                       // row context menu

        let delete = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Delete'")).firstMatch
        guard delete.waitForExistence(timeout: 3) else { return }
        delete.tap()

        let confirm = app.sheets.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Delete'")).firstMatch
        if confirm.waitForExistence(timeout: 3) { confirm.tap() }
    }
}
