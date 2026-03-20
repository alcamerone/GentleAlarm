//
//  RepeatDays.swift
//  GentleAlarm
//

import Foundation

struct RepeatDays: Codable, Sendable {
    let rawValue: UInt8

    static let sunday    = RepeatDays(rawValue: 1 << 0)
    static let monday    = RepeatDays(rawValue: 1 << 1)
    static let tuesday   = RepeatDays(rawValue: 1 << 2)
    static let wednesday = RepeatDays(rawValue: 1 << 3)
    static let thursday  = RepeatDays(rawValue: 1 << 4)
    static let friday    = RepeatDays(rawValue: 1 << 5)
    static let saturday  = RepeatDays(rawValue: 1 << 6)

    static let weekdays: RepeatDays = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekend: RepeatDays  = [.saturday, .sunday]
    static let all: RepeatDays      = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

    /// Ordered array of (day, abbreviation) pairs starting from Monday.
    static let orderedDays: [(RepeatDays, String)] = [
        (.monday, "M"),
        (.tuesday, "T"),
        (.wednesday, "W"),
        (.thursday, "T"),
        (.friday, "F"),
        (.saturday, "S"),
        (.sunday, "S")
    ]

    /// Full day names in the same Monday-first order as `orderedDays`.
    static let orderedDayNames: [String] = [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ]

    /// Returns a human-readable summary, e.g. "Weekdays", "Every day", "Mon, Wed, Fri".
    var displayText: String {
        if self == .all { return "Every day" }
        if self == .weekdays { return "Weekdays" }
        if self == .weekend { return "Weekends" }
        if self.isEmpty { return "Never" }

        let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let bits: [RepeatDays] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        return zip(bits, names)
            .filter { contains($0.0) }
            .map(\.1)
            .joined(separator: ", ")
    }

    /// Given a reference date, returns the next `Date` when this alarm should fire
    /// at the specified hour and minute. Returns nil if `self.isEmpty` (one-time alarm).
    func nextFireDate(after reference: Date, hour: Int, minute: Int) -> Date? {
        guard !isEmpty else { return nil }

        let calendar = Calendar.current
        let bits: [RepeatDays] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

        for dayOffset in 0..<8 {
            guard let candidate = calendar.date(byAdding: .day, value: dayOffset, to: reference) else { continue }
            let weekday = calendar.component(.weekday, from: candidate) // 1 = Sunday
            let bit = bits[weekday - 1]
            guard contains(bit) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: candidate)
            components.hour   = hour
            components.minute = minute
            components.second = 0
            guard let fireDate = calendar.date(from: components) else { continue }
            if fireDate >= reference { return fireDate }
        }
        return nil
    }
}

// Conformance is declared in a separate extension so `@preconcurrency` can be applied,
// preventing spurious @MainActor isolation inference that cascades from Alarm (@Model).
extension RepeatDays: @preconcurrency OptionSet {}
