//
//  UserProfile.swift
//  SkincareCompanion
//
//  A single local profile. The app is single-user/on-device for now
//  (no backend account system), but modeling it as a persisted entity
//  keeps the door open for iCloud sync (SwiftData + CloudKit) later
//  without changing call sites.
//

import Foundation
import SwiftData

enum SkinType: String, CaseIterable, Codable, Identifiable {
    case oily, dry, combination, normal, sensitive
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

@Model
final class UserProfile {
    var name: String
    var skinTypeRaw: String?
    var selectedConcernRaws: [String]
    var onboardingComplete: Bool
    var createdAt: Date

    init(name: String = "", skinType: SkinType? = nil, selectedConcerns: [SkinConcern] = []) {
        self.name = name
        self.skinTypeRaw = skinType?.rawValue
        self.selectedConcernRaws = selectedConcerns.map { $0.rawValue }
        self.onboardingComplete = false
        self.createdAt = .now
    }

    var skinType: SkinType? {
        get { skinTypeRaw.flatMap(SkinType.init(rawValue:)) }
        set { skinTypeRaw = newValue?.rawValue }
    }

    var selectedConcerns: [SkinConcern] {
        get { selectedConcernRaws.compactMap(SkinConcern.init(rawValue:)) }
        set { selectedConcernRaws = newValue.map { $0.rawValue } }
    }
}
