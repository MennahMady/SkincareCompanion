//
//  SavedRoutine.swift
//  SkincareCompanion
//
//  A persisted snapshot of a generated Routine so a user can look back
//  at "what was I told to do for breakouts last month" without the
//  engine having to be re-run against bag items that may have changed
//  since. Step lists are stored as plain strings for simplicity.
//

import Foundation
import SwiftData

// CloudKit-backed SwiftData requires every non-optional attribute to
// carry a default value at its declaration — see SkincareCompanionApp's
// CloudKit sync section.
@Model
final class SavedRoutine {
    var concernRaws: [String] = []
    var amStepDescriptions: [String] = []
    var pmStepDescriptions: [String] = []
    var warningTitles: [String] = []
    var savedAt: Date = Date.now

    init(routine: Routine) {
        self.concernRaws = routine.concerns.map { $0.rawValue }
        self.amStepDescriptions = routine.amSteps.map { Self.describe($0) }
        self.pmStepDescriptions = routine.pmSteps.map { Self.describe($0) }
        self.warningTitles = routine.warnings.map { $0.title }
        self.savedAt = .now
    }

    var concerns: [SkinConcern] {
        concernRaws.compactMap(SkinConcern.init(rawValue:))
    }

    private static func describe(_ step: RoutineStep) -> String {
        guard step.frequency != .daily else {
            return "\(step.productName) — \(step.category.displayName)"
        }
        return "\(step.productName) — \(step.category.displayName) (\(step.scheduleDescription))"
    }
}
