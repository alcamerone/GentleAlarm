//
//  Alarm.swift
//  GentleAlarm
//

import Foundation
import SwiftData

@Model
final class Alarm {
    var id: UUID = UUID()
    var label: String = "Alarm"
    var hour: Int         // 0–23
    var minute: Int       // 0–59
    var isEnabled: Bool = true
    var repeatDaysRaw: UInt8 = 0       // RepeatDays.rawValue (SwiftData can't store custom OptionSets directly)
    var soundName: String = AlarmSound.possibility.rawValue
    var rampDurationSeconds: Int = 60
    var snoozeEnabled: Bool = true
    var vibrationEnabled: Bool = true
    var soundEnabled: Bool = true

    /// Convenience wrapper around the raw storage.
    @Transient var repeatDays: RepeatDays {
        get { RepeatDays(rawValue: repeatDaysRaw) }
        set { repeatDaysRaw = newValue.rawValue }
    }

    /// The resolved `AlarmSound`, defaulting to `.gentleBells` for unknown names.
    @Transient var sound: AlarmSound {
        AlarmSound(rawValue: soundName) ?? .possibility
    }

    init(hour: Int, minute: Int) {
        self.hour   = hour
        self.minute = minute
    }

    // MARK: - Display helpers

    /// e.g. "07:30"
    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Secondary line shown in the alarm row, e.g. "Weekdays · Gentle Bells"
    var subtitle: String {
        let days = repeatDays.isEmpty ? "Once" : repeatDays.displayText
        return "\(days) · \(sound.displayName)"
    }

    // MARK: - Scheduling

    /// Returns the next Date this alarm should fire, or nil if disabled / can't be determined.
    func nextFireDate(after reference: Date = Date()) -> Date? {
        guard isEnabled else { return nil }

        if !repeatDays.isEmpty {
            return repeatDays.nextFireDate(after: reference, hour: hour, minute: minute)
        }

        // One-time alarm: fire at the next occurrence of hour:minute today or tomorrow.
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: reference)
        components.hour   = hour
        components.minute = minute
        components.second = 0
        guard let today = calendar.date(from: components) else { return nil }
        if today > reference { return today }
        return calendar.date(byAdding: .day, value: 1, to: today)
    }
}
