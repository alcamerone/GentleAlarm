//
//  NotificationManager.swift
//  GentleAlarm
//

import UserNotifications

private let alarmCategoryID = "ALARM_CATEGORY"
private let snoozeActionID  = "SNOOZE_ACTION"
private let dismissActionID = "DISMISS_ACTION"

protocol NotificationScheduling: AnyObject {
    func scheduleNotification(for alarm: Alarm, at fireDate: Date)
    func cancelAllNotifications()
}

/// Handles local notification scheduling and user action callbacks (lock-screen snooze/dismiss).
///
/// Notifications serve as a lock-screen UI and background fallback — the primary alarm
/// is fired by AlarmManager's timer. Set `onSnooze` and `onDismiss` before any
/// notifications are delivered (done in GentleAlarmApp, step 6).
final class NotificationManager: NSObject, NotificationScheduling {

    static let shared = NotificationManager()

    var onSnooze: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
        registerCategories()
    }

    // MARK: - Permission

    func requestPermission() {
        // Permission denial is surfaced via the system permission prompt; no in-app gating needed
        center.requestAuthorization(options: [.alert, .sound, .timeSensitive]) { _, error in
            if let error {
                print("NotificationManager: permission request failed: \(error)")
            }
        }
    }

    // MARK: - Schedule / cancel

    /// Pre-schedule a notification at a known fire date.
    /// Call this whenever an alarm is saved/edited/toggled so the system can deliver
    /// the lock-screen notification at exactly the right moment — before hasFired is set.
    func scheduleNotification(for alarm: Alarm, at fireDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = alarm.label
        content.body = alarm.timeString
        content.categoryIdentifier = alarmCategoryID
        content.interruptionLevel = .timeSensitive  // bypasses Focus modes

        if alarm.soundEnabled {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: alarm.sound.filename))
        }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                print("NotificationManager: failed to schedule notification: \(error)")
            }
        }
    }

    func cancelNotification(for alarm: Alarm) {
        center.removePendingNotificationRequests(withIdentifiers: [alarm.id.uuidString])
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Private

    private func registerCategories() {
        let snooze = UNNotificationAction(
            identifier: snoozeActionID,
            title: "Snooze",
            options: []
        )
        let dismiss = UNNotificationAction(
            identifier: dismissActionID,
            title: "Dismiss",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: alarmCategoryID,
            actions: [snooze, dismiss],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Called when the user taps a notification action (snooze / dismiss) from the lock screen.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case snoozeActionID:
            onSnooze?()
        case dismissActionID, UNNotificationDefaultActionIdentifier:
            // Default action fires when the user taps the notification body itself.
            onDismiss?()
        default:
            break
        }
        completionHandler()
    }

    /// Allows the notification banner to show even while the app is foregrounded,
    /// so the lock-screen UI is consistent regardless of app state.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
