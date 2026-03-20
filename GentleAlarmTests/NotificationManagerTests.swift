//
//  NotificationManagerTests.swift
//  GentleAlarmTests
//
// TESTING BOUNDARY NOTE
// ─────────────────────
// UNNotificationResponse and UNNotification have no public initializers, so the
// full delegate dispatch (didReceive response:) cannot be unit-tested without
// spinning up a UNUserNotificationCenter mock that requires a host app entitlement.
// The callback wiring (onSnooze / onDismiss) is instead verified at the
// AlarmManager level via SpyNotificationScheduler in AlarmManagerTests.swift.
//
// What IS testable here:
//   • NotificationManager.shared initializes without crashing.
//   • onSnooze and onDismiss accept (and can be cleared) without crashing.
//   • Delegate conformance.
//   • scheduleNotification(for:at:) and cancelAllNotifications() smoke tests.

import Testing
import UserNotifications
@testable import GentleAlarm

struct NotificationManagerTests {

    // MARK: - Smoke tests

    @Test func testSharedInitializesWithoutCrash() {
        _ = NotificationManager.shared
    }

    @Test func testClosurePropertiesAcceptAndClearWithoutCrash() {
        let manager = NotificationManager.shared
        manager.onSnooze  = { }
        manager.onDismiss = { }
        manager.onSnooze  = nil
        manager.onDismiss = nil
    }

    // MARK: - Delegate conformance

    // UNNotification cannot be constructed in unit tests (no public init), so the
    // willPresent and didReceive paths cannot be exercised directly. Coverage of
    // those paths is deferred to UI / integration tests.
    //
    // What we CAN assert: the manager conforms to UNUserNotificationCenterDelegate.
    @Test func testConformsToUNUserNotificationCenterDelegate() {
        let manager = NotificationManager.shared
        #expect(manager is UNUserNotificationCenterDelegate)
    }

    // MARK: - Scheduling / cancellation smoke tests

    @Test func testRealScheduleNotificationDoesNotCrash() {
        let manager = NotificationManager.shared
        let alarm = Alarm(hour: 8, minute: 0)
        // Scheduling may silently fail without notification permission (the error
        // is only printed); the call must not throw or crash.
        manager.scheduleNotification(for: alarm, at: Date().addingTimeInterval(60))
        // Paired cancel so this doesn't pollute the notification centre.
        manager.cancelAllNotifications()
    }

    @Test func testCancelAllNotificationsDoesNotCrash() {
        let manager = NotificationManager.shared
        let alarm = Alarm(hour: 8, minute: 0)
        manager.scheduleNotification(for: alarm, at: Date().addingTimeInterval(120))
        manager.cancelAllNotifications()  // must not crash; clears the request we just added
    }
}
