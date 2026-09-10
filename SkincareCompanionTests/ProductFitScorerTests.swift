//
//  ProductFitScorerTests.swift
//  SkincareCompanionTests
//

import XCTest
@testable import SkincareCompanion

final class ProductFitScorerTests: XCTestCase {
    private func product(_ name: String, ingredients: String?, category: ProductCategory = .serum) -> Product {
        Product(id: name, name: name, brand: nil, ingredientsText: ingredients, category: category, imageURL: nil, source: .manual)
    }

    func test_containsPersonalAllergen_isAlwaysAvoid_regardlessOfOtherFactors() {
        let p = product("Oat Cleanser", ingredients: "Water, Colloidal Oatmeal", category: .cleanser)
        let context = ProductFitContext(personalAllergens: ["oatmeal"])
        let fit = ProductFitScorer.score(product: p, context: context)
        XCTAssertEqual(fit.verdict, .avoid)
        XCTAssertLessThanOrEqual(fit.percentage, 15)
    }

    func test_pregnantAndRetinoid_isAvoid() {
        let p = product("Retinol Serum", ingredients: "Retinol")
        let context = ProductFitContext(isPregnantOrNursing: true)
        let fit = ProductFitScorer.score(product: p, context: context)
        XCTAssertEqual(fit.verdict, .avoid)
    }

    func test_pregnantAndSalicylicAcid_isCautionNotHardAvoid() {
        let p = product("BHA Toner", ingredients: "Salicylic Acid", category: .toner)
        let context = ProductFitContext(isPregnantOrNursing: true)
        let fit = ProductFitScorer.score(product: p, context: context)
        XCTAssertNotEqual(fit.verdict, .avoid)
        XCTAssertLessThan(fit.percentage, 50) // still penalized
    }

    func test_matchingConcern_boostsScore() {
        let p = product("Niacinamide Serum", ingredients: "Niacinamide")
        let withConcern = ProductFitScorer.score(product: p, context: ProductFitContext(concerns: [.breakouts]))
        let withoutConcern = ProductFitScorer.score(product: p, context: ProductFitContext())
        XCTAssertGreaterThan(withConcern.percentage, withoutConcern.percentage)
    }

    func test_newConflictWithBagActives_lowersScore() {
        let p = product("Retinol Serum", ingredients: "Retinol")
        let context = ProductFitContext(currentBagActives: [.glycolicAcid])
        let fit = ProductFitScorer.score(product: p, context: context)
        XCTAssertTrue(fit.reasons.contains { $0.localizedCaseInsensitiveContains("retinoid") || $0.localizedCaseInsensitiveContains("aha") })
        XCTAssertLessThan(fit.percentage, 50)
    }

    func test_noAllergensOrConcernsOrConflicts_isNeutral() {
        let p = product("Plain Moisturizer", ingredients: "Water, Glycerin", category: .moisturizer)
        let fit = ProductFitScorer.score(product: p, context: ProductFitContext())
        XCTAssertEqual(fit.percentage, 50)
        XCTAssertFalse(fit.reasons.isEmpty)
    }
}
