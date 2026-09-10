//
//  ProductCategoryTests.swift
//  SkincareCompanionTests
//

import XCTest
@testable import SkincareCompanion

final class ProductCategoryTests: XCTestCase {

    func test_toner_hasALayeringApplicationTip() {
        // The concrete thing that prompted this feature: a toner should
        // mention it's commonly layered, not just "used."
        let tip = ProductCategory.toner.applicationTip
        XCTAssertNotNil(tip)
        XCTAssertTrue(tip!.lowercased().contains("layer"))
    }

    func test_everyCategoryExceptOther_hasAnApplicationTip() {
        for category in ProductCategory.allCases where category != .other {
            XCTAssertNotNil(category.applicationTip, "\(category) should have an application tip")
        }
    }
}
