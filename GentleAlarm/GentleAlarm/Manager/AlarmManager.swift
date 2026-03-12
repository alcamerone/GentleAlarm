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

    // MARK: - Scheduling state

    private var schedulingTimer: DispatchSourceTimer?
    private var snoozeAlarmID: UUID?
    private var snoozeFireDate: Date?

    // MARK: - Init

    init(modelContext: ModelContext, audioEngine: AudioEngine) {
        self.modelContext = modelContext
        self.audioEngine  = audioEngine
    }

    // MARK: - App lifecycle

    /// Call when moving to .background. Only starts the heartbeat if there is
    /// actually an alarm scheduled — no point burning CPU otherwise.
    func appDidBackground() {
        if nearestPendingAlarm() != nil {
            audioEngine.startHeartbeat()
        }
    }

    /// Call when returning to .active. The process is foregrounded so the
    /// heartbeat is no longer needed.
    func appDidForeground() {
        audioEngine.stopHeartbeat()
    }

    // MARK: - Public scheduling API

    /// Recalculate and reschedule after any alarm list change (add / edit / delete / toggle).
    func reschedule() {
        scheduleNextCheck()
    }

    // MARK: - Fire / Snooze / Dismiss

    func snooze() {
        guard let alarm = activeAlarm else { return }
        audioEngine.stopAlarm()
        snoozeAlarmID   = alarm.id
        snoozeFireDate  = Date().addingTimeInterval(snoozeDuration)
        setActiveAlarm(nil)
        scheduleNextCheck()
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
    }

    // MARK: - Private scheduling

    private func scheduleNextCheck() {
        schedulingTimer?.cancel()
        schedulingTimer = nil

        guard let (_, fireDate) = nearestPendingAlarm() else { return }

        let secondsUntil = fireDate.timeIntervalSinceNow

        // Already past due — fire immediately.
        if secondsUntil <= 0 {
            tick()
            return
        }

        // Coarse check when the alarm is far away; fine check within 2 minutes.
        let delay: DispatchTimeInterval = secondsUntil > 120 ? .seconds(60) : .seconds(1)

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        timer.schedule(deadline: .now() + delay, repeating: .never)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        schedulingTimer = timer
    }

    private func tick() {
        guard let (alarm, fireDate) = nearestPendingAlarm() else { return }

        if fireDate.timeIntervalSinceNow <= 0 {
            fire(alarm)
        } else {
            scheduleNextCheck()
        }
    }

    private func fire(_ alarm: Alarm) {
        snoozeAlarmID  = nil
        snoozeFireDate = nil

        NotificationManager.shared.postAlarmNotification(alarm)

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
    private func nearestPendingAlarm() -> (Alarm, Date)? {
        let descriptor = FetchDescriptor<Alarm>(
            predicate: #Predicate { $0.isEnabled }
        )
        guard let alarms = try? modelContext.fetch(descriptor) else { return nil }

        let now = Date()
        var best: (Alarm, Date)?

        for alarm in alarms {
            let fireDate: Date?

            if alarm.id == snoozeAlarmID, let sd = snoozeFireDate {
                fireDate = sd
            } else {
                fireDate = alarm.nextFireDate(after: now)
            }

            guard let fd = fireDate else { continue }

            if best == nil || fd < best!.1 {
                best = (alarm, fd)
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
