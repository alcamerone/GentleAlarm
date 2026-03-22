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
        app.launchArguments = ["UITesting"]  // use in-memory SwiftData store; isolates each test
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
        addAlarm()

        // The sheet dismisses and the list animates asynchronously — wait for the
        // cell count to increase before asserting (mirrors the pattern in testDeleteAlarm).
        let oneAdded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == \(initialCount + 1)"),
            object: app.cells
        )
        XCTWaiter().wait(for: [oneAdded], timeout: 5)
        XCTAssertEqual(app.cells.count, initialCount + 1)
    }

    @MainActor
    func testCancelAddDoesNotCreateAlarm() throws {
        let initialCount = app.cells.count
        app.buttons["addAlarmButton"].tap()
        app.buttons["cancelAlarmButton"].tap()

        // Wait for the sheet to finish dismissing before asserting.
        // On slow CI devices the sheet animation is asynchronous.
        let sheetGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == \(initialCount)"),
            object: app.cells
        )
        XCTWaiter().wait(for: [sheetGone], timeout: 5)
        XCTAssertEqual(app.cells.count, initialCount)
    }

    // MARK: - Delete alarm

    @MainActor
    func testDeleteAlarm() throws {
        addAlarm()

        let alarmCell = firstAlarmCell()
        XCTAssertTrue(alarmCell.waitForExistence(timeout: 2))
        let countBeforeDelete = app.cells.count

        // swipeLeft() reveals the trailing swipe-action buttons.
        alarmCell.swipeLeft()

        // Tap the Delete button that appears after the swipe.
        let deleteButton = app.buttons["deleteAlarmButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()


        // SwiftUI's list deletion runs a UICollectionView animation; wait for the cell
        // count to drop by one before asserting.
        let oneRemoved = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == \(countBeforeDelete - 1)"),
            object: app.cells
        )
        XCTWaiter().wait(for: [oneRemoved], timeout: 5)
        XCTAssertEqual(app.cells.count, countBeforeDelete - 1)
    }

    // MARK: - Toggle

    @MainActor
    func testToggleDisablesAlarm() throws {
        addAlarm()

        // Wait for the new alarm cell (and its toggle) to appear before interacting.
        let toggle = app.switches.firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let initialValue = toggle.value as? String
        toggle.tap()
        let newValue = toggle.value as? String

        XCTAssertNotEqual(initialValue, newValue)
    }

    // MARK: - Edit alarm

    @MainActor
    func testEditAlarmLabel() throws {
        addAlarm()

        // Tap the alarm row's edit button to open the edit sheet.
        let editButton = app.buttons["editAlarmCell"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 2))
        editButton.tap()

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

// MARK: - Helpers

extension GentleAlarmUITests {
    /// Adds a default alarm via the add sheet and waits for it to appear in the list.
    private func addAlarm() {
        app.buttons["addAlarmButton"].tap()
        app.buttons["saveAlarmButton"].tap()
    }

    /// Returns the first alarm list cell (identified by its contained edit button).
    private func firstAlarmCell() -> XCUIElement {
        app.cells.containing(.button, identifier: "editAlarmCell").firstMatch
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
