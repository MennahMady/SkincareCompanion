//
//  RoutineViewModelTests.swift
//  SkincareCompanionTests
//
//  Covers applyOverrides — the "do today instead" / "not today" manual
//  scheduling exception logic, kept as a pure function specifically so
//  it's testable without a SwiftData container.
//

import XCTest
@testable import SkincareCompanion

@MainActor
final class RoutineViewModelTests: XCTestCase {

    let viewModel = RoutineViewModel()

    private func step(_ id: String, frequency: StepFrequency = .daily) -> RoutineStep {
        RoutineStep(bagItemID: id, productName: id, brand: nil, category: .serum, note: nil, frequency: frequency, scheduleDescription: "")
    }

    func test_noOverrides_returnsDueStepsUnchanged() {
        let due = [step("a"), step("b")]
        let result = viewModel.applyOverrides([], toDueSteps: due, allSteps: due, on: .now)
        XCTAssertEqual(Set(result.map { $0.bagItemID }), ["a", "b"])
    }

    func test_skipOverride_removesAStepThatWasNaturallyDue() {
        let today = Date()
        let key = RoutineViewModel.dayKey(for: today)
        let due = [step("a"), step("b")]
        let overrides = [ScheduleOverride(bagItemID: "a", dayKey: key, isDueOverride: false)]

        let result = viewModel.applyOverrides(overrides, toDueSteps: due, allSteps: due, on: today)
        XCTAssertEqual(result.map { $0.bagItemID }, ["b"])
    }

    func test_doTodayOverride_addsAStepThatWasNotNaturallyDue() {
        let today = Date()
        let key = RoutineViewModel.dayKey(for: today)
        let allSteps = [step("a"), step("missed-exfoliant")]
        let due = [step("a")] // "missed-exfoliant" isn't due today by its normal schedule
        let overrides = [ScheduleOverride(bagItemID: "missed-exfoliant", dayKey: key, isDueOverride: true)]

        let result = viewModel.applyOverrides(overrides, toDueSteps: due, allSteps: allSteps, on: today)
        XCTAssertEqual(Set(result.map { $0.bagItemID }), ["a", "missed-exfoliant"])
    }

    func test_overrideOnADifferentDay_doesNotAffectToday() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let due = [step("a")]
        let overrides = [ScheduleOverride(bagItemID: "a", dayKey: RoutineViewModel.dayKey(for: yesterday), isDueOverride: false)]

        let result = viewModel.applyOverrides(overrides, toDueSteps: due, allSteps: due, on: today)
        XCTAssertEqual(result.map { $0.bagItemID }, ["a"], "An override recorded for a different day shouldn't apply to today.")
    }
}
