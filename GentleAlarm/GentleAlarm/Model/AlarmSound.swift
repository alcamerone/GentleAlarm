//
//  AlarmSound.swift
//  GentleAlarm
//

import Foundation

enum AlarmSound: String, CaseIterable, Identifiable, Codable {
    case possibility  = "Possibility"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .possibility:  return "Possibility"
        }
    }

    var filename: String { "\(rawValue).caf" }
}
