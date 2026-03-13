//
//  AlarmRowView.swift
//  GentleAlarm
//

import SwiftData
import SwiftUI

struct AlarmRowView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AlarmManager.self) private var alarmManager

    let alarm: Alarm
    var onEditTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            // .borderless gives List-cell-aware button priority over the cell's default tap,
            // while keeping the Toggle's UISwitch as a separate accessibility element on the right.
            Button(action: { onEditTap?() }, label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(timeString)
                            .font(.system(size: 48, weight: .thin, design: .default))
                        Text(amPm)
                            .font(.title3)
                            .padding(.bottom, 6)
                    }
                    Text(alarm.label)
                        .font(.subheadline)
                    Text(alarm.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            })
            .buttonStyle(.borderless)

            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { newValue in
                    alarm.isEnabled = newValue
                    try? modelContext.save()
                    alarmManager.reschedule()
                }
            ))
            .labelsHidden()
            .accessibilityHint("Double-tap to \(alarm.isEnabled ? "disable" : "enable")")
        }
        .accessibilityElement(children: .contain)
        .opacity(alarm.isEnabled ? 1 : 0.4)
    }

    // MARK: - Helpers

    private var timeString: String {
        let hour12 = alarm.hour % 12 == 0 ? 12 : alarm.hour % 12
        return String(format: "%d:%02d", hour12, alarm.minute)
    }

    private var amPm: String {
        alarm.hour < 12 ? "AM" : "PM"
    }
}
