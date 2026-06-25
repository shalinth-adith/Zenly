//
//  ZenlyUITests.swift
//  ZenlyUITests
//
//  Created by shalinth adithyan on 17/06/26.
//

import XCTest

final class ZenlyUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testCreateProfileSaveWorks() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait out the splash overlay, then go to Profiles.
        let profilesTab = app.tabBars.buttons["Profiles"]
        XCTAssertTrue(profilesTab.waitForExistence(timeout: 10), "Profiles tab missing")
        Thread.sleep(forTimeInterval: 3)

        let newProfile = app.buttons["new-profile"]
        profilesTab.tap()
        if !newProfile.waitForExistence(timeout: 4) {
            profilesTab.tap() // retry once if the first tap was swallowed by splash
        }
        XCTAssertTrue(newProfile.waitForExistence(timeout: 6), "New Profile button missing")
        newProfile.tap()

        let nameField = app.textFields["profile-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Name field missing")
        nameField.tap()
        nameField.typeText("UITestWork")

        let save = app.buttons["profile-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 2), "Save button missing")
        // Directly tests the 'stale disabled' hypothesis:
        XCTAssertTrue(save.isEnabled, "Save button is DISABLED after typing a name")
        save.tap()

        // The sheet must dismiss AND the new profile must appear.
        XCTAssertTrue(nameField.waitForNonExistence(timeout: 4),
                      "Editor sheet did NOT dismiss after Save")
        XCTAssertTrue(app.staticTexts["UITestWork"].waitForExistence(timeout: 5),
                      "New profile did not appear after Save")
    }

    @MainActor
    func testCreateScheduleSaveWorks() throws {
        let app = XCUIApplication()
        app.launch()

        let schedulesTab = app.tabBars.buttons["Schedules"]
        XCTAssertTrue(schedulesTab.waitForExistence(timeout: 10), "Schedules tab missing")
        Thread.sleep(forTimeInterval: 3)

        schedulesTab.tap()
        Thread.sleep(forTimeInterval: 1)
        schedulesTab.tap() // ensure we landed on Schedules past the splash

        // "Add Schedule" is the last row; scroll until it's realized.
        let addSchedule = app.buttons["add-schedule"]
        var tries = 0
        while !addSchedule.exists && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(addSchedule.waitForExistence(timeout: 4), "Add Schedule button missing")
        addSchedule.tap()

        let titleField = app.textFields["schedule-title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field missing")

        let save = app.buttons["schedule-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 2), "Save button missing")
        // The fix: Save must be tappable WITHOUT typing a title (days are pre-set).
        XCTAssertTrue(save.isEnabled, "Schedule Save is DISABLED before any input (title should be optional)")

        titleField.tap()
        titleField.typeText("UITestFocus")
        save.tap()

        XCTAssertTrue(titleField.waitForNonExistence(timeout: 4),
                      "Schedule editor did NOT dismiss after Save")
        XCTAssertTrue(app.staticTexts["UITestFocus"].waitForExistence(timeout: 5),
                      "New schedule did not appear after Save")
    }

    @MainActor
    func testScheduleToggleWorks() throws {
        let app = XCUIApplication()
        app.launch()

        let schedulesTab = app.tabBars.buttons["Schedules"]
        XCTAssertTrue(schedulesTab.waitForExistence(timeout: 10), "Schedules tab missing")
        Thread.sleep(forTimeInterval: 3)
        schedulesTab.tap()
        Thread.sleep(forTimeInterval: 1)
        schedulesTab.tap()

        let toggle = app.switches["schedule-toggle"].firstMatch
        if !toggle.waitForExistence(timeout: 4) {
            let add = app.buttons["add-schedule"]
            var t = 0
            while !add.exists && t < 6 { app.swipeUp(); t += 1 }
            if add.exists { add.tap(); app.buttons["schedule-save"].tap(); Thread.sleep(forTimeInterval: 1) }
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 4), "No schedule toggle found")

        var scrolls = 0
        while !toggle.isHittable && scrolls < 6 { app.swipeUp(); scrolls += 1 }
        XCTAssertTrue(toggle.isHittable, "Schedule toggle is not hittable on screen")

        let before = (toggle.value as? String) ?? ""
        toggle.tap()
        Thread.sleep(forTimeInterval: 1)
        let after = (app.switches["schedule-toggle"].firstMatch.value as? String) ?? ""
        XCTAssertNotEqual(after, before,
                          "Schedule toggle did not change state when tapped (before=\(before), after=\(after))")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
