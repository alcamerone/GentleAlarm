//
//  RepeatDaysTests.swift
//  GentleAlarmTests
//

import Foundation
import Testing
@testable import GentleAlarm

struct RepeatDaysTests {

    // MARK: - displayText

    @Test func testDisplayTextEveryDay() {
        #expect(RepeatDays.all.displayText == "Every day")
    }

    @Test func testDisplayTextWeekdays() {
        #expect(RepeatDays.weekdays.displayText == "Weekdays")
    }

    @Test func testDisplayTextWeekend() {
        #expect(RepeatDays.weekend.displayText == "Weekends")
    }

    @Test func testDisplayTextNever() {
        #expect(RepeatDays([]).displayText == "Never")
    }

    @Test func testDisplayTextCustomDays() {
        let days: RepeatDays = [.monday, .wednesday, .friday]
        #expect(days.displayText == "Mon, Wed, Fri")
    }

    // MARK: - nextFireDate

    /// March 9 2026 is a Monday. Alarm at 9 AM with an 8 AM reference → returns today.
    @Test func testNextFireDateFutureToday() {
        var refComps = DateComponents()
        refComps.year = 2026; refComps.month = 3; refComps.day = 9
        refComps.hour = 8; refComps.minute = 0; refComps.second = 0
        let reference = Calendar.current.date(from: refComps)!

        let result = RepeatDays([.monday]).nextFireDate(after: reference, hour: 9, minute: 0)

        var expComps = refComps
        expComps.hour = 9
        let expected = Calendar.current.date(from: expComps)!

        #expect(result == expected)
    }

    /// March 9 2026 is a Monday. Alarm at 8 AM with a 10 AM reference → skips to next Monday.
    @Test func testNextFireDatePastToday() {
        var refComps = DateComponents()
        refComps.year = 2026; refComps.month = 3; refComps.day = 9
        refComps.hour = 10; refComps.minute = 0; refComps.second = 0
        let reference = Calendar.current.date(from: refComps)!

        let result = RepeatDays([.monday]).nextFireDate(after: reference, hour: 8, minute: 0)

        var expComps = DateComponents()
        expComps.year = 2026; expComps.month = 3; expComps.day = 16
        expComps.hour = 8; expComps.minute = 0; expComps.second = 0
        let expected = Calendar.current.date(from: expComps)!

        #expect(result == expected)
    }

    /// Weekdays set, reference is Monday 10 AM, alarm at 8 AM → next available is Tuesday.
    @Test func testNextFireDateNextAvailableDay() {
        var refComps = DateComponents()
        refComps.year = 2026; refComps.month = 3; refComps.day = 9
        refComps.hour = 10; refComps.minute = 0; refComps.second = 0
        let reference = Calendar.current.date(from: refComps)!

        let result = RepeatDays.weekdays.nextFireDate(after: reference, hour: 8, minute: 0)

        var expComps = DateComponents()
        expComps.year = 2026; expComps.month = 3; expComps.day = 10
        expComps.hour = 8; expComps.minute = 0; expComps.second = 0
        let expected = Calendar.current.date(from: expComps)!

        #expect(result == expected)
    }

    @Test func testNextFireDateEmptyReturnsNil() {
        #expect(RepeatDays([]).nextFireDate(after: Date(), hour: 8, minute: 0) == nil)
    }

    @Test func testNextFireDateWithinEightDays() {
        let reference = Date()
        let eightDaysLater = Calendar.current.date(byAdding: .day, value: 8, to: reference)!
        let result = RepeatDays([.monday]).nextFireDate(after: reference, hour: 0, minute: 0)
        #expect(result != nil)
        #expect(result! <= eightDaysLater)
    }

    // MARK: - OptionSet operations

    @Test func testOptionSetContains() {
        #expect(RepeatDays.weekdays.contains(.monday))
        #expect(!RepeatDays.weekdays.contains(.sunday))
    }

    @Test func testOptionSetUnion() {
        let combined = RepeatDays.weekdays.union(.weekend)
        #expect(combined == .all)
    }
}
