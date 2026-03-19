//
//  AlarmEditView.swift
//  GentleAlarm
//

import SwiftData
import SwiftUI

struct AlarmEditView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AlarmManager.self) private var alarmManager

    let alarm: Alarm?

    // Local draft state — written back to the model only on Save,
    // so Cancel leaves the original alarm untouched.
    @State private var selectedTime: Date
    @State private var label: String
    @State private var repeatDays: RepeatDays
    @State private var soundName: String
    @State private var rampDurationSeconds: Int
    @State private var snoozeEnabled: Bool
    @State private var vibrationEnabled: Bool
    @State private var soundEnabled: Bool

    init(alarm: Alarm?) {
        self.alarm = alarm
        let now = Date()
        let calendar = Calendar.current
        if let alarm {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour   = alarm.hour
            components.minute = alarm.minute
            _selectedTime         = State(initialValue: calendar.date(from: components) ?? now)
            _label                = State(initialValue: alarm.label)
            _repeatDays           = State(initialValue: alarm.repeatDays)
            _soundName            = State(initialValue: alarm.soundName)
            _rampDurationSeconds  = State(initialValue: alarm.rampDurationSeconds)
            _snoozeEnabled        = State(initialValue: alarm.snoozeEnabled)
            _vibrationEnabled     = State(initialValue: alarm.vibrationEnabled)
            _soundEnabled         = State(initialValue: alarm.soundEnabled)
        } else {
            _selectedTime         = State(initialValue: now)
            _label                = State(initialValue: "Alarm")
            _repeatDays           = State(initialValue: [])
            _soundName            = State(initialValue: AlarmSound.possibility.rawValue)
            _rampDurationSeconds  = State(initialValue: 60)
            _snoozeEnabled        = State(initialValue: true)
            _vibrationEnabled     = State(initialValue: true)
            _soundEnabled         = State(initialValue: true)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Time ──────────────────────────────────────────────────
                Section {
                    DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }

                // ── Label ─────────────────────────────────────────────────
                Section {
                    TextField("Label", text: $label)
                        .accessibilityIdentifier("alarmLabelField")
                }

                // ── Repeat days ───────────────────────────────────────────
                Section("Repeat") {
                    RepeatDaysPicker(selection: $repeatDays)
                }

                // ── Sound & ramp ──────────────────────────────────────────
                Section {
                    NavigationLink {
                        SoundPickerView(soundName: $soundName)
                    } label: {
                        LabeledValue(
                            label: "Sound",
                            value: AlarmSound(rawValue: soundName)?.displayName ?? soundName
                        )
                    }

                    NavigationLink {
                        RampPickerView(rampDurationSeconds: $rampDurationSeconds)
                    } label: {
                        LabeledValue(label: "Ramp Duration", value: rampLabel)
                    }
                }

                // ── Toggles ───────────────────────────────────────────────
                Section {
                    Toggle("Snooze", isOn: $snoozeEnabled)
                    Toggle("Vibration", isOn: $vibrationEnabled)
                    Toggle("Sound", isOn: $soundEnabled)
                }
            }
            .navigationTitle(alarm == nil ? "Add Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelAlarmButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .accessibilityIdentifier("saveAlarmButton")
                }
            }
        }
    }

    // MARK: - Helpers

    private var rampLabel: String {
        switch rampDurationSeconds {
        case 30:  return "30 sec"
        case 60:  return "1 min"
        case 120: return "2 min"
        case 300: return "5 min"
        case 600: return "10 min"
        default:  return "\(rampDurationSeconds) sec"
        }
    }

    private func save() {
        let calendar = Calendar.current
        let hour   = calendar.component(.hour, from: selectedTime)
        let minute = calendar.component(.minute, from: selectedTime)

        // For one-time alarms, build an explicit fire date anchored to the real current
        // date rather than the date inside selectedTime. The DatePicker can normalise a
        // past initialisation value to tomorrow, so extracting year/month/day from
        // selectedTime can silently produce the wrong calendar day. Using Date() ensures
        // we always get today-or-tomorrow based on whether the chosen time has passed.
        let oneTimeFire: Date? = repeatDays.isEmpty ? {
            let now = Date()
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour   = hour
            components.minute = minute
            components.second = 0
            guard let today = calendar.date(from: components) else { return nil }
            if today >= now { return today }
            return calendar.date(byAdding: .day, value: 1, to: today)
        }() : nil

        if let alarm {
            alarm.hasFired            = false
            alarm.hour                = hour
            alarm.minute              = minute
            alarm.label               = label
            alarm.repeatDays          = repeatDays
            alarm.soundName           = soundName
            alarm.rampDurationSeconds = rampDurationSeconds
            alarm.snoozeEnabled       = snoozeEnabled
            alarm.vibrationEnabled    = vibrationEnabled
            alarm.soundEnabled        = soundEnabled
            alarm.oneTimeFire         = oneTimeFire
        } else {
            let newAlarm = Alarm(hour: hour, minute: minute)
            newAlarm.label               = label
            newAlarm.repeatDays          = repeatDays
            newAlarm.soundName           = soundName
            newAlarm.rampDurationSeconds = rampDurationSeconds
            newAlarm.snoozeEnabled       = snoozeEnabled
            newAlarm.vibrationEnabled    = vibrationEnabled
            newAlarm.soundEnabled        = soundEnabled
            newAlarm.oneTimeFire         = oneTimeFire
            modelContext.insert(newAlarm)
        }

        try? modelContext.save()
        alarmManager.reschedule()
        dismiss()
    }
}

// MARK: - RepeatDaysPicker

private struct RepeatDaysPicker: View {
    @Binding var selection: RepeatDays

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<RepeatDays.orderedDays.count, id: \.self) { index in
                let day        = RepeatDays.orderedDays[index].0
                let abbrev     = RepeatDays.orderedDays[index].1
                let name       = RepeatDays.orderedDayNames[index]
                let isSelected = selection.contains(day)
                Button {
                    var updated = selection
                    if isSelected { updated.remove(day) } else { updated.insert(day) }
                    selection = updated
                } label: {
                    Text(abbrev)
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 36, height: 36)
                        .background(isSelected ? Color.accentColor : Color(.systemGray5))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

// MARK: - LabeledValue

/// A right-aligned secondary value label, used inside NavigationLink rows.
private struct LabeledValue: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
