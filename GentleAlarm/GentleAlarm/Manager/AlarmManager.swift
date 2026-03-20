//
//  AlarmManager.swift
//  GentleAlarm
//

import Foundation
import SwiftData

private let snoozeDuration: TimeInterval = 9 * 60  // 9 minutes, standard iOS default

/// Central coordinator for alarm scheduling, firing, snooze, and dismiss.
/// Instantiated once in GentleAlarmApp and injected via .environment.
@Observable
final class AlarmManager {

    // MARK: - Public state

    /// Non-nil while an alarm is actively firing; drives ActiveAlarmView presentation.
    var activeAlarm: Alarm?

    // MARK: - Dependencies

    let audioEngine: AudioEngine
    private let modelContext: ModelContext
    private let notificationScheduler: any NotificationScheduling

    // MARK: - Scheduling state

    private var schedulingTimer: DispatchSourceTimer?
    private var snoozeAlarmID: UUID?
    private var snoozeFireDate: Date?

    // MARK: - Init

    init(modelContext: ModelContext, audioEngine: AudioEngine, notificationScheduler: (any NotificationScheduling)? = nil) {
        self.modelContext         = modelContext
        self.audioEngine          = audioEngine
        self.notificationScheduler = notificationScheduler ?? NotificationManager.shared
    }

    // MARK: - App lifecycle

    /// Call when moving to .background. Only starts the heartbeat if there is
    /// actually an alarm scheduled — no point burning CPU otherwise.
    func appDidBackground() {
        if nearestPendingAlarm() != nil {
            audioEngine.startHeartbeat()
            reschedule()
        }
    }

    /// Call when returning to .active. The process is foregrounded so the
    /// heartbeat is no longer needed.
    func appDidForeground() {
        audioEngine.stopHeartbeat()
    }

    // MARK: - Public scheduling API

    /// Recalculate and reschedule after any alarm list change (add / edit / delete / toggle).
    /// No-op while an alarm is actively ringing — cancelling the pre-scheduled notification
    /// mid-ring would disrupt the lock-screen UI; snooze()/dismiss() handle rescheduling
    /// once the user responds.
    func reschedule() {
        guard activeAlarm == nil else { return }
        scheduleNextCheck()
        refreshNotifications()
    }

    // MARK: - Fire / Snooze / Dismiss

    func snooze() {
        guard let alarm = activeAlarm else { return }
        audioEngine.stopAlarm()
        snoozeAlarmID   = alarm.id
        snoozeFireDate  = Date().addingTimeInterval(snoozeDuration)
        setActiveAlarm(nil)
        scheduleNextCheck()
        refreshNotifications()
    }

    func dismiss() {
        guard let alarm = activeAlarm else { return }
        audioEngine.stopAlarm()
        snoozeAlarmID  = nil
        snoozeFireDate = nil

        if alarm.repeatDays.isEmpty {
            // One-time alarm: disable so it doesn't fire again.
            alarm.isEnabled = false
            try? modelContext.save()
        }
        // Repeating alarms stay enabled; nextFireDate() will return next week's occurrence.

        setActiveAlarm(nil)
        scheduleNextCheck()
        refreshNotifications()
    }

    // MARK: - Private scheduling

    private func refreshNotifications() {
        notificationScheduler.cancelAllNotifications()
        guard let (alarm, fireDate) = nearestPendingAlarm() else { return }
        notificationScheduler.scheduleNotification(for: alarm, at: fireDate)
    }

    private func scheduleNextCheck() {
        schedulingTimer?.cancel()
        schedulingTimer = nil

        // An alarm is already ringing — don't schedule another tick.
        // snooze() and dismiss() will call reschedule() when the user responds.
        guard activeAlarm == nil else { return }

        guard let (_, fireDate) = nearestPendingAlarm() else { return }

        let secondsUntil = fireDate.timeIntervalSinceNow

        // Already past due — fire immediately.
        if secondsUntil <= 0 {
            tick()
            return
        }

        // Coarse check when the alarm is far away; fine check within 2 minutes.
        let delay: DispatchTimeInterval = secondsUntil > 120 ? .seconds(60) : .seconds(1)

        // Background queue so the timer fires even while backgrounded (the heartbeat
        // audio keeps the process alive). tick() is dispatched to main so all
        // SwiftData access and @Observable mutations stay on the correct thread.
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        timer.schedule(deadline: .now() + delay, repeating: .never)
        timer.setEventHandler { [weak self] in DispatchQueue.main.async { self?.tick() } }
        timer.resume()
        schedulingTimer = timer
    }

    private func tick() {
        guard let (alarm, fireDate) = nearestPendingAlarm() else { return }

        if fireDate.timeIntervalSinceNow <= 0 {
            fire(alarm)
            // Reschedule so any other pending alarms still get a timer. The
            // fired alarm is no longer returned by nearestPendingAlarm() for
            // one-time alarms (nextFireDate returns nil for past-due one-time
            // alarms) and returns a future occurrence for repeating ones.
            scheduleNextCheck()
        } else {
            scheduleNextCheck()
        }
    }

    private func fire(_ alarm: Alarm) {
        // Prevent re-firing while the same alarm is already active (e.g. while the
        // user hasn't dismissed yet and scheduleNextCheck keeps ticking past oneTimeFire).
        guard activeAlarm?.id != alarm.id else { return }

        snoozeAlarmID  = nil
        snoozeFireDate = nil

        alarm.hasFired = true
        do {
            try modelContext.save()
        } catch {
            print("AlarmManager: modelContext.save() failed in fire(_:): \(error)")
        }

        // Notification was already pre-scheduled by reschedule(); nothing to do here.

        if alarm.soundEnabled {
            audioEngine.startAlarm(
                soundName: alarm.soundName,
                rampDurationSeconds: alarm.rampDurationSeconds,
                vibrate: alarm.vibrationEnabled
            )
        } else if alarm.vibrationEnabled {
            audioEngine.startAlarm(soundName: "", rampDurationSeconds: 0, vibrate: true)
        }

        setActiveAlarm(alarm)
    }

    // MARK: - Nearest alarm query

    /// Returns the enabled alarm with the earliest upcoming fire date, accounting for any active snooze.
    func nearestPendingAlarm() -> (Alarm, Date)? {
        let descriptor = FetchDescriptor<Alarm>(
            predicate: #Predicate { $0.isEnabled }
        )
        let alarms: [Alarm]
        do {
            alarms = try modelContext.fetch(descriptor)
        } catch {
            print("AlarmManager: modelContext.fetch failed: \(error)")
            return nil
        }

        let now = Date()
        var best: (Alarm, Date)?

        for alarm in alarms {
            let fireDate: Date?

            if alarm.id == snoozeAlarmID, let snoozeDate = snoozeFireDate {
                fireDate = snoozeDate
            } else {
                fireDate = alarm.nextFireDate(after: now)
            }

            guard let nextDate = fireDate else { continue }

            // map returns nil (not false) when best is nil; ?? true picks the first alarm encountered
            if best.map({ nextDate < $0.1 }) ?? true {
                best = (alarm, nextDate)
            }
        }

        return best
    }

    // MARK: - Thread safety

    /// Always mutate @Observable properties that drive UI on the main thread.
    private func setActiveAlarm(_ alarm: Alarm?) {
        if Thread.isMainThread {
            activeAlarm = alarm
        } else {
            DispatchQueue.main.async { self.activeAlarm = alarm }
        }
    }
}
