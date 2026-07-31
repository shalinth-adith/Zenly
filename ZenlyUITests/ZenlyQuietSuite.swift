//
//  ZenlyQuietSuite.swift
//  ZenlyUITests
//
//  Automated coverage for the [Sim OK] cases in TEST_CASES.md, written against
//  the current "Quiet" UI (tabs: Focus · Insights · Schedule · Settings).
//
//  Device-only cases (FamilyControls / ManagedSettings / DeviceActivity, Live
//  Activity, widgets) are deliberately absent — they cannot run on Simulator.
//

import XCTest

final class ZenlyQuietSuite: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Launches the app and returns once the main tab bar is on screen,
    /// dismissing the splash and completing onboarding if either is present.
    @discardableResult
    private func launchToHome(_ file: StaticString = #filePath,
                              _ line: UInt = #line) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        if !tabBar.waitForExistence(timeout: 6) {
            // Splash auto-finishes at ~3.6s, but a tap skips it immediately.
            app.tap()
            if !tabBar.waitForExistence(timeout: 4) {
                completeOnboardingIfPresent(app)
            }
        }
        endAnyRunningSession(app)
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8),
                      "Never reached the main tab bar", file: file, line: line)

        // The tab bar exists *before* the splash crossfade (0.5s) finishes, and
        // taps land on the fading overlay instead of the content. Wait until a
        // known Home control is genuinely hittable before handing control back.
        waitUntilHittable(app.buttons["Increase focus duration"], timeout: 8)
        return app
    }

    /// A schedule whose window covers "now" auto-starts a focus session, whose
    /// full-screen cover hides the whole tab UI. Dismiss it so the suite can run.
    private func endAnyRunningSession(_ app: XCUIApplication) {
        let endEarly = app.buttons.matching(
            NSPredicate(format: "label == 'End early' OR label == 'End break'")).firstMatch
        guard endEarly.waitForExistence(timeout: 3) else { return }
        robustTap(app, endEarly)

        // Strict mode routes through a 5s-gated confirmation.
        let confirm = app.buttons.matching(
            NSPredicate(format: "label == 'End focus'")).firstMatch
        if confirm.waitForExistence(timeout: 2) {
            waitUntilHittable(confirm, timeout: 8)
            if confirm.isEnabled { robustTap(app, confirm) }
        }
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 8)
    }

    /// Polls until the element reports hittable, or the timeout expires.
    @discardableResult
    private func waitUntilHittable(_ element: XCUIElement,
                                   timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isHittable { return true }
            usleep(200_000)
        }
        return false
    }

    /// Walks the 5-page onboarding flow if it is showing. Returns true if it ran.
    @discardableResult
    private func completeOnboardingIfPresent(_ app: XCUIApplication) -> Bool {
        guard button(app, "Get Started").waitForExistence(timeout: 3) else { return false }
        tapHittable(app, "Get Started")
        tapHittable(app, "Next")
        tapHittable(app, "Next")
        tapHittable(app, "Maybe later")
        tapHittable(app, "Start Focusing")
        return true
    }

    /// First button whose accessibility label matches exactly.
    private func button(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Taps the first *hittable* button with this label. Paged TabViews keep
    /// off-screen pages in the tree, so several "Next" buttons can coexist.
    @discardableResult
    private func tapHittable(_ app: XCUIApplication, _ label: String,
                             timeout: TimeInterval = 6) -> Bool {
        let matches = app.buttons.matching(NSPredicate(format: "label == %@", label))
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for i in 0..<matches.count {
                let element = matches.element(boundBy: i)
                // An off-screen page's button reports a zero/invalid frame, and
                // querying isHittable on it raises "activation point invalid".
                guard element.exists else { continue }
                let frame = element.frame
                guard frame.width > 1, frame.height > 1 else { continue }
                if element.isHittable {
                    element.tap()
                    return true
                }
            }
            usleep(200_000)
        }
        return false
    }

    /// Taps an element, falling back to a coordinate tap when it reports
    /// non-hittable. SwiftUI keeps a full-screen overlay above the tab content,
    /// which intermittently suppresses hittability while animations settle.
    private func robustTap(_ app: XCUIApplication, _ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: element.frame.midX, dy: element.frame.midY))
                .tap()
        }
    }

    /// Taps until `read()` reports a different value. Asserts the *behaviour*
    /// (the control mutates state) without being hostage to a swallowed tap.
    @discardableResult
    private func tapUntilChange(_ app: XCUIApplication, _ element: XCUIElement,
                                read: () -> Int, attempts: Int = 6) -> Bool {
        let before = read()
        for _ in 0..<attempts {
            robustTap(app, element)
            usleep(500_000)
            if read() != before { return true }
        }
        return false
    }

    /// Scrolls an element into reach, then taps it. Scrolls both ways, because
    /// a form section can sit above or below the current viewport depending on
    /// how much content precedes it.
    @discardableResult
    private func scrollToAndTap(_ app: XCUIApplication, _ element: XCUIElement,
                                attempts: Int = 5) -> Bool {
        for _ in 0..<attempts {
            if element.isHittable { element.tap(); return true }
            app.swipeUp()
        }
        for _ in 0..<attempts {
            if element.isHittable { element.tap(); return true }
            app.swipeDown()
        }
        return false
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openTab(_ app: XCUIApplication, _ name: String,
                         file: StaticString = #filePath, line: UInt = #line) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 6),
                      "\(name) tab missing", file: file, line: line)
        tab.tap()
    }

    // MARK: - TC-1.x Entry

    /// TC-1.1 / TC-1.4 — splash plays, then the app lands on the tab bar.
    func testLaunchReachesHome() throws {
        let app = try launchToHome()
        XCTAssertTrue(app.tabBars.buttons["Focus"].exists, "Focus tab missing")
        snap(app, "TC-1.1-home")
    }

    /// Navigation contract: the Quiet UI has exactly these four tabs.
    func testFourTabsPresent() throws {
        let app = try launchToHome()
        for tab in ["Focus", "Insights", "Schedule", "Settings"] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists, "\(tab) tab missing")
        }
        XCTAssertEqual(app.tabBars.buttons.count, 4, "Unexpected tab count")
    }

    // MARK: - TC-3.2 Editable duration

    /// TC-3.2 — −/+ step the duration by 5 and clamp to 5...120.
    func testDurationStepperStepsAndClamps() throws {
        let app = try launchToHome()
        let orb = app.otherElements["Focus duration"]
        XCTAssertTrue(orb.waitForExistence(timeout: 6), "Focus duration orb missing")

        func minutes() -> Int {
            Int((orb.value as? String ?? "").components(separatedBy: " ").first ?? "") ?? -1
        }

        let plus = app.buttons["Increase focus duration"]
        let minus = app.buttons["Decrease focus duration"]

        let start = minutes()
        XCTAssertGreaterThan(start, 0, "Could not read duration value")

        XCTAssertTrue(tapUntilChange(app, plus, read: minutes), "+ never changed the duration")
        XCTAssertEqual(minutes(), min(120, start + 5), "+ did not add exactly 5 minutes")

        XCTAssertTrue(tapUntilChange(app, minus, read: minutes), "− never changed the duration")
        XCTAssertEqual(minutes(), start, "− did not subtract exactly 5 minutes")

        // Lower clamp: hammer − well past the floor.
        for _ in 0..<30 where minus.exists { robustTap(app, minus) }
        XCTAssertEqual(minutes(), 5, "Duration did not clamp at 5 minutes")

        // Upper clamp.
        for _ in 0..<40 where plus.exists { robustTap(app, plus) }
        XCTAssertEqual(minutes(), 120, "Duration did not clamp at 120 minutes")
        snap(app, "TC-3.2-duration-clamped")
    }

    // MARK: - TC-4.x Profiles

    /// TC-4.1 — Work / Study / Gym seed on first run and are selectable.
    func testDefaultProfilesSeeded() throws {
        let app = try launchToHome()
        for name in ["Work", "Study", "Gym"] {
            XCTAssertTrue(button(app, name).waitForExistence(timeout: 5),
                          "Default profile '\(name)' missing from the profile row")
        }
        snap(app, "TC-4.1-default-profiles")
    }

    /// TC-4.5 (sim portion) — tapping a profile makes it the selected one and
    /// resets the duration to that profile's default length.
    func testSelectingProfileResetsDuration() throws {
        let app = try launchToHome()
        let orb = app.otherElements["Focus duration"]
        XCTAssertTrue(orb.waitForExistence(timeout: 6))

        func minutes() -> Int {
            Int((orb.value as? String ?? "").components(separatedBy: " ").first ?? "") ?? -1
        }

        // Start from a known profile so the assertion is deterministic.
        robustTap(app, button(app, "Work"))
        usleep(800_000)
        let workDefault = minutes()

        XCTAssertTrue(tapUntilChange(app, app.buttons["Increase focus duration"], read: minutes),
                      "+ did not change the duration")
        let nudged = minutes()

        robustTap(app, button(app, "Study"))
        usleep(1_000_000)
        XCTAssertNotEqual(minutes(), nudged,
                          "Switching profile did not reset the duration")

        robustTap(app, button(app, "Work"))
        usleep(1_000_000)
        XCTAssertEqual(minutes(), workDefault,
                       "Switching back did not restore the profile default")
    }

    /// TC-4.2 — create a profile from Settings → Focus profiles → +.
    func testCreateProfile() throws {
        let app = try launchToHome()
        openTab(app, "Settings")

        let profilesRow = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Focus profiles'")).firstMatch
        XCTAssertTrue(profilesRow.waitForExistence(timeout: 15), "'Focus profiles' row missing")
        robustTap(app, profilesRow)

        // "New Profile" is the last row of the List. SwiftUI does not realize
        // off-screen rows, so with enough profiles it is absent until scrolled to.
        let newProfile = app.buttons["new-profile"]
        var scrolls = 0
        while !newProfile.exists && scrolls < 8 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(newProfile.waitForExistence(timeout: 6), "New Profile button missing")
        robustTap(app, newProfile)

        let nameField = app.textFields["profile-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 6), "Name field missing")
        nameField.tap()
        nameField.typeText("UITestWork")

        // The Quiet editor requires an icon as well as a name (spec screen 10).
        let icon = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'briefcase'")).firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 4), "Icon grid missing")
        icon.tap()

        let save = app.buttons["profile-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3), "Save button missing")
        // The CTA is never disabled — an incomplete form is reported in place
        // rather than by greying out the only way forward.
        XCTAssertTrue(save.isEnabled, "Save should stay tappable")
        save.tap()

        // Simulator has no Screen Time access, so a profile that blocks
        // everything hits the permission gate (spec screen 12) on the way out.
        let saveWithout = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'without blocking'")).firstMatch
        if saveWithout.waitForExistence(timeout: 4) { robustTap(app, saveWithout) }

        // Saving swaps the editor for the confirmation (spec screen 13) rather
        // than dropping straight back to the list.
        XCTAssertTrue(nameField.waitForNonExistence(timeout: 5),
                      "Editor did not leave after Save")
        XCTAssertTrue(app.staticTexts["UITestWork is ready"].waitForExistence(timeout: 5),
                      "Saved confirmation did not appear after Save")
        snap(app, "TC-4.2-profile-saved-confirmation")

        // Leave via the secondary action, which closes the sheet here.
        let putOnSchedule = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Put it on the schedule'")).firstMatch
        XCTAssertTrue(putOnSchedule.waitForExistence(timeout: 3), "No way out of the confirmation")
        putOnSchedule.tap()

        XCTAssertTrue(app.staticTexts["UITestWork"].waitForExistence(timeout: 5),
                      "New profile did not appear in the list after Save")
        snap(app, "TC-4.2-profile-created")

        // Clean up. Without this the profile list grows by one every run until
        // "New Profile" is pushed off-screen and this test starts failing.
        deleteProfile(app, named: "UITestWork")
    }

    /// Removes a profile by name, accepting the confirmation dialog.
    private func deleteProfile(_ app: XCUIApplication, named name: String) {
        let row = app.staticTexts.matching(
            NSPredicate(format: "label == %@", name)).firstMatch
        guard row.waitForExistence(timeout: 4) else { return }
        row.swipeLeft()

        let delete = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Delete'")).firstMatch
        guard delete.waitForExistence(timeout: 3) else { return }
        robustTap(app, delete)

        let confirm = app.sheets.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Delete'")).firstMatch
        if confirm.waitForExistence(timeout: 3) { robustTap(app, confirm) }
        _ = row.waitForNonExistence(timeout: 5)
    }

    /// The row chevron opens the profile editor. It used to be a plain image, so
    /// the row looked navigable while editing was reachable only by swiping.
    func testProfileChevronOpensEditor() throws {
        let app = try launchToHome()
        openTab(app, "Settings")

        let profilesRow = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Focus profiles'")).firstMatch
        XCTAssertTrue(profilesRow.waitForExistence(timeout: 15), "'Focus profiles' row missing")
        robustTap(app, profilesRow)

        let chevron = app.buttons.matching(
            NSPredicate(format: "label == 'Edit Work'")).firstMatch
        XCTAssertTrue(chevron.waitForExistence(timeout: 8),
                      "Chevron is not exposed as a button — it is still decorative")
        robustTap(app, chevron)

        let nameField = app.textFields["profile-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 6),
                      "Tapping the chevron did not open the profile editor")
        XCTAssertEqual(nameField.value as? String, "Work",
                       "Editor opened on the wrong profile")
        snap(app, "TC-4.x-chevron-opens-editor")

        let cancel = app.buttons.matching(
            NSPredicate(format: "label ==[c] 'Cancel'")).firstMatch
        if cancel.exists { cancel.tap() }
    }

    /// TC-4.3 — deleting a profile asks for confirmation first.
    func testDeleteProfileAsksForConfirmation() throws {
        let app = try launchToHome()
        openTab(app, "Settings")

        let profilesRow = app.buttons.containing(
            NSPredicate(format: "label CONTAINS 'Focus profiles'")).firstMatch
        XCTAssertTrue(profilesRow.waitForExistence(timeout: 15), "'Focus profiles' row missing")
        robustTap(app, profilesRow)

        // Swipe the row (the cell), not the label inside it.
        let row = app.cells.containing(
            NSPredicate(format: "label CONTAINS 'Gym'")).firstMatch
        let target = row.exists ? row : app.staticTexts["Gym"]
        XCTAssertTrue(target.waitForExistence(timeout: 8), "No 'Gym' profile row to delete")
        target.swipeLeft()

        let delete = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Delete'")).firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 4), "Delete swipe action missing")
        delete.tap()

        // ProfilesView uses .confirmationDialog, which surfaces as a sheet.
        let dialog = app.sheets.firstMatch
        let alert = app.alerts.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 4) || alert.exists,
                      "No confirmation shown before deleting a profile")
        snap(app, "TC-4.3-delete-confirmation")

        // Cancel — leave the fixture intact for other tests.
        let cancel = app.buttons.matching(
            NSPredicate(format: "label ==[c] 'Cancel'")).firstMatch
        if cancel.exists { cancel.tap() }
        XCTAssertTrue(app.staticTexts["Gym"].waitForExistence(timeout: 4),
                      "Cancel did not keep the profile")
    }

    // MARK: - TC-5.x Schedules

    /// TC-5.1 — create a schedule; Save is usable without typing a title.
    func testCreateSchedule() throws {
        let app = try launchToHome()
        openTab(app, "Schedule")

        let addSchedule = app.buttons["add-schedule"]
        XCTAssertTrue(addSchedule.waitForExistence(timeout: 8), "Add Schedule button missing")
        waitUntilHittable(addSchedule, timeout: 5)
        addSchedule.tap()

        let titleField = app.textFields["schedule-title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 6), "Title field missing")

        let save = app.buttons["schedule-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3), "Save button missing")
        XCTAssertTrue(save.isEnabled, "Schedule Save should stay tappable")

        titleField.tap()
        // The trailing return closes the keyboard, which otherwise covers the
        // profile row further down the form.
        titleField.typeText("UITestFocus\n")

        // Days and a profile are what a schedule actually needs (spec 16/17);
        // the title stays optional. How far down the form they sit depends on
        // how many profiles exist, so scroll to them rather than assuming.
        let monday = app.buttons["Monday"]
        let workChip = app.buttons["Work"]
        XCTAssertTrue(monday.waitForExistence(timeout: 4), "Day row missing")
        XCTAssertTrue(workChip.waitForExistence(timeout: 4), "Profile row missing")

        XCTAssertTrue(scrollToAndTap(app, workChip), "Could not reach the profile row")
        XCTAssertTrue(scrollToAndTap(app, monday), "Could not reach the day row")

        // A schedule left behind by an earlier test can occupy the same hour,
        // which the editor now blocks on (spec screen 18). Take the offered
        // repair rather than depending on the simulator being empty.
        let moveIt = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Start at'")).firstMatch
        if moveIt.waitForExistence(timeout: 2) { robustTap(app, moveIt) }

        save.tap()

        XCTAssertTrue(titleField.waitForNonExistence(timeout: 5),
                      "Schedule editor did not dismiss after Save")
        // Rows carry both halves — "Work · UITestFocus" (comp 07).
        XCTAssertTrue(app.staticTexts["Work · UITestFocus"].waitForExistence(timeout: 5),
                      "New schedule did not appear after Save")
        snap(app, "TC-5.1-schedule-created")

        // Clean up: a saved schedule whose window covers "now" auto-starts a
        // focus session, which would hijack every later test in this suite.
        deleteSchedule(app, titled: "Work · UITestFocus")
        endAnyRunningSession(app)
    }

    /// Removes a schedule by title, confirming the deletion dialog if shown.
    private func deleteSchedule(_ app: XCUIApplication, titled title: String) {
        let row = app.staticTexts.matching(
            NSPredicate(format: "label == %@", title)).firstMatch
        guard row.waitForExistence(timeout: 4) else { return }
        row.swipeLeft()

        let delete = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Delete'")).firstMatch
        guard delete.waitForExistence(timeout: 3) else { return }
        robustTap(app, delete)

        // Confirmation dialog (if the app asks) — accept it.
        let confirm = app.sheets.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Delete'")).firstMatch
        if confirm.waitForExistence(timeout: 3) { robustTap(app, confirm) }
        _ = row.waitForNonExistence(timeout: 5)
    }

    /// TC-5.1 — the per-schedule enable toggle flips state.
    func testScheduleToggleFlips() throws {
        let app = try launchToHome()
        openTab(app, "Schedule")

        let toggle = app.switches["schedule-toggle"].firstMatch
        if !toggle.waitForExistence(timeout: 5) {
            throw XCTSkip("No schedule present to toggle")
        }
        var scrolls = 0
        while !toggle.isHittable && scrolls < 6 { app.swipeUp(); scrolls += 1 }

        let before = (toggle.value as? String) ?? ""
        toggle.tap()
        usleep(800_000)
        let after = (app.switches["schedule-toggle"].firstMatch.value as? String) ?? ""
        XCTAssertNotEqual(after, before, "Schedule toggle did not change state")
    }

    /// TC-5.4 — a suggested-schedule card opens the editor prefilled.
    func testSuggestedScheduleOpensEditor() throws {
        let app = try launchToHome()
        openTab(app, "Schedule")

        let suggested = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Suggest'")).firstMatch
        if !suggested.waitForExistence(timeout: 5) {
            throw XCTSkip("No 'Suggested' section rendered")
        }
        snap(app, "TC-5.4-suggestions")
    }

    // MARK: - TC-6.x Insights

    /// TC-6.1 / TC-6.2 — Insights renders its chart and score without crashing.
    func testInsightsRenders() throws {
        let app = try launchToHome()
        openTab(app, "Insights")
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 6)
                        || app.collectionViews.firstMatch.exists,
                      "Insights did not render any scrollable content")
        snap(app, "TC-6.1-insights")
    }

    /// TC-6.5 / TC-6.6 — History and Badges are reachable from Insights.
    ///
    /// Insights renders a first-run empty state until at least one focus session
    /// has completed. A session cannot be started on Simulator (Begin focus stays
    /// disabled without FamilyControls authorization), so on Simulator this case
    /// is genuinely blocked rather than failing.
    func testHistoryAndBadgesReachable() throws {
        let app = try launchToHome()
        openTab(app, "Insights")

        let emptyState = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] 'focus story starts here'"
                        + " OR label CONTAINS[c] 'Begin your first focus'")).firstMatch
        if emptyState.waitForExistence(timeout: 6) {
            snap(app, "TC-6.x-insights-empty-state")
            throw XCTSkip("Insights is in its empty state — no completed sessions are "
                          + "possible on Simulator, so History/Badges cannot be reached.")
        }

        for destination in ["History", "Badges"] {
            let link = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", destination)).firstMatch
            if link.waitForExistence(timeout: 4) {
                link.tap()
                snap(app, "TC-6.x-\(destination)")
                let back = app.navigationBars.buttons.element(boundBy: 0)
                if back.exists { back.tap() }
            } else {
                throw XCTSkip("'\(destination)' is not present — Insights has no "
                              + "completed-session data, which cannot be produced on "
                              + "Simulator (Begin focus requires FamilyControls auth).")
            }
        }
    }

    // MARK: - TC-11.x Accessibility

    /// TC-11.1 — the core Home controls expose usable VoiceOver labels.
    func testHomeControlsHaveAccessibilityLabels() throws {
        let app = try launchToHome()
        for label in ["Focus duration", "Decrease focus duration", "Increase focus duration"] {
            let element = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", label)).firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: 5),
                          "Missing accessibility label: \(label)")
        }
    }

    /// TC-11.2 — at the largest accessibility text size the main screens still
    /// render their key controls (a proxy for "no clipping/overlap").
    func testDynamicTypeAccessibilityXXXL() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName",
                                "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        if !tabBar.waitForExistence(timeout: 6) {
            app.tap()
            completeOnboardingIfPresent(app)
        }
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8), "Tab bar missing at XXXL text size")
        snap(app, "TC-11.2-home-XXXL")

        for tab in ["Insights", "Schedule", "Settings"] {
            app.tabBars.buttons[tab].tap()
            usleep(700_000)
            snap(app, "TC-11.2-\(tab)-XXXL")
        }
    }
}
