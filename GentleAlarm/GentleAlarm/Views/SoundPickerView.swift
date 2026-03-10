//
//  SoundPickerView.swift
//  GentleAlarm
//

import SwiftUI

struct SoundPickerView: View {

    @Binding var soundName: String

    var body: some View {
        List {
            ForEach(AlarmSound.allCases) { sound in
                Button {
                    soundName = sound.rawValue
                } label: {
                    HStack {
                        Text(sound.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if soundName == sound.rawValue {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle("Sound")
        .navigationBarTitleDisplayMode(.inline)
    }
}
