//
//  RoutineAdherence.swift
//  SkincareCompanion
//
//  Pure math over RoutineCompletion records: a "did I actually do this"
//  streak and a calendar-heatmap-friendly day list. Kept separate from
//  RoutineEngine (which is about *building* a routine, not tracking
//  whether someone followed it) but follows the same "pure, storage-
//  agnostic, takes plain data in" pattern.
//

import Foundation

struct DayAdherence: Identifiable {
    let date: Date
    let dayKey: String
    let didAM: Bool
    let didPM: Bool
    var id: String { dayKey }

    /// A day counts as "followed" if at least one session was marked
    /// done — someone who only has a PM routine (or skipped AM on
    /// purpose) shouldn't read as a broken streak.
    var followed: Bool { didAM || didPM }
}

enum RoutineAdherence {
    /// Builds one `DayAdherence` per day for the last `days` days
    /// (inclusive of `today`), oldest first — ready to render as a
    /// calendar-heatmap strip.
    static func recentDays(completions: [RoutineCompletion], today: Date = .now, days: Int = 28, calendar: Calendar = .current) -> [DayAdherence] {
        var byDay: [String: (am: Bool, pm: Bool)] = [:]
        for completion in completions {
            var entry = byDay[completion.dayKey] ?? (am: false, pm: false)
            if completion.sessionRaw == "am" { entry.am = true }
            if completion.sessionRaw == "pm" { entry.pm = true }
            byDay[completion.dayKey] = entry
        }

        return (0..<days).reversed().compactMap { offset -> DayAdherence? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = RoutineViewModel.dayKey(for: date)
            let entry = byDay[key] ?? (am: false, pm: false)
            return DayAdherence(date: date, dayKey: key, didAM: entry.am, didPM: entry.pm)
        }
    }

    /// Consecutive followed days counting back from `today`, stopping at
    /// the first day that wasn't followed. Today itself not yet being
    /// marked done doesn't break the streak — it just isn't counted yet
    /// (checking at 9am shouldn't zero out an otherwise-solid streak).
    static func currentStreak(completions: [RoutineCompletion], today: Date = .now, calendar: Calendar = .current) -> Int {
        var byDay: Set<String> = []
        for completion in completions {
            byDay.insert(completion.dayKey)
        }

        var streak = 0
        var cursor = today
        var isFirstDay = true
        while true {
            let key = RoutineViewModel.dayKey(for: cursor)
            let followedToday = byDay.contains(key)
            if !followedToday {
                if isFirstDay {
                    // Today not marked yet — don't break the streak,
                    // just don't count it; move on to yesterday.
                    isFirstDay = false
                    guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                    cursor = previous
                    continue
                }
                break
            }
            streak += 1
            isFirstDay = false
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
