//
//  RoutineViewModel.swift
//  SkincareCompanion
//
//  Bridges the SwiftData-backed bag/profile into RoutineEngine (a pure,
//  storage-agnostic type) and exposes the result to RoutineView.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class RoutineViewModel: ObservableObject {
    @Published private(set) var routine: Routine?
    @Published var selectedConcerns: Set<SkinConcern> = []

    private let engine = RoutineEngine()

    func generate(bagItems: [BagItem]) {
        let products = bagItems.map { $0.asProduct }
        let concerns = SkinConcern.allCases.filter { selectedConcerns.contains($0) }
        routine = engine.generateRoutine(bag: products, concerns: concerns)
    }

    func toggleConcern(_ concern: SkinConcern) {
        if selectedConcerns.contains(concern) {
            selectedConcerns.remove(concern)
        } else {
            selectedConcerns.insert(concern)
        }
    }
}
