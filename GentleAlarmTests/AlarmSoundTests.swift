//
//  AlarmSoundTests.swift
//  GentleAlarmTests
//

import Foundation
import Testing
@testable import GentleAlarm

struct AlarmSoundTests {

    @Test func testFilename() {
        #expect(AlarmSound.possibility.filename == "Possibility.caf")
    }

    @Test func testDisplayName() {
        #expect(AlarmSound.possibility.displayName == "Possibility")
    }

    @Test func testRawValueRoundTrip() {
        #expect(AlarmSound(rawValue: "Possibility") == .possibility)
    }

    @Test func testUnknownRawValueNil() {
        #expect(AlarmSound(rawValue: "NotReal") == nil)
    }

    @Test func testCaseIterableNonEmpty() {
        #expect(!AlarmSound.allCases.isEmpty)
    }

    @Test func testIdEqualsRawValue() {
        #expect(AlarmSound.possibility.id == AlarmSound.possibility.rawValue)
    }
}
