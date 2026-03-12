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
}
