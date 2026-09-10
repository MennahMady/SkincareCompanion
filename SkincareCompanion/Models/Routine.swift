//
//  Routine.swift
//  SkincareCompanion
//
//  In-memory output of RoutineEngine: a generated AM/PM routine plus
//  any conflict warnings and gap-based recommendations. Not persisted
//  directly — SavedRoutine below stores a lightweight snapshot when the
//  user chooses to save one.
//

import Foundation

struct RoutineStep: Identifiable, Hashable {
    var id: String { bagItemID }
    let bagItemID: String
    let productName: String
    let brand: String?
    let category: ProductCategory
    let note: String?
    let frequency: StepFrequency
    let scheduleDescription: String
    /// The key StepSchedule actually hashes to pick a day pattern. This
    /// is usually just `bagItemID`, but RoutineEngine can hand in a
    /// different (still stable) key when two non-daily items in the same
    /// routine would otherwise land on the exact same days by hash
    /// coincidence — see `RoutineEngine.assignScheduleKeys`.
    let scheduleKey: String

    init(bagItemID: String, productName: String, brand: String?, category: ProductCategory, note: String?, frequency: StepFrequency, scheduleDescription: String, scheduleKey: String? = nil) {
        self.bagItemID = bagItemID
        self.productName = productName
        self.brand = brand
        self.category = category
        self.note = note
        self.frequency = frequency
        self.scheduleDescription = scheduleDescription
        self.scheduleKey = scheduleKey ?? bagItemID
    }

    /// Whether this step is actually due on the given date. Daily steps
    /// are always due; everything else follows StepSchedule's
    /// deterministic per-product weekly pattern.
    func isDue(on date: Date = .now) -> Bool {
        StepSchedule.isDue(frequency: frequency, productID: scheduleKey, on: date)
    }
}

struct RoutineWarning: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    /// Which specific bag items this warning is actually about, if any.
    /// When non-empty, the UI attaches a small warning icon to those
    /// exact product rows (tap to reveal) instead of showing the
    /// warning in a general upfront list. Empty means it's a
    /// routine-wide warning with no single product to pin it to (e.g.
    /// "no sunscreen in your bag").
    var relatedBagItemIDs: [String] = []
}

struct Recommendation: Identifiable, Hashable {
    let id = UUID()
    let concern: SkinConcern
    let missingCategory: ProductCategory
    let suggestedActives: [Active]
    let reason: String
}

struct Routine {
    var concerns: [SkinConcern]
    var amSteps: [RoutineStep]
    var pmSteps: [RoutineStep]
    var warnings: [RoutineWarning]
    var recommendations: [Recommendation]
    var generatedAt: Date = .now

    /// AM steps actually due on the given date (daily steps always
    /// qualify; weekly/every-other-day/3x-weekly steps only on their
    /// scheduled day). Powers the "Today" view in RoutineView.
    func amSteps(on date: Date = .now) -> [RoutineStep] {
        amSteps.filter { $0.isDue(on: date) }
    }

    func pmSteps(on date: Date = .now) -> [RoutineStep] {
        pmSteps.filter { $0.isDue(on: date) }
    }

    /// Steps that exist in the routine but aren't due today — shown
    /// separately so "why isn't my exfoliant listed" has a visible
    /// answer instead of the product silently disappearing.
    func stepsNotToday(on date: Date = .now) -> [RoutineStep] {
        var seen = Set<String>()
        return (amSteps + pmSteps).filter { step in
            guard !step.isDue(on: date), !seen.contains(step.id) else { return false }
            seen.insert(step.id)
            return true
        }
    }
}
