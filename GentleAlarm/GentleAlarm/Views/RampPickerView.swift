//
//  RampPickerView.swift
//  GentleAlarm
//

import SwiftUI

struct RampPickerView: View {

    @Binding var rampDurationSeconds: Int

    var body: some View {
        List {
            row(label: "30 seconds", seconds: 30)
            row(label: "1 minute", seconds: 60)
            row(label: "2 minutes", seconds: 120)
            row(label: "5 minutes", seconds: 300)
            row(label: "10 minutes", seconds: 600)
        }
        .navigationTitle("Ramp Duration")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(label: String, seconds: Int) -> some View {
        Button {
            rampDurationSeconds = seconds
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                if rampDurationSeconds == seconds {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}
