//
//  SkinTypeQuizTests.swift
//  SkincareCompanionTests
//

import XCTest
@testable import SkincareCompanion

final class SkinTypeQuizTests: XCTestCase {
    func test_shinyOnly_resultsInOily() {
        let result = SkinTypeQuiz.result(for: .init(shinyByMidday: true, tightOrFlakyCheeks: false, easilyIrritated: false))
        XCTAssertEqual(result, .oily)
    }

    func test_tightOrFlakyOnly_resultsInDry() {
        let result = SkinTypeQuiz.result(for: .init(shinyByMidday: false, tightOrFlakyCheeks: true, easilyIrritated: false))
        XCTAssertEqual(result, .dry)
    }

    func test_bothShinyAndFlaky_resultsInCombination() {
        let result = SkinTypeQuiz.result(for: .init(shinyByMidday: true, tightOrFlakyCheeks: true, easilyIrritated: false))
        XCTAssertEqual(result, .combination)
    }

    func test_neither_resultsInNormal() {
        let result = SkinTypeQuiz.result(for: .init(shinyByMidday: false, tightOrFlakyCheeks: false, easilyIrritated: false))
        XCTAssertEqual(result, .normal)
    }

    func test_easilyIrritated_alwaysResultsInSensitive_regardlessOfOtherAnswers() {
        let result = SkinTypeQuiz.result(for: .init(shinyByMidday: true, tightOrFlakyCheeks: true, easilyIrritated: true))
        XCTAssertEqual(result, .sensitive)
    }
}
