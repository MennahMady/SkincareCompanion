//
//  SkinTypeSuitabilityTests.swift
//  SkincareCompanionTests
//

import XCTest
@testable import SkincareCompanion

final class SkinTypeSuitabilityTests: XCTestCase {

    func test_richOilBasedProduct_excludesOily() {
        let result = SkinTypeSuitability.infer(category: .faceOil, ingredientsText: "Squalane, Jojoba Oil", detectedActives: [.squalane])
        XCTAssertFalse(result.contains(.oily))
    }

    func test_harshActive_excludesSensitive() {
        let result = SkinTypeSuitability.infer(category: .exfoliant, ingredientsText: "Glycolic Acid 10%, Water", detectedActives: [.glycolicAcid])
        XCTAssertFalse(result.contains(.sensitive))
    }

    func test_gentleBarrierIngredients_includeSensitive() {
        let result = SkinTypeSuitability.infer(category: .moisturizer, ingredientsText: "Centella Asiatica Extract, Ceramide NP, Glycerin", detectedActives: [.centella, .ceramides, .glycerin])
        XCTAssertTrue(result.contains(.sensitive))
    }

    func test_emptyIngredients_suitsEveryType() {
        let result = SkinTypeSuitability.infer(category: .cleanser, ingredientsText: nil, detectedActives: [])
        XCTAssertEqual(Set(result), Set(SkinType.allCases))
    }
}
