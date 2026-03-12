//
//  GentleAlarmUITests.swift
//  GentleAlarmUITests
//

import XCTest

final class GentleAlarmUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch

    @MainActor
    func testLaunchShowsAlarmsTitle() throws {
        XCTAssertTrue(app.navigationBars["Alarms"].exists)
    }

    // MARK: - Add alarm

    @MainActor
    func testAddAlarmAppearsInList() throws {
        let initialCount = app.cells.count
        app.buttons["addAlarmButton"].tap()
        app.buttons["saveAlarmButton"].tap()
        XCTAssertEqual(app.cells.count, initialCount + 1)
    }

    @MainActor
    func testCancelAddDoesNotCreateAlarm() throws {
        let initialCount = app.cells.count
        app.buttons["addAlarmButton"].tap()
        app.buttons["cancelAlarmButton"].tap()
        XCTAssertEqual(app.cells.count, initialCount)
    }

    // MARK: - Delete alarm

    @MainActor
    func testDeleteAlarm() throws {
        // Add an alarm first
        app.buttons["addAlarmButton"].tap()
        app.buttons["saveAlarmButton"].tap()

        let cell = app.cells.firstMatch
        cell.swipeLeft()
        app.buttons["Delete"].tap()

        XCTAssertEqual(app.cells.count, 0)
    }

    // MARK: - Toggle

    @MainActor
    func testToggleDisablesAlarm() throws {
        app.buttons["addAlarmButton"].tap()
        app.buttons["saveAlarmButton"].tap()

        let toggle = app.switches.firstMatch
        let initialValue = toggle.value as? String
        toggle.tap()
        let newValue = toggle.value as? String

        XCTAssertNotEqual(initialValue, newValue)
    }

    // MARK: - Edit alarm

    @MainActor
    func testEditAlarmLabel() throws {
        // Add an alarm
        app.buttons["addAlarmButton"].tap()
        app.buttons["saveAlarmButton"].tap()

        // Tap the alarm row to open the edit sheet
        // Tap in the leading portion of the cell (away from the toggle switch on the right)
        let cell = app.cells.firstMatch
        let leadingPoint = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        leadingPoint.tap()

        // Change the label
        let labelField = app.textFields["alarmLabelField"]
        XCTAssertTrue(labelField.waitForExistence(timeout: 2))
        labelField.tap()
        labelField.clearAndTypeText("Morning Run")

        app.buttons["saveAlarmButton"].tap()

        // Verify label appears in the row subtitle
        XCTAssertTrue(app.staticTexts["Morning Run"].waitForExistence(timeout: 2))
    }

    // MARK: - Navigation to sub-screens

    @MainActor
    func testSoundPickerNavigates() throws {
        app.buttons["addAlarmButton"].tap()
        // Tap the Sound row in the form (NavigationLink row)
        let soundRow = app.cells.staticTexts["Sound"].firstMatch
        XCTAssertTrue(soundRow.waitForExistence(timeout: 2))
        soundRow.tap()
        XCTAssertTrue(app.navigationBars["Sound"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testRampPickerNavigates() throws {
        app.buttons["addAlarmButton"].tap()
        // Tap the Ramp Duration row in the form (NavigationLink row)
        let rampRow = app.cells.staticTexts["Ramp Duration"].firstMatch
        XCTAssertTrue(rampRow.waitForExistence(timeout: 2))
        rampRow.tap()
        // RampPickerView shows duration options — "1 minute" is the default (60 s)
        XCTAssertTrue(app.staticTexts["1 minute"].waitForExistence(timeout: 2))
    }

    // MARK: - Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

// MARK: - XCUIElement helper

extension XCUIElement {
    /// Clears the current text and types new text.
    func clearAndTypeText(_ text: String) {
        guard let currentValue = self.value as? String else {
            typeText(text)
            return
        }
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        typeText(deleteString)
        typeText(text)
    }
}
