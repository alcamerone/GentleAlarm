//
//  GentleAlarmApp.swift
//  GentleAlarm
//

import SwiftUI
import SwiftData

@main
struct GentleAlarmApp: App {

    // MARK: - SwiftData

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([Alarm.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - Managers

    @State private var alarmManager: AlarmManager

    init() {
        // Build the model context first, then hand it to AlarmManager.
        let container = sharedModelContainer
        let context   = ModelContext(container)
        let engine    = AudioEngine()
        let manager   = AlarmManager(modelContext: context, audioEngine: engine)

        // Wire notification action callbacks before any notifications can fire.
        NotificationManager.shared.onSnooze  = { manager.snooze() }
        NotificationManager.shared.onDismiss = { manager.dismiss() }

        _alarmManager = State(initialValue: manager)

        // Request permission on first launch (no-op on subsequent launches).
        NotificationManager.shared.requestPermission()
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(alarmManager)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                alarmManager.appDidBackground()
            case .active:
                alarmManager.appDidForeground()
            default:
                break
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
}
