//
//  RoutineCompletion.swift
//  SkincareCompanion
//
//  Marks "I actually did my AM/PM routine" for a given day — the app
//  otherwise only knows what's *scheduled*, never what actually
//  happened, which is what a real adherence streak needs. One record
//  per (day, session); see RoutineAdherence for the streak/heatmap math
//  built on top of these.
//

import Foundation
import SwiftData

// CloudKit-backed SwiftData requires every non-optional attribute to
// carry a default value at its declaration — see SkincareCompanionApp's
// CloudKit sync section.
@Model
final class RoutineCompletion {
    /// "yyyy-MM-dd" — see RoutineViewModel.dayKey.
    var dayKey: String = ""
    /// "am" or "pm" — deliberately a plain string rather than reusing
    /// RoutineSession (which also has a "both" case that doesn't apply
    /// to a single completion record).
    var sessionRaw: String = ""
    var completedAt: Date = Date.now

    init(dayKey: String, sessionRaw: String, completedAt: Date = .now) {
        self.dayKey = dayKey
        self.sessionRaw = sessionRaw
        self.completedAt = completedAt
    }
}
