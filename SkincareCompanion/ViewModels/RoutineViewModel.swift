//
//  RoutineViewModel.swift
//  SkincareCompanion
//
//  Bridges the SwiftData-backed bag/profile into RoutineEngine (a pure,
//  storage-agnostic type) and exposes the result to RoutineView.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class RoutineViewModel: ObservableObject {
    @Published private(set) var routine: Routine?
    @Published var selectedConcerns: Set<SkinConcern> = []

    private let engine = RoutineEngine()

    func generate(bagItems: [BagItem], ageRange: AgeRange? = nil, personalAllergens: [String] = [], isPregnantOrNursing: Bool = false) {
        let products = bagItems.map { $0.asProduct }
        let concerns = SkinConcern.allCases.filter { selectedConcerns.contains($0) }
        routine = engine.generateRoutine(bag: products, concerns: concerns, ageRange: ageRange, personalAllergens: personalAllergens, isPregnantOrNursing: isPregnantOrNursing)
    }

    func toggleConcern(_ concern: SkinConcern) {
        if selectedConcerns.contains(concern) {
            selectedConcerns.remove(concern)
        } else {
            selectedConcerns.insert(concern)
        }
    }

    /// "yyyy-MM-dd" key ScheduleOverride rows are stored/looked-up by —
    /// a plain string so a lookup is an exact match, not a calendar
    /// comparison.
    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter.string(from: date)
    }

    /// Combines StepSchedule's normal "is this due today" result with
    /// any one-day manual overrides for that date: a step naturally due
    /// today can be hidden (someone marked "not today"), and a step NOT
    /// naturally due today can be pulled in (someone marked "do today
    /// instead" after missing its usual day). `allSteps` is the full,
    /// unfiltered step list for the session so an overridden-in step can
    /// actually be found.
    func applyOverrides(_ overrides: [ScheduleOverride], toDueSteps dueSteps: [RoutineStep], allSteps: [RoutineStep], on date: Date) -> [RoutineStep] {
        let key = Self.dayKey(for: date)
        var overrideByID: [String: Bool] = [:]
        for override in overrides where override.dayKey == key {
            overrideByID[override.bagItemID] = override.isDueOverride
        }
        guard !overrideByID.isEmpty else { return dueSteps }

        var result = dueSteps.filter { overrideByID[$0.bagItemID] != false }
        let resultIDs = Set(result.map { $0.bagItemID })
        for step in allSteps where overrideByID[step.bagItemID] == true && !resultIDs.contains(step.bagItemID) {
            result.append(step)
        }
        return result
    }
}
