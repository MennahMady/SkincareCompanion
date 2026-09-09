//
//  RoutineEngineTests.swift
//  SkincareCompanionTests
//

import XCTest
@testable import SkincareCompanion

final class RoutineEngineTests: XCTestCase {

    let engine = RoutineEngine()

    private func product(_ name: String, category: ProductCategory, ingredients: String? = nil) -> Product {
        Product(id: name, name: name, brand: nil, ingredientsText: ingredients, category: category, imageURL: nil, source: .manual)
    }

    func test_foundationalItems_alwaysIncluded_regardlessOfConcerns() {
        let cleanser = product("Gentle Cleanser", category: .cleanser)
        let moisturizer = product("Basic Moisturizer", category: .moisturizer)
        let routine = engine.generateRoutine(bag: [cleanser, moisturizer], concerns: [.breakouts])

        XCTAssertTrue(routine.amSteps.contains { $0.productName == "Gentle Cleanser" })
        XCTAssertTrue(routine.pmSteps.contains { $0.productName == "Gentle Cleanser" })
        XCTAssertTrue(routine.amSteps.contains { $0.productName == "Basic Moisturizer" })
    }

    func test_sunscreen_onlyAppearsInMorning() {
        let spf = product("Daily SPF", category: .sunscreen, ingredients: "Zinc Oxide, Water")
        let routine = engine.generateRoutine(bag: [spf], concerns: [])

        XCTAssertTrue(routine.amSteps.contains { $0.productName == "Daily SPF" })
        XCTAssertFalse(routine.pmSteps.contains { $0.productName == "Daily SPF" })
    }

    func test_retinoid_onlyAppearsInEvening() {
        let retinol = product("Retinol Serum", category: .serum, ingredients: "Retinol, Squalane")
        let routine = engine.generateRoutine(bag: [retinol], concerns: [.fineLines])

        XCTAssertTrue(routine.pmSteps.contains { $0.productName == "Retinol Serum" })
        XCTAssertFalse(routine.amSteps.contains { $0.productName == "Retinol Serum" })
    }

    func test_stepsWithinSession_areOrderedByApplicationOrder() {
        let cleanser = product("Cleanser", category: .cleanser)
        let moisturizer = product("Moisturizer", category: .moisturizer)
        let serum = product("Niacinamide Serum", category: .serum, ingredients: "Niacinamide")
        let routine = engine.generateRoutine(bag: [moisturizer, serum, cleanser], concerns: [.oiliness])

        let amCategories = routine.amSteps.map { $0.category }
        XCTAssertEqual(amCategories, amCategories.sorted { $0.applicationOrder < $1.applicationOrder })
        XCTAssertEqual(amCategories.first, .cleanser)
    }

    func test_conflictWarning_raisedForRetinoidAndAHAInSameSession() {
        // Both are PM-leaning actives, so both land in the same evening
        // session and should trigger the conflict rule.
        let retinol = product("Retinol Serum", category: .serum, ingredients: "Retinol")
        let glycolic = product("Glycolic Toner", category: .toner, ingredients: "Glycolic Acid")
        let routine = engine.generateRoutine(bag: [retinol, glycolic], concerns: [.unevenTexture, .fineLines])

        XCTAssertTrue(routine.warnings.contains { $0.title.contains("Retinoid + AHA") })
    }

    func test_noConflictWarning_whenActivesAreInDifferentSessions() {
        let vitaminC = product("Vitamin C Serum", category: .serum, ingredients: "Ascorbic Acid")
        let retinol = product("Retinol Serum", category: .serum, ingredients: "Retinol")
        let routine = engine.generateRoutine(bag: [vitaminC, retinol], concerns: [.dullness, .fineLines])

        XCTAssertTrue(routine.amSteps.contains { $0.productName == "Vitamin C Serum" })
        XCTAssertTrue(routine.pmSteps.contains { $0.productName == "Retinol Serum" })
        XCTAssertFalse(routine.warnings.contains { $0.title.contains("Vitamin C") })
    }

    func test_missingSunscreenWarning_whenActivesPresentButNoSPFInBag() {
        let retinol = product("Retinol Serum", category: .serum, ingredients: "Retinol")
        let routine = engine.generateRoutine(bag: [retinol], concerns: [.fineLines])

        XCTAssertTrue(routine.warnings.contains { $0.title == "No sunscreen in your bag" })
    }

    func test_recommendation_generatedForUnaddressedConcern() {
        let cleanser = product("Cleanser", category: .cleanser)
        let routine = engine.generateRoutine(bag: [cleanser], concerns: [.hyperpigmentation])

        XCTAssertTrue(routine.recommendations.contains { $0.concern == .hyperpigmentation })
    }

    func test_noRecommendation_whenConcernAlreadyAddressed() {
        let azelaic = product("Azelaic Acid Serum", category: .serum, ingredients: "Azelaic Acid")
        let routine = engine.generateRoutine(bag: [azelaic], concerns: [.hyperpigmentation])

        XCTAssertFalse(routine.recommendations.contains { $0.concern == .hyperpigmentation })
    }

    func test_emptyConcerns_includesEntireBagWithNoFiltering() {
        let randomSerum = product("Random Serum", category: .serum, ingredients: "Water")
        let routine = engine.generateRoutine(bag: [randomSerum], concerns: [])

        XCTAssertTrue(routine.amSteps.contains { $0.productName == "Random Serum" } ||
                      routine.pmSteps.contains { $0.productName == "Random Serum" })
    }
}
