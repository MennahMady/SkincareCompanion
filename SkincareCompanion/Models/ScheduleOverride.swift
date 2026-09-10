//
//  ScheduleOverride.swift
//  SkincareCompanion
//
//  A per-day, per-product override on top of StepSchedule's normal
//  weekly pattern. Lets someone say "I missed this Tuesday, let me do
//  it today instead" (isDueOverride = true on a day it wouldn't
//  otherwise be due) or "skip this one today" (isDueOverride = false on
//  a day it normally would be due) without changing the product's
//  actual weekly schedule going forward — it's a one-day exception, not
//  a reschedule of the pattern itself.
//

import Foundation
import SwiftData

// CloudKit-backed SwiftData requires every non-optional attribute to
// carry a default value at its declaration — see SkincareCompanionApp's
// CloudKit sync section.
@Model
final class ScheduleOverride {
    var bagItemID: String = ""
    /// "yyyy-MM-dd" in the user's current calendar/timezone — a plain
    /// day key rather than a Date so "is this today's override" is a
    /// simple string match, not a calendar-aware date comparison.
    var dayKey: String = ""
    var isDueOverride: Bool = false

    init(bagItemID: String, dayKey: String, isDueOverride: Bool) {
        self.bagItemID = bagItemID
        self.dayKey = dayKey
        self.isDueOverride = isDueOverride
    }
}
