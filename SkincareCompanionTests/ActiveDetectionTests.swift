//
//  ActiveDetectionTests.swift
//  SkincareCompanionTests
//

import XCTest
@testable import SkincareCompanion

final class ActiveDetectionTests: XCTestCase {

    func test_detectsRetinolFromIngredientsText() {
        let actives = Active.detect(in: "Water, Retinol, Squalane, Tocopherol")
        XCTAssertTrue(actives.contains(.retinoid))
    }

    func test_detectsMultipleActives() {
        let actives = Active.detect(in: "Aqua, Niacinamide, Zinc PCA, Hyaluronic Acid")
        XCTAssertTrue(actives.contains(.niacinamide))
        XCTAssertTrue(actives.contains(.hyaluronicAcid))
    }

    func test_caseInsensitive() {
        let actives = Active.detect(in: "SALICYLIC ACID, Water")
        XCTAssertTrue(actives.contains(.salicylicAcid))
    }

    func test_emptyOrNilIngredients_returnsEmptySet() {
        XCTAssertTrue(Active.detect(in: nil).isEmpty)
        XCTAssertTrue(Active.detect(in: "").isEmpty)
    }

    func test_noFalsePositiveOnUnrelatedIngredients() {
        let actives = Active.detect(in: "Aqua, Glycerin, Phenoxyethanol")
        XCTAssertFalse(actives.contains(.retinoid))
        XCTAssertFalse(actives.contains(.vitaminC))
        XCTAssertTrue(actives.contains(.glycerin))
    }

    func test_conflictRules_flagRetinoidAndBHA() {
        let conflicts = IngredientConflictRules.conflicts(among: [.retinoid, .salicylicAcid])
        XCTAssertFalse(conflicts.isEmpty)
    }

    func test_conflictRules_noFlagForCompatibleActives() {
        let conflicts = IngredientConflictRules.conflicts(among: [.hyaluronicAcid, .niacinamide])
        XCTAssertTrue(conflicts.isEmpty)
    }
}
