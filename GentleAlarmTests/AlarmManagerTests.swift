//
//  AlarmManagerTests.swift
//  GentleAlarmTests
//

import Foundation
import Testing
import SwiftData
@testable import GentleAlarm

struct AlarmManagerTests {

    private func makeManager() throws -> (AlarmManager, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Alarm.self, configurations: config)
        let context = ModelContext(container)
        let engine = AudioEngine()
        let manager = AlarmManager(modelContext: context, audioEngine: engine)
        return (manager, context)
    }

    // MARK: - snooze()

    @Test @MainActor func testSnoozeNilsActiveAlarm() throws {
        let (manager, _) = try makeManager()
        manager.activeAlarm = Alarm(hour: 7, minute: 0)
        manager.snooze()
        #expect(manager.activeAlarm == nil)
    }

    @Test @MainActor func testSnoozeLeavesAlarmEnabled() throws {
        let (manager, context) = try makeManager()
        let alarm = Alarm(hour: 7, minute: 0)
        context.insert(alarm)
        manager.activeAlarm = alarm
        manager.snooze()
        #expect(alarm.isEnabled == true)
    }

    // MARK: - dismiss()

    @Test @MainActor func testDismissOneTimeDisablesAlarm() throws {
        let (manager, context) = try makeManager()
        let alarm = Alarm(hour: 7, minute: 0)
        context.insert(alarm)
        manager.activeAlarm = alarm
        manager.dismiss()
        #expect(alarm.isEnabled == false)
    }

    @Test @MainActor func testDismissRepeatingKeepsEnabled() throws {
        let (manager, context) = try makeManager()
        let alarm = Alarm(hour: 7, minute: 0)
        alarm.repeatDays = .weekdays
        context.insert(alarm)
        manager.activeAlarm = alarm
        manager.dismiss()
        #expect(alarm.isEnabled == true)
    }

    @Test @MainActor func testDismissNilsActiveAlarm() throws {
        let (manager, _) = try makeManager()
        manager.activeAlarm = Alarm(hour: 7, minute: 0)
        manager.dismiss()
        #expect(manager.activeAlarm == nil)
    }

    // MARK: - Lifecycle

    @Test func testAppDidForegroundNoThrow() throws {
        let (manager, _) = try makeManager()
        manager.appDidForeground()  // must not crash
    }

    @Test func testRescheduleNoAlarmsNoThrow() throws {
        let (manager, _) = try makeManager()
        manager.reschedule()  // must not crash with empty context
    }

    /// reschedule() must not crash (or restart the timer) while an alarm is actively ringing.
    @Test @MainActor func testRescheduleDoesNotCrashWithActiveAlarm() throws {
        let (manager, _) = try makeManager()
        manager.activeAlarm = Alarm(hour: 7, minute: 0)
        manager.reschedule()  // guard activeAlarm == nil should make this a no-op
    }

    // MARK: - nearestPendingAlarm()

    @Test @MainActor func testNearestAlarmPicksEarliest() throws {
        let (manager, context) = try makeManager()

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
        let (manager, _) = try makeManager()
        #expect(manager.nearestPendingAlarm() == nil)
    }

    @Test func testNearestAlarmSkipsDisabled() throws {
        let (manager, context) = try makeManager()
        let alarm = Alarm(hour: 7, minute: 0)
        alarm.isEnabled = false
        context.insert(alarm)
        #expect(manager.nearestPendingAlarm() == nil)
    }

    @Test @MainActor func testNearestAlarmSnoozeOverrides() throws {
        let (manager, context) = try makeManager()

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
}
