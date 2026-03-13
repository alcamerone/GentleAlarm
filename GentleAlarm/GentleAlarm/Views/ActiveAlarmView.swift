//
//  ActiveAlarmView.swift
//  GentleAlarm
//

import SwiftUI

struct ActiveAlarmView: View {

    @Environment(AlarmManager.self) private var alarmManager

    let alarm: Alarm

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Time ─────────────────────────────────────────────────
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(timeString)
                        .font(.system(size: 80, weight: .thin))
                        .foregroundStyle(.white)
                    Text(amPm)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(.bottom, 10)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(timeString) \(amPm)")

                // ── Label ─────────────────────────────────────────────────
                Text(alarm.label)
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 12)

                Spacer()

                // ── Buttons ───────────────────────────────────────────────
                VStack(spacing: 14) {
                    if alarm.snoozeEnabled {
                        Button("Snooze") { alarmManager.snooze() }
                            .buttonStyle(AlarmActionButtonStyle(prominent: false))
                            .accessibilityIdentifier("snoozeButton")
                    }
                    Button("Dismiss") { alarmManager.dismiss() }
                        .buttonStyle(AlarmActionButtonStyle(prominent: true))
                        .accessibilityIdentifier("dismissButton")
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        // Prevent swipe-to-dismiss — the alarm must be explicitly dismissed.
        .interactiveDismissDisabled()
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

// MARK: - Button style

private struct AlarmActionButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(prominent ? Color.white : Color.white.opacity(0.15))
            .foregroundStyle(prominent ? Color.black : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}
