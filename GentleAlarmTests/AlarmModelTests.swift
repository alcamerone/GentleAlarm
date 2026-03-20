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

    /// Alarm marked as hasFired → nextFireDate must return nil (prevents re-fire on relaunch).
    @Test func testNextFireDateReturnsNilWhenHasFired() {
        let alarm = Alarm(hour: 8, minute: 0)
        alarm.isEnabled = true
        alarm.hasFired = true
        #expect(alarm.nextFireDate() == nil)
    }

    /// When oneTimeFire is set, nextFireDate must return that exact date.
    @Test func testNextFireDateReturnsOneTimeFire() {
        let alarm = Alarm(hour: 8, minute: 0)
        alarm.isEnabled = true
        let explicitDate = Date().addingTimeInterval(3600)
        alarm.oneTimeFire = explicitDate
        #expect(alarm.nextFireDate() == explicitDate)
    }

    /// oneTimeFire is in the past but hasFired is false (e.g. app killed before AlarmManager
    /// could persist the flag). nextFireDate must return that past date so the manager can
    /// fire the alarm immediately on relaunch.
    @Test func testNextFireDateReturnsPastOneTimeFireWhenNotYetFired() {
        let alarm = Alarm(hour: 6, minute: 0)
        alarm.isEnabled = true
        alarm.hasFired = false
        let past = Date().addingTimeInterval(-7200)
        alarm.oneTimeFire = past
        #expect(alarm.nextFireDate() == past)
    }

    /// When fire time == reference exactly, the alarm fires now (not tomorrow).
    /// This validates the `>=` fix (previously `>`).
    @Test func testNextFireDateExactReferenceReturnsToday() {
        var refComps = DateComponents()
        refComps.year = 2026; refComps.month = 3; refComps.day = 18
        refComps.hour = 8; refComps.minute = 0; refComps.second = 0
        let reference = Calendar.current.date(from: refComps)!

        let alarm = Alarm(hour: 8, minute: 0)
        #expect(alarm.nextFireDate(after: reference) == reference)
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

    // MARK: - refreshOneTimeFire

    /// For a repeating alarm, refreshOneTimeFire must not reset hasFired or set oneTimeFire.
    @Test func testRefreshOneTimeFireIsNoOpForRepeatingAlarm() {
        let alarm = Alarm(hour: 9, minute: 0)
        alarm.hasFired = true
        alarm.repeatDays = .weekdays
        alarm.refreshOneTimeFire()
        #expect(alarm.hasFired == true)
        #expect(alarm.oneTimeFire == nil)
    }

    /// For a one-time alarm whose hour:minute hasn't passed today, oneTimeFire is set to today.
    @Test func testRefreshOneTimeFireSetsTodayWhenTimeHasNotPassed() {
        // 23:59 is almost always in the future relative to now.
        let alarm = Alarm(hour: 23, minute: 59)
        alarm.hasFired = true
        alarm.refreshOneTimeFire()
        #expect(alarm.hasFired == false)
        let result = alarm.oneTimeFire
        #expect(result != nil)
        let calendar = Calendar.current
        #expect(calendar.component(.hour, from: result!) == 23)
        #expect(calendar.component(.minute, from: result!) == 59)
        #expect(calendar.isDateInToday(result!))
    }

    /// For a one-time alarm whose hour:minute has already passed today, oneTimeFire is set to tomorrow.
    @Test func testRefreshOneTimeFireSetsTomorrowWhenTimeHasPassed() {
        // 00:00 midnight is always in the past.
        let alarm = Alarm(hour: 0, minute: 0)
        alarm.hasFired = true
        alarm.refreshOneTimeFire()
        #expect(alarm.hasFired == false)
        let result = alarm.oneTimeFire
        #expect(result != nil)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        #expect(calendar.isDate(result!, inSameDayAs: tomorrow))
    }

    /// After refreshOneTimeFire() on a fired alarm, nextFireDate() must return a future date.
    @Test func testRefreshOneTimeFireMakesNextFireDateFuture() {
        let alarm = Alarm(hour: 23, minute: 59)
        alarm.isEnabled = true
        alarm.hasFired = true
        alarm.oneTimeFire = Date().addingTimeInterval(-86400) // yesterday

        alarm.refreshOneTimeFire()

        let next = alarm.nextFireDate()
        #expect(next != nil)
        #expect(next! > Date())
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
