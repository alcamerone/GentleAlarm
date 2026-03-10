//
//  AlarmSound.swift
//  GentleAlarm
//

import Foundation

enum AlarmSound: String, CaseIterable, Identifiable, Codable {
    case gentleBells  = "gentle_bells"
    case softChime    = "soft_chime"
    case morningBirds = "morning_birds"
    case risingTone   = "rising_tone"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gentleBells:  return "Gentle Bells"
        case .softChime:    return "Soft Chime"
        case .morningBirds: return "Morning Birds"
        case .risingTone:   return "Rising Tone"
        }
    }

    var filename: String { "\(rawValue).caf" }
}
