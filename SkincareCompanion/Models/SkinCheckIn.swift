//
//  SkinCheckIn.swift
//  SkincareCompanion
//
//  A 1-tap daily "how did my skin feel" log — the lightweight half of
//  closing the feedback loop that photos alone can't (a photo shows what
//  skin looks like; this captures how it felt, which is often how a
//  reaction actually gets noticed first). One entry per calendar day,
//  keyed by dayKey so re-logging the same day updates it instead of
//  duplicating. See SkinCheckInInsights for what this data is used for.
//

import Foundation
import SwiftData

enum SkinFeeling: String, CaseIterable, Codable, Identifiable {
    case great
    case okay
    case irritated

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .great: return "Great"
        case .okay: return "Okay"
        case .irritated: return "Irritated"
        }
    }

    var emoji: String {
        switch self {
        case .great: return "😊"
        case .okay: return "😐"
        case .irritated: return "😣"
        }
    }
}

// CloudKit-backed SwiftData requires every non-optional attribute to
// carry a default value at its declaration — see SkincareCompanionApp's
// CloudKit sync section.
@Model
final class SkinCheckIn {
    /// "yyyy-MM-dd" — one entry per day, see RoutineViewModel.dayKey for
    /// the same formatting convention used elsewhere in the app.
    var dayKey: String = ""
    var date: Date = Date.now
    var feelingRaw: String = SkinFeeling.okay.rawValue
    var note: String = ""

    init(dayKey: String, date: Date = .now, feeling: SkinFeeling, note: String = "") {
        self.dayKey = dayKey
        self.date = date
        self.feelingRaw = feeling.rawValue
        self.note = note
    }

    var feeling: SkinFeeling {
        get { SkinFeeling(rawValue: feelingRaw) ?? .okay }
        set { feelingRaw = newValue.rawValue }
    }
}
