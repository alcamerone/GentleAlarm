//
//  AlarmListView.swift
//  GentleAlarm
//

import SwiftData
import SwiftUI

struct AlarmListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AlarmManager.self) private var alarmManager

    @Query(sort: [SortDescriptor(\Alarm.hour), SortDescriptor(\Alarm.minute)])
    private var alarms: [Alarm]

    @State private var showingAddSheet = false
    @State private var editingAlarm: Alarm?

    var body: some View {
        List {
            ForEach(alarms) { alarm in
                AlarmRowView(alarm: alarm) {
                    editingAlarm = alarm
                }
            }
            .onDelete(perform: deleteAlarms)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let next = nextAlarmSummary {
                Text(next)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(.bar)
            }
        }
        .navigationTitle("Alarms")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add alarm")
                .accessibilityIdentifier("addAlarmButton")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AlarmEditView(alarm: nil)
        }
        .sheet(item: $editingAlarm) { alarm in
            AlarmEditView(alarm: alarm)
        }
    }

    // MARK: - Helpers

    private var nextAlarmSummary: String? {
        guard let date = alarms
            .filter(\.isEnabled)
            .compactMap({ $0.nextFireDate() })
            .min()
        else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Next alarm \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    private func deleteAlarms(at offsets: IndexSet) {
        for index in offsets {
            let alarm = alarms[index]
            NotificationManager.shared.cancelNotification(for: alarm)
            modelContext.delete(alarm)
        }
        try? modelContext.save()
        alarmManager.reschedule()
    }
}
