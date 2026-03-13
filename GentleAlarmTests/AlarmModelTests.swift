//
//  AlarmModelTests.swift
//  GentleAlarmTests
//

import Foundation
import Testing
@testable import GentleAlarm

struct AlarmModelTests {

    // MARK: - timeString

    @Test func testTimeStringLeadingZero() {
        let alarm = Alarm(hour: 7, minute: 5)
        #expect(alarm.timeString == "07:05")
    }

    @Test func testTimeStringNoon() {
        let alarm = Alarm(hour: 12, minute: 0)
        #expect(alarm.timeString == "12:00")
    }

    // MARK: - subtitle

    @Test func testSubtitleOneTime() {
        let alarm = Alarm(hour: 7, minute: 0)
        #expect(alarm.subtitle.hasPrefix("Once"))
    }

    @Test func testSubtitleWeekdays() {
        let alarm = Alarm(hour: 7, minute: 0)
        alarm.repeatDays = .weekdays
        #expect(alarm.subtitle.hasPrefix("Weekdays"))
    }

    @Test func testSubtitleIncludesSoundName() {
        let alarm = Alarm(hour: 7, minute: 0)
        #expect(alarm.subtitle.contains(alarm.sound.displayName))
    }

    // MARK: - nextFireDate

    @Test func testNextFireDateDisabledReturnsNil() {
        let alarm = Alarm(hour: 7, minute: 0)
        alarm.isEnabled = false
        #expect(alarm.nextFireDate() == nil)
    }

    /// Alarm at 9 AM, reference at 8 AM → fires today.
    @Test func testNextFireDateOneTimeFuture() {
        var refComps = DateComponents()
        refComps.year = 2026; refComps.month = 3; refComps.day = 9
        refComps.hour = 8; refComps.minute = 0; refComps.second = 0
        let reference = Calendar.current.date(from: refComps)!

        let alarm = Alarm(hour: 9, minute: 0)
        let result = alarm.nextFireDate(after: reference)

        var expComps = refComps
        expComps.hour = 9
        let expected = Calendar.current.date(from: expComps)!

        #expect(result == expected)
    }

    /// Alarm at 8 AM, reference at 10 AM → fires tomorrow.
    @Test func testNextFireDateOneTimePast() {
        var refComps = DateComponents()
        refComps.year = 2026; refComps.month = 3; refComps.day = 9
        refComps.hour = 10; refComps.minute = 0; refComps.second = 0
        let reference = Calendar.current.date(from: refComps)!

        let alarm = Alarm(hour: 8, minute: 0)
        let result = alarm.nextFireDate(after: reference)

        var expComps = DateComponents()
        expComps.year = 2026; expComps.month = 3; expComps.day = 10
        expComps.hour = 8; expComps.minute = 0; expComps.second = 0
        let expected = Calendar.current.date(from: expComps)!

        #expect(result == expected)
    }

    @Test func testNextFireDateRepeatingDelegates() {
        var refComps = DateComponents()
        refComps.year = 2026; refComps.month = 3; refComps.day = 9
        refComps.hour = 8; refComps.minute = 0; refComps.second = 0
        let reference = Calendar.current.date(from: refComps)!

        let alarm = Alarm(hour: 9, minute: 0)
        alarm.repeatDays = .weekdays

        let fromAlarm = alarm.nextFireDate(after: reference)
        let fromRepeatDays = alarm.repeatDays.nextFireDate(after: reference, hour: 9, minute: 0)

        #expect(fromAlarm == fromRepeatDays)
    }

    // MARK: - Sound resolution

    @Test func testSoundResolutionKnown() {
        let alarm = Alarm(hour: 7, minute: 0)
        alarm.soundName = "Possibility"
        #expect(alarm.sound == .possibility)
    }

    @Test func testSoundResolutionUnknown() {
        let alarm = Alarm(hour: 7, minute: 0)
        alarm.soundName = "DoesNotExist"
        #expect(alarm.sound == .possibility)
    }

    // MARK: - repeatDays round-trip

    @Test func testRepeatDaysRoundTrip() {
        let alarm = Alarm(hour: 7, minute: 0)
        alarm.repeatDays = .weekdays
        #expect(alarm.repeatDays == .weekdays)
    }

    // MARK: - 12-hour display

    @Test func testHour12Midnight() {
        let alarm = Alarm(hour: 0, minute: 0)
        let hour12 = alarm.hour % 12 == 0 ? 12 : alarm.hour % 12
        #expect(hour12 == 12)
        #expect("\(hour12):\(String(format: "%02d", alarm.minute))" == "12:00")
    }

    @Test func testHour12Noon() {
        let alarm = Alarm(hour: 12, minute: 0)
        let hour12 = alarm.hour % 12 == 0 ? 12 : alarm.hour % 12
        #expect(hour12 == 12)
        #expect("\(hour12):\(String(format: "%02d", alarm.minute))" == "12:00")
    }

    @Test func testHour12Afternoon() {
        let alarm = Alarm(hour: 13, minute: 5)
        let hour12 = alarm.hour % 12 == 0 ? 12 : alarm.hour % 12
        #expect(hour12 == 1)
        #expect("\(hour12):\(String(format: "%02d", alarm.minute))" == "1:05")
    }

    @Test func testHour12MinutePadding() {
        let alarm = Alarm(hour: 9, minute: 3)
        let hour12 = alarm.hour % 12 == 0 ? 12 : alarm.hour % 12
        #expect(hour12 == 9)
        #expect("\(hour12):\(String(format: "%02d", alarm.minute))" == "9:03")
    }
}
