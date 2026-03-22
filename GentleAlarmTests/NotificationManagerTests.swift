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
//   • scheduleNotification(for:at:) content — identifier, interruption level,
//     sound attachment — verified via SpyUNCenter injection.
//   • cancelAllNotifications() delegation to the underlying center.

import Testing
import UserNotifications
@testable import GentleAlarm

// MARK: - Spy

private final class SpyUNCenter: UNUserNotificationCenterProtocol {
    var addedRequests: [UNNotificationRequest] = []
    var removedAllCount = 0

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        addedRequests.append(request)
        completionHandler?(nil)
    }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
    func removeAllPendingNotificationRequests() { removedAllCount += 1 }
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {}
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void) {}
}

// MARK: - Tests

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

    // Verify NotificationScheduling conformance is intact and callable via the protocol type.
    // The AlarmManager dependency-injection path uses NotificationManager.shared as
    // `any NotificationScheduling`; this ensures that binding still compiles and runs.
    @Test func testConformsToNotificationSchedulingProtocol() {
        let nm: any NotificationScheduling = NotificationManager.shared
        nm.cancelAllNotifications()  // must not crash
    }

    // MARK: - scheduleNotification content (injected spy)

    @Test func testScheduleNotificationUsesAlarmIDAsIdentifier() {
        let spy = SpyUNCenter()
        let manager = NotificationManager(center: spy)
        let alarm = Alarm(hour: 8, minute: 30)
        manager.scheduleNotification(for: alarm, at: Date().addingTimeInterval(3600))
        #expect(spy.addedRequests.count == 1)
        #expect(spy.addedRequests[0].identifier == alarm.id.uuidString)
    }

    @Test func testScheduleNotificationSetsTimeSensitiveInterruptionLevel() {
        let spy = SpyUNCenter()
        let manager = NotificationManager(center: spy)
        let alarm = Alarm(hour: 8, minute: 0)
        manager.scheduleNotification(for: alarm, at: Date().addingTimeInterval(3600))
        #expect(spy.addedRequests.count == 1)
        #expect(spy.addedRequests[0].content.interruptionLevel == .timeSensitive)
    }

    @Test func testScheduleNotificationAttachesSoundWhenSoundEnabled() {
        let spy = SpyUNCenter()
        let manager = NotificationManager(center: spy)
        let alarm = Alarm(hour: 8, minute: 0)
        alarm.soundEnabled = true
        manager.scheduleNotification(for: alarm, at: Date().addingTimeInterval(3600))
        #expect(spy.addedRequests.count == 1)
        #expect(spy.addedRequests[0].content.sound != nil)
    }

    @Test func testScheduleNotificationOmitsSoundWhenSoundDisabled() {
        let spy = SpyUNCenter()
        let manager = NotificationManager(center: spy)
        let alarm = Alarm(hour: 8, minute: 0)
        alarm.soundEnabled = false
        manager.scheduleNotification(for: alarm, at: Date().addingTimeInterval(3600))
        #expect(spy.addedRequests.count == 1)
        #expect(spy.addedRequests[0].content.sound == nil)
    }

    @Test func testCancelAllNotificationsDelegatesToCenter() {
        let spy = SpyUNCenter()
        let manager = NotificationManager(center: spy)
        manager.cancelAllNotifications()
        #expect(spy.removedAllCount == 1)
    }
}
