//
//  PatchTestAdvisorTests.swift
//  SkincareCompanionTests
//

import XCTest
@testable import SkincareCompanion

final class PatchTestAdvisorTests: XCTestCase {
    private func product(_ name: String, ingredients: String?) -> Product {
        Product(id: name, name: name, brand: nil, ingredientsText: ingredients, category: .serum, imageURL: nil, source: .manual)
    }

    func test_singleActiveProduct_noAdvisory() {
        let items = [(product: product("Retinol Serum", ingredients: "Retinol"), dateAdded: Date.now)]
        XCTAssertNil(PatchTestAdvisor.advisory(items: items))
    }

    func test_twoActiveProductsAddedRecently_triggersAdvisory() {
        let items = [
            (product: product("Retinol Serum", ingredients: "Retinol"), dateAdded: Date.now),
            (product: product("Vitamin C Serum", ingredients: "Ascorbic Acid"), dateAdded: Date.now),
        ]
        let advisory = PatchTestAdvisor.advisory(items: items)
        XCTAssertNotNil(advisory)
        XCTAssertEqual(advisory?.recentActiveProducts.count, 2)
    }

    func test_productsWithNoDetectedActives_dontCount() {
        let items = [
            (product: product("Plain Moisturizer", ingredients: "Water, Glycerin"), dateAdded: Date.now),
            (product: product("Plain Cleanser", ingredients: nil), dateAdded: Date.now),
        ]
        XCTAssertNil(PatchTestAdvisor.advisory(items: items))
    }

    func test_oldActiveProduct_outsideWindow_doesNotCountTowardAdvisory() {
        let old = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let items = [
            (product: product("Retinol Serum", ingredients: "Retinol"), dateAdded: old),
            (product: product("Vitamin C Serum", ingredients: "Ascorbic Acid"), dateAdded: Date.now),
        ]
        XCTAssertNil(PatchTestAdvisor.advisory(items: items, windowDays: 7))
    }
}
