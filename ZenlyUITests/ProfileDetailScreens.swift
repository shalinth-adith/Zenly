//
//  ProfileDetailScreens.swift
//  ZenlyUITests
//
//  Walks the Quiet spec's profile detail and edit screens — 20b ("Profile ·
//  Gym") and 20c ("Profile · edit") — and writes a PNG per state, matching the
//  conventions in `QuietEditorScreens`.
//
//  The first test is also the regression guard for the App Store rejection of
//  1.0 build 35: "In the Profiles section, the features were unresponsive,
//  preventing us from selecting a specific app to block." Tapping a profile row
//  used to do nothing visible, because the row's chevron had no destination.
//  If that ever regresses, `testTappingAProfileRowOpensTheDetail` fails.
//
//  Screenshots go to $QUIET_SHOT_DIR when set, otherwise NSTemporaryDirectory().
//

import XCTest

final class ProfileDetailScreens: XCTestCase {

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

    /// Screen Time can never be granted on Simulator, and the reviewer HAD
    /// granted it, so stand in for that with the DEBUG-only bypass flag.
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["ZenlyUITestBypassScreenTime",
                                "ZenlyUITestResetSession"]
        app.launch()
        let tabBar = app.tabBars.firstMatch
        if !tabBar.waitForExistence(timeout: 6) {
            app.tap()                       // skip the splash
            completeOnboardingIfPresent(app)
        }
        _ = tabBar.waitForExistence(timeout: 10)
        return app
    }

    /// With the bypass on, the permission page's secondary button reads
    /// "Continue" rather than "Maybe later", so drive the walk by whichever
    /// advancing label is hittable instead of a fixed script.
    private func completeOnboardingIfPresent(_ app: XCUIApplication) {
        guard named(app, "Get Started").waitForExistence(timeout: 6) else { return }
        let advancing = ["Get Started", "Next", "Continue", "Maybe later", "Start Focusing"]
        for _ in 0..<8 {
            if app.tabBars.firstMatch.exists { return }
            var moved = false
            for label in advancing where tapHittable(app, label, timeout: 1) {
                moved = true
                break
            }
            if !moved { usleep(400_000) }
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

    @discardableResult
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

    /// Get back to the tab bar. Ending a session is a deliberate hold, so tuck
    /// it away instead — every test launches with `ZenlyUITestResetSession`, so
    /// nothing carries into the next one regardless.
    private func endAnyRunningSession(_ app: XCUIApplication) {
        guard !app.tabBars.firstMatch.exists else { return }
        tapHittable(app, "Minimize timer", timeout: 3)
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 4)
    }

    /// Settings › Focus profiles — the sheet holding screens 20 / 20b / 21.
    private func openProfiles(_ app: XCUIApplication) {
        XCTAssertTrue(tap(app.tabBars.buttons["Settings"]), "Settings tab missing")
        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Focus profiles'")).firstMatch
        XCTAssertTrue(tap(row), "Focus profiles row missing")
        XCTAssertTrue(app.staticTexts["Profiles"].waitForExistence(timeout: 6),
                      "Profiles sheet did not open")
    }

    // MARK: - 20b · the row's chevron leads somewhere

    func testTappingAProfileRowOpensTheDetail() throws {
        let app = launch()
        openProfiles(app)
        capture(app, "20-profiles-list")

        let work = app.staticTexts["Work"].firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 6), "No profile rows")
        work.tap()

        // 20b — the detail the chevron promises.
        XCTAssertTrue(app.buttons["profile-detail-edit"].waitForExistence(timeout: 6),
                      "REGRESSION: tapping a profile row opened nothing. The row draws a "
                      + "chevron, so it must push screen 20b — this is the App Store "
                      + "rejection of 1.0 (35).")
        capture(app, "20b-profile-detail")

        XCTAssertTrue(app.staticTexts["Focus"].exists, "Stat strip missing")
        XCTAssertTrue(app.buttons["profile-detail-delete"].exists, "Delete profile missing")

        // 20b back to the list, and the list back to Settings. A sheet with no
        // visible way out is only dismissible by dragging it down, which nothing
        // on screen tells you.
        XCTAssertTrue(tap(app.buttons["profile-detail-back"]), "Back to Profiles missing")
        XCTAssertTrue(tap(app.buttons["profiles-back"]), "Profiles has no way back to Settings")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 6),
                      "Closing Profiles did not return to Settings")
    }

    // MARK: - 20c · Edit opens the editor, Save writes the change

    func testEditOpensTheEditorAndSavePersists() throws {
        let app = launch()
        openProfiles(app)

        let study = app.staticTexts["Study"].firstMatch
        XCTAssertTrue(study.waitForExistence(timeout: 6), "No Study profile")
        study.tap()

        XCTAssertTrue(tap(app.buttons["profile-detail-edit"]), "Edit button missing on 20b")

        // 20c
        let nameField = app.textFields["profile-edit-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 6), "Edit profile sheet did not open")
        capture(app, "20c-profile-edit")

        // Rename it, and confirm Save writes through to the list.
        nameField.tap()
        nameField.press(forDuration: 1.2)
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 2) { selectAll.tap() }
        nameField.typeText("Reading")

        XCTAssertTrue(tap(app.buttons["profile-edit-save"]), "Save missing")

        // Back on 20b, then back to the list — both must show the new name.
        XCTAssertTrue(app.staticTexts["Reading"].waitForExistence(timeout: 6),
                      "Save did not apply the new name to the detail screen")
        capture(app, "20b-after-rename")

        XCTAssertTrue(tap(app.buttons["profile-detail-back"]), "Back button missing")
        XCTAssertTrue(app.staticTexts["Reading"].waitForExistence(timeout: 6),
                      "Save did not apply the new name to the profiles list")
    }

    /// Control for the test below: does the Focus tab's own "Begin focus" put
    /// the session on screen? Isolates a presentation problem in `HomeView` from
    /// a routing problem in the profile editor.
    func testBeginFocusFromHomeShowsTheSession() throws {
        let app = launch()
        XCTAssertTrue(tap(app.tabBars.buttons["Focus"]), "Focus tab missing")
        XCTAssertTrue(tapHittable(app, "Begin focus"), "Begin focus not tappable")
        sleep(2)
        capture(app, "13c-session-from-home")

        let ending = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'end' OR label CONTAINS[c] 'minimi'")).firstMatch
        let reached = ending.waitForExistence(timeout: 8)
        XCTAssertTrue(reached, "The session screen did not come up from Home either — "
                      + "this is a HomeView presentation problem, not a routing one.")
        endAnyRunningSession(app)
    }

    // MARK: - Saving a profile ends on the Focus screen, not mid-session

    /// The saved screen (Quiet 13) deliberately does NOT start a session.
    ///
    /// It used to, and doing so meant starting one two sheets deep on the
    /// Settings tab — which left the session running with no timer, no pause and
    /// no way to end it, and then took ten seconds to appear once that was
    /// half-fixed. "Done" selects the new profile and gets out of the way, so
    /// the session begins where every other one does.
    func testSavingAProfileSelectsItAndLeavesTheUserOnFocus() throws {
        let app = launch()
        // Through the Schedule tab's "New profile": the editor is presented
        // straight from a tab there, so "Done" lands back on the tab bar. From
        // Settings it returns to the Profiles sheet you came from, which is
        // correct but has no tab bar to walk to.
        XCTAssertTrue(tap(app.tabBars.buttons["Schedule"]), "Schedule tab missing")
        let newProfile = app.buttons["new-profile"]
        scrollTo(app, newProfile)
        XCTAssertTrue(tap(newProfile), "New profile button missing")

        let nameField = app.textFields["profile-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 6), "Profile editor did not open")
        nameField.tap()
        nameField.typeText("Reading room")
        let icon = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'book'")).firstMatch
        XCTAssertTrue(tap(icon), "Icon grid missing")
        XCTAssertTrue(tap(app.buttons["profile-save"]), "Save missing")

        // Screen 13. No session is offered here — that is the point.
        let done = app.buttons["profile-saved-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 6), "Saved confirmation did not appear")
        capture(app, "13-saved-no-start")
        XCTAssertFalse(app.buttons["profile-saved-start"].exists,
                       "REGRESSION: the saved screen is offering to start a session again.")
        done.tap()

        // The new profile is selected, so Focus is one tap from beginning it.
        XCTAssertTrue(tap(app.tabBars.buttons["Focus"], timeout: 8), "Focus tab missing")
        // Each profile in the switcher is a Button carrying the name as its
        // accessibility label, not a static text of its own.
        XCTAssertTrue(app.buttons["Reading room"].waitForExistence(timeout: 6),
                      "The new profile is not on the Focus screen")
        XCTAssertTrue(tapHittable(app, "Begin focus"),
                      "Begin focus is not available for the profile just created")

        let ending = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'end' OR label CONTAINS[c] 'minimi'")).firstMatch
        XCTAssertTrue(ending.waitForExistence(timeout: 4),
                      "Starting the new profile from Focus did not show the session")
        // It ran the profile just created, which is what "selected on the way
        // out" has to mean for the Focus screen to be a fair place to send you.
        // The session screen names it as "FOCUSING · READING ROOM".
        let named = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Reading room'")).firstMatch
        XCTAssertTrue(named.waitForExistence(timeout: 4),
                      "The session that started is not the profile just created")
        capture(app, "13b-session-begun-from-focus")
        endAnyRunningSession(app)
    }

    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement, tries: Int = 8) {
        var attempts = 0
        while !element.exists && attempts < tries {
            app.swipeUp()
            attempts += 1
        }
    }

    // MARK: - The picker an existing profile could never reach

    func testBlockedAppsPickerOpensForAnExistingProfile() throws {
        let app = launch()
        openProfiles(app)

        let gym = app.staticTexts["Gym"].firstMatch
        XCTAssertTrue(gym.waitForExistence(timeout: 6), "No Gym profile")
        gym.tap()
        XCTAssertTrue(tap(app.buttons["profile-detail-edit"]), "Edit button missing on 20b")
        XCTAssertTrue(app.textFields["profile-edit-name"].waitForExistence(timeout: 6),
                      "Edit profile sheet did not open")

        // "Block everything" is on by default, which hides the blocked-apps row.
        // Turning it off is the only way to reach a specific selection — the
        // control the comp's filled-in example does not draw.
        let toggle = app.switches.firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 6), "Block everything toggle missing")
        if (toggle.value as? String) == "1" { toggle.tap() }

        let choose = app.buttons["profile-edit-choose-blocked"]
        for _ in 0..<6 where !choose.exists { app.swipeUp() }
        XCTAssertTrue(tap(choose), "Blocked apps 'Choose' row not tappable")

        // The system picker is a remote view; its "Choose Activities" title is
        // the only stable thing to assert on.
        let picker = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Choose Activities'")).firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 8),
                      "The Screen Time picker did not present for an existing profile")
        capture(app, "20c-blocked-apps-picker")
    }
}
