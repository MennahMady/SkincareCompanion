//
//  CuratedProductStoreTests.swift
//  SkincareCompanionTests
//
//  Note: these tests read the bundled CuratedProducts.json via
//  Bundle.main, which resolves to the app's bundle only when the test
//  target runs "hosted" in the app (Xcode's default when you create a
//  Unit Testing Bundle target with the app selected as Host
//  Application) — the setup this project's README walks through.
//

import XCTest
@testable import SkincareCompanion

final class CuratedProductStoreTests: XCTestCase {

    func test_bundledDatasetLoads_withMultipleProducts() {
        XCTAssertGreaterThan(CuratedProductStore.all.count, 10, "Expected the bundled starter dataset to load several products")
    }

    func test_search_matchesByBrand_caseInsensitive() {
        let results = CuratedProductStore.search(matching: "glow recipe")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.brand?.lowercased() == "glow recipe" })
    }

    func test_search_matchesByProductName() {
        let results = CuratedProductStore.search(matching: "niacinamide")
        XCTAssertFalse(results.isEmpty)
    }

    func test_search_emptyQuery_returnsNothing() {
        XCTAssertTrue(CuratedProductStore.search(matching: "").isEmpty)
    }

    func test_curatedProducts_haveDetectableActives() {
        let niacinamideProducts = CuratedProductStore.search(matching: "niacinamide")
        XCTAssertTrue(niacinamideProducts.contains { $0.detectedActives.contains(.niacinamide) })
    }
}
