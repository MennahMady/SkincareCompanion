//
//  AgeRange.swift
//  SkincareCompanion
//
//  Age isn't just a profile field — it changes what the app should
//  recommend (commonly-cited skincare guidance is to go gentler on
//  actives like retinoids and strong acids for teens) and, more
//  importantly, whether the app can collect this person's data at all.
//  COPPA (and most App Store review guidance for apps that store any
//  personal information) requires blocking users under 13 rather than
//  quietly onboarding them — see `isEligible` below and how
//  ProfileSetupView uses it to gate onboarding.
//
//  Deliberately a coarse bucket, not a birthdate: it's the minimum
//  granularity the app actually needs (age-appropriate guidance +
//  the under-13 gate), and collecting less personal data than you
//  need is its own good practice, not just a legal minimum.
//

import Foundation

enum AgeRange: String, CaseIterable, Codable, Identifiable {
    case under13
    case teen13to17
    case age18to24
    case age25to34
    case age35to44
    case age45plus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .under13: return "Under 13"
        case .teen13to17: return "13–17"
        case .age18to24: return "18–24"
        case .age25to34: return "25–34"
        case .age35to44: return "35–44"
        case .age45plus: return "45+"
        }
    }

    /// COPPA prohibits collecting personal information from children
    /// under 13 without verified parental consent, which this app has
    /// no mechanism for — so onboarding stops here rather than silently
    /// creating a profile. See ProfileSetupView.
    var isEligible: Bool { self != .under13 }

    /// Commonly-cited skincare guidance is to avoid over-the-counter
    /// retinoids and to use exfoliating acids sparingly (if at all)
    /// during the teen years unless a dermatologist says otherwise —
    /// skin barrier development and higher irritation sensitivity are
    /// the usual reasons cited. Used by RoutineEngine to add a caution
    /// warning and to steer recommendations toward gentler actives.
    var needsActiveCaution: Bool { self == .teen13to17 }
}
