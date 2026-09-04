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

@Model
final class SavedRoutine {
    var concernRaws: [String]
    var amStepDescriptions: [String]
    var pmStepDescriptions: [String]
    var warningTitles: [String]
    var savedAt: Date

    init(routine: Routine) {
        self.concernRaws = routine.concerns.map { $0.rawValue }
        self.amStepDescriptions = routine.amSteps.map { "\($0.productName) — \($0.category.displayName)" }
        self.pmStepDescriptions = routine.pmSteps.map { "\($0.productName) — \($0.category.displayName)" }
        self.warningTitles = routine.warnings.map { $0.title }
        self.savedAt = .now
    }

    var concerns: [SkinConcern] {
        concernRaws.compactMap(SkinConcern.init(rawValue:))
    }
}
