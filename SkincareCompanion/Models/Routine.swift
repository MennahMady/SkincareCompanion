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
}

struct RoutineWarning: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
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
}
