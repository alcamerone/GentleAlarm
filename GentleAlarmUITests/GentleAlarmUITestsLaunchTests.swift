//
//  GentleAlarmUITestsLaunchTests.swift
//  GentleAlarmUITests
//
//  Created by Cameron Ekblad on 04/03/2026.
//

import XCTest

final class GentleAlarmUITestsLaunchTests: XCTestCase {

    // false: GentleAlarm has no configuration-varying assets or logic (no custom dark-mode
    // colours, no Dynamic Type layouts under test), so running once per UI configuration
    // (light + dark) produces identical screenshots. Disabled to halve launch-test time.
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
