//
//  StepSchedule.swift
//  SkincareCompanion
//
//  Not everything in a routine belongs in it every day — exfoliating
//  acids, benzoyl peroxide, and retinoids are conventionally used a few
//  times a week (or every other day) rather than daily, and masks are
//  typically a once-a-week treatment. This file assigns each routine
//  step a frequency and a deterministic schedule (which day(s) of the
//  week it's due), so RoutineView can answer "what do I actually do
//  today" instead of listing everything at once regardless of date.
//
//  The schedule is derived from the product's own id rather than stored
//  anywhere, so it's stable across app launches without needing to
//  persist "which Tuesday did I start this" — the same product always
//  lands on the same day(s) of the week.
//

import Foundation

enum StepFrequency: String, Codable, CaseIterable, Hashable {
    case daily
    case everyOtherDay
    case threeTimesWeekly
    case weekly

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .everyOtherDay: return "Every other day"
        case .threeTimesWeekly: return "3x a week"
        case .weekly: return "Weekly"
        }
    }
}

enum StepSchedule {

    /// Assigns a conventional-use frequency based on category and
    /// detected actives. Category takes priority (a mask is a weekly
    /// treatment no matter what's in it); within "daily-ish" categories,
    /// irritation-prone actives (retinoids, BPO, exfoliating acids) get
    /// throttled back even if they showed up in a serum or toner rather
    /// than the "exfoliant" category.
    static func frequency(for product: Product) -> StepFrequency {
        if product.category == .mask { return .weekly }
        if product.category == .tool { return .weekly } // steamers etc. — commonly a weekly, not daily, thing
        if product.category == .exfoliant { return .threeTimesWeekly }

        let actives = product.detectedActives
        if actives.contains(.retinoid) || actives.contains(.benzoylPeroxide) {
            return .everyOtherDay
        }
        if actives.contains(.glycolicAcid) || actives.contains(.lacticAcid) || actives.contains(.salicylicAcid) {
            return .threeTimesWeekly
        }
        return .daily
    }

    /// Whether this product's step is due on the given date, given its
    /// frequency. Daily is always true; everything else is derived from
    /// a stable per-product offset so different products with the same
    /// frequency don't all cluster onto the same day.
    static func isDue(frequency: StepFrequency, productID: String, on date: Date, calendar: Calendar = .current) -> Bool {
        switch frequency {
        case .daily:
            return true
        case .weekly:
            let offset = stableOffset(for: productID, modulo: 7)
            let weekdayIndex = calendar.component(.weekday, from: date) - 1 // 0...6
            return weekdayIndex == offset
        case .threeTimesWeekly:
            let weekday = calendar.component(.weekday, from: date) // 1 (Sun) ... 7 (Sat)
            let patternA: Set<Int> = [2, 4, 6] // Mon / Wed / Fri
            let patternB: Set<Int> = [3, 5, 7] // Tue / Thu / Sat
            let offset = stableOffset(for: productID, modulo: 2)
            return (offset == 0 ? patternA : patternB).contains(weekday)
        case .everyOtherDay:
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
            let offset = stableOffset(for: productID, modulo: 2)
            return (dayOfYear % 2) == offset
        }
    }

    /// Human-readable description of the schedule, e.g. "Every day",
    /// "Mon / Wed / Fri", "Sundays".
    static func description(frequency: StepFrequency, productID: String, calendar: Calendar = .current) -> String {
        switch frequency {
        case .daily:
            return "Every day"
        case .everyOtherDay:
            return "Every other day"
        case .weekly:
            let offset = stableOffset(for: productID, modulo: 7)
            let symbols = calendar.weekdaySymbols // ["Sunday", "Monday", ... "Saturday"]
            guard offset < symbols.count else { return "Weekly" }
            return symbols[offset] + "s"
        case .threeTimesWeekly:
            let offset = stableOffset(for: productID, modulo: 2)
            return offset == 0 ? "Mon / Wed / Fri" : "Tue / Thu / Sat"
        }
    }

    /// The raw pattern offset a given id/frequency combination would
    /// hash to — exposed so RoutineEngine can detect when two different
    /// non-daily items in the same routine are about to land on the
    /// exact same day pattern purely by hash coincidence, and nudge one
    /// of them onto the other pattern instead. `nil` for `.daily`, which
    /// has no pattern to collide on.
    static func patternOffset(frequency: StepFrequency, productID: String) -> Int? {
        switch frequency {
        case .daily: return nil
        case .weekly: return stableOffset(for: productID, modulo: 7)
        case .threeTimesWeekly, .everyOtherDay: return stableOffset(for: productID, modulo: 2)
        }
    }

    /// A stable (not random-per-launch) small integer derived from a
    /// product's id, used to spread same-frequency products across
    /// different days instead of all landing on the same one.
    ///
    /// Deliberately NOT using Swift's `Hasher`/`hashValue` — those are
    /// seeded randomly per process launch (a DoS mitigation), so the
    /// same product would land on a different day every time the app
    /// restarts. This is a plain djb2-style string hash instead, which
    /// always produces the same value for the same id.
    private static func stableOffset(for id: String, modulo: Int) -> Int {
        var hash: UInt64 = 5381
        for byte in id.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return Int(hash % UInt64(modulo))
    }
}
