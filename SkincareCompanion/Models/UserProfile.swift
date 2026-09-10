//
//  UserProfile.swift
//  SkincareCompanion
//
//  A single profile, synced across the user's own devices via SwiftData's
//  CloudKit integration (see SkincareCompanionApp) — still no backend
//  account system, just the user's private iCloud database, so this
//  remains single-user rather than becoming multi-account.
//

import Foundation
import SwiftData

enum SkinType: String, CaseIterable, Codable, Identifiable {
    case oily, dry, combination, normal, sensitive
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

// CloudKit-backed SwiftData requires every non-optional attribute to
// carry a default value at its declaration — see SkincareCompanionApp's
// CloudKit sync section.
@Model
final class UserProfile {
    var name: String = ""
    var skinTypeRaw: String?
    var selectedConcernRaws: [String] = []
    var ageRangeRaw: String?
    var acknowledgedDisclaimer: Bool = false
    var onboardingComplete: Bool = false
    var createdAt: Date = Date.now

    /// Local-notification reminder settings — see NotificationScheduler.
    /// Times are stored as full Dates but only their hour/minute
    /// components are used (DatePicker's `.hourAndMinute` component gives
    /// back a Date anchored to today, which is all a repeating daily
    /// reminder needs).
    var remindersEnabled: Bool = false
    var amReminderTime: Date?
    var pmReminderTime: Date?

    /// Optional, off by default, and easy to toggle back off — flags a
    /// small set of actives (retinoids especially) with commonly-cited
    /// pregnancy/nursing caution. See PregnancySafety. Nobody has to set
    /// this to use the app; it only changes anything once it's turned on.
    var isPregnantOrNursing: Bool = false

    init(name: String = "", skinType: SkinType? = nil, selectedConcerns: [SkinConcern] = [], ageRange: AgeRange? = nil) {
        self.name = name
        self.skinTypeRaw = skinType?.rawValue
        self.selectedConcernRaws = selectedConcerns.map { $0.rawValue }
        self.ageRangeRaw = ageRange?.rawValue
        self.acknowledgedDisclaimer = false
        self.onboardingComplete = false
        self.createdAt = .now
        self.remindersEnabled = false
        self.amReminderTime = nil
        self.pmReminderTime = nil
        self.isPregnantOrNursing = false
    }

    var skinType: SkinType? {
        get { skinTypeRaw.flatMap(SkinType.init(rawValue:)) }
        set { skinTypeRaw = newValue?.rawValue }
    }

    var selectedConcerns: [SkinConcern] {
        get { selectedConcernRaws.compactMap(SkinConcern.init(rawValue:)) }
        set { selectedConcernRaws = newValue.map { $0.rawValue } }
    }

    var ageRange: AgeRange? {
        get { ageRangeRaw.flatMap(AgeRange.init(rawValue:)) }
        set { ageRangeRaw = newValue?.rawValue }
    }
}
