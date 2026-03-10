//
//  ContentView.swift
//  GentleAlarm
//

import SwiftUI

struct ContentView: View {

    @Environment(AlarmManager.self) private var alarmManager

    var body: some View {
        NavigationStack {
            AlarmListView()
        }
        .fullScreenCover(isPresented: Binding(
            get: { alarmManager.activeAlarm != nil },
            set: { _ in }
        )) {
            if let alarm = alarmManager.activeAlarm {
                ActiveAlarmView(alarm: alarm)
            }
        }
    }
}

#Preview {
    ContentView()
}
