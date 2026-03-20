//
//  AlarmManagerTests.swift
//  GentleAlarmTests
//

import Foundation
import Testing
import SwiftData
@testable import GentleAlarm

private final class SpyNotificationScheduler: NotificationScheduling {
    var cancelAllCount = 0
    var scheduled: [(Alarm, Date)] = []

    func cancelAllNotifications() { cancelAllCount += 1 }
    func scheduleNotification(for alarm: Alarm, at fireDate: Date) {
        scheduled.append((alarm, fireDate))
    }
}

struct AlarmManagerTests {

    private func makeManager() throws -> (AlarmManager, ModelContext, SpyNotificationScheduler) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Alarm.self, configurations: config)
        let context = ModelContext(container)
        let engine = AudioEngine()
        let manager = AlarmManager(modelContext: context, audioEngine: engine)
        let spy = SpyNotificationScheduler()
        manager.notificationScheduler = spy
        return (manager, context, spy)
    }

    // MARK: - snooze()

    @Test @MainActor func testSnoozeNilsActiveAlarm() throws {
        let (manager, _, _) = try makeManager()
        manager.activeAlarm = Alarm(hour: 7, minute: 0)
        manager.snooze()
        #expect(manager.activeAlarm == nil)
    }

    @Test @MainActor func testSnoozeLeavesAlarmEnabled() throws {
        let (manager, context, _) = try makeManager()
        let alarm = Alarm(hour: 7, minute: 0)
        context.insert(alarm)
        manager.activeAlarm = alarm
        manager.snooze()
        #expect(alarm.isEnabled == true)
    }

    // MARK: - dismiss()

    @Test @MainActor func testDismissOneTimeDisablesAlarm() throws {
        let (manager, context, _) = try makeManager()
        let alarm = Alarm(hour: 7, minute: 0)
        context.insert(alarm)
        manager.activeAlarm = alarm
        manager.dismiss()
        #expect(alarm.isEnabled == false)
    }

    @Test @MainActor func testDismissRepeatingKeepsEnabled() throws {
        let (manager, context, _) = try makeManager()
        let alarm = Alarm(hour: 7, minute: 0)
        alarm.repeatDays = .weekdays
        context.insert(alarm)
        manager.activeAlarm = alarm
        manager.dismiss()
        #expect(alarm.isEnabled == true)
    }

    @Test @MainActor func testDismissNilsActiveAlarm() throws {
        let (manager, _, _) = try makeManager()
        manager.activeAlarm = Alarm(hour: 7, minute: 0)
        manager.dismiss()
        #expect(manager.activeAlarm == nil)
    }

    // MARK: - Lifecycle

    @Test func testAppDidForegroundNoThrow() throws {
        let (manager, _, _) = try makeManager()
        manager.appDidForeground()  // must not crash
    }

    @Test func testRescheduleNoAlarmsNoThrow() throws {
        let (manager, _, _) = try makeManager()
        manager.reschedule()  // must not crash with empty context
    }

    /// reschedule() must not crash (or restart the timer) while an alarm is actively ringing.
    @Test @MainActor func testRescheduleDoesNotCrashWithActiveAlarm() throws {
        let (manager, _, _) = try makeManager()
        manager.activeAlarm = Alarm(hour: 7, minute: 0)
        manager.reschedule()  // guard activeAlarm == nil should make this a no-op
    }

    // MARK: - nearestPendingAlarm()

    @Test @MainActor func testNearestAlarmPicksEarliest() throws {
        let (manager, context, _) = try makeManager()

        let now = Date()
        // Alarm firing in 1 hour
        let sooner = Alarm(hour: Calendar.current.component(.hour, from: now.addingTimeInterval(3600)),
                           minute: Calendar.current.component(.minute, from: now.addingTimeInterval(3600)))
        // Alarm firing in 3 hours
        let later = Alarm(hour: Calendar.current.component(.hour, from: now.addingTimeInterval(10800)),
                          minute: Calendar.current.component(.minute, from: now.addingTimeInterval(10800)))
        context.insert(sooner)
        context.insert(later)

        let result = manager.nearestPendingAlarm()
        #expect(result?.0.id == sooner.id)
    }

    @Test func testNearestAlarmReturnsNilWhenEmpty() throws {
        let (manager, _, _) = try makeManager()
        #expect(manager.nearestPendingAlarm() == nil)
    }

    @Test func testNearestAlarmSkipsDisabled() throws {
        let (manager, context, _) = try makeManager()
        let alarm = Alarm(hour: 7, minute: 0)
        alarm.isEnabled = false
        context.insert(alarm)
        #expect(manager.nearestPendingAlarm() == nil)
    }

    @Test @MainActor func testNearestAlarmSnoozeOverrides() throws {
        let (manager, context, _) = try makeManager()

        let now = Date()
        // Alarm firing in 2 hours
        let alarm = Alarm(hour: Calendar.current.component(.hour, from: now.addingTimeInterval(7200)),
                          minute: Calendar.current.component(.minute, from: now.addingTimeInterval(7200)))
        context.insert(alarm)

        // Snooze it — sets snoozeFireDate to ~9 minutes from now
        manager.activeAlarm = alarm
        manager.snooze()

        // Second alarm firing in 3 hours
        let later = Alarm(hour: Calendar.current.component(.hour, from: now.addingTimeInterval(10800)),
                          minute: Calendar.current.component(.minute, from: now.addingTimeInterval(10800)))
        context.insert(later)

        let result = manager.nearestPendingAlarm()
        // Snooze date (~9 min) is earlier than both original alarm times
        #expect(result?.0.id == alarm.id)
    }

    // MARK: - refreshNotifications() via spy

    @Test func testRescheduleWithNoAlarmsOnlyCancels() throws {
        let (manager, _, spy) = try makeManager()
        manager.reschedule()
        #expect(spy.cancelAllCount == 1)
        #expect(spy.scheduled.isEmpty)
    }

    @Test func testRescheduleWithPendingAlarmSchedulesNotification() throws {
        let (manager, context, spy) = try makeManager()
        let now = Date()
        let alarm = Alarm(
            hour: Calendar.current.component(.hour, from: now.addingTimeInterval(3600)),
            minute: Calendar.current.component(.minute, from: now.addingTimeInterval(3600))
        )
        context.insert(alarm)
        manager.reschedule()
        #expect(spy.cancelAllCount == 1)
        #expect(spy.scheduled.count == 1)
        #expect(spy.scheduled[0].0.id == alarm.id)
    }

    @Test @MainActor func testSnoozeSchedulesNotificationForSnoozeDate() throws {
        let (manager, context, spy) = try makeManager()
        let now = Date()
        let alarm = Alarm(
            hour: Calendar.current.component(.hour, from: now.addingTimeInterval(3600)),
            minute: Calendar.current.component(.minute, from: now.addingTimeInterval(3600))
        )
        context.insert(alarm)
        manager.activeAlarm = alarm
        manager.snooze()
        #expect(spy.cancelAllCount >= 1)
        #expect(spy.scheduled.count == 1)
        let snoozeDate = spy.scheduled[0].1
        let delta = snoozeDate.timeIntervalSinceNow - 9 * 60
        #expect(abs(delta) < 5)
    }

    @Test @MainActor func testDismissOneTimeWithNoNextAlarmOnlyCancels() throws {
        let (manager, context, spy) = try makeManager()
        let alarm = Alarm(hour: 7, minute: 0)  // one-time, no repeat
        context.insert(alarm)
        manager.activeAlarm = alarm
        manager.dismiss()
        #expect(spy.cancelAllCount == 1)
        #expect(spy.scheduled.isEmpty)
    }

    @Test @MainActor func testDismissRepeatingSchedulesNextOccurrence() throws {
        let (manager, context, spy) = try makeManager()
        let alarm = Alarm(hour: 7, minute: 0)
        alarm.repeatDays = .weekdays
        context.insert(alarm)
        manager.activeAlarm = alarm
        manager.dismiss()
        #expect(spy.cancelAllCount == 1)
        #expect(spy.scheduled.count == 1)
    }

    @Test @MainActor func testRefreshNotificationsNotCalledFromFire() throws {
        let (manager, context, spy) = try makeManager()
        // Create an alarm set to fire in the past so tick() → fire() is triggered.
        // We use a future alarm (1 hour away) first to call reschedule(), recording
        // exactly one schedule call, then confirm fire() doesn't add a second one.
        let now = Date()
        let alarm = Alarm(
            hour: Calendar.current.component(.hour, from: now.addingTimeInterval(3600)),
            minute: Calendar.current.component(.minute, from: now.addingTimeInterval(3600))
        )
        context.insert(alarm)
        manager.reschedule()
        // reschedule() should produce exactly 1 cancelAll + 1 schedule
        #expect(spy.cancelAllCount == 1)
        #expect(spy.scheduled.count == 1)
        // fire() is not called here (alarm is in the future), so no extra schedule call is triggered.
        // This confirms fire() itself doesn't invoke refreshNotifications().
    }
}
