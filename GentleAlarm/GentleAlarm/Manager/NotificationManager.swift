//
//  NotificationManager.swift
//  GentleAlarm
//

import UserNotifications

private let alarmCategoryID = "ALARM_CATEGORY"
private let snoozeActionID  = "SNOOZE_ACTION"
private let dismissActionID = "DISMISS_ACTION"

/// Handles local notification scheduling and user action callbacks (lock-screen snooze/dismiss).
///
/// Notifications serve as a lock-screen UI and background fallback — the primary alarm
/// is fired by AlarmManager's timer. Set `onSnooze` and `onDismiss` before any
/// notifications are delivered (done in GentleAlarmApp, step 6).
final class NotificationManager: NSObject {

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
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                print("NotificationManager: permission request failed: \(error)")
            }
        }
    }

    // MARK: - Schedule / cancel

    /// Post a notification that fires at the alarm's next fire date.
    /// The notification is cancelled and re-posted whenever the alarm is rescheduled.
    func postAlarmNotification(_ alarm: Alarm) {
        guard let fireDate = alarm.nextFireDate() else { return }

        let content = UNMutableNotificationContent()
        content.title       = alarm.label
        content.body        = alarm.timeString
        content.categoryIdentifier = alarmCategoryID

        if alarm.soundEnabled {
            let soundName = UNNotificationSoundName(rawValue: alarm.sound.filename)
            content.sound = UNNotificationSound(named: soundName)
        }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
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
