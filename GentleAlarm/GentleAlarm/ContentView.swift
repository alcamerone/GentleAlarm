//
//  ContentView.swift
//  GentleAlarm
//

import SwiftUI

struct ContentView: View {

    @Environment(AlarmManager.self) private var alarmManager

    var body: some View {
        let activeAlarm = alarmManager.activeAlarm
        NavigationStack {
            AlarmListView()
        }
        .fullScreenCover(isPresented: Binding(
            get: { activeAlarm != nil },
            set: { _ in }
        )) {
            if let alarm = activeAlarm {
                ActiveAlarmView(alarm: alarm)
            }
        }
    }
}

#Preview {
    ContentView()
}
