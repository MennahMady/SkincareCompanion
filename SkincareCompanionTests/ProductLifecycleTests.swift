//
//  ProductLifecycleTests.swift
//  SkincareCompanionTests
//

import XCTest
@testable import SkincareCompanion

final class ProductLifecycleTests: XCTestCase {
    private let calendar = Calendar.current

    func test_noOpenedDate_returnsNilExpiry() {
        XCTAssertNil(ProductLifecycle.estimatedExpiryDate(openedDate: nil, paoMonths: 12))
    }

    func test_noPaoMonths_returnsNilExpiry() {
        XCTAssertNil(ProductLifecycle.estimatedExpiryDate(openedDate: .now, paoMonths: nil))
    }

    func test_expiryIsOpenedDatePlusPaoMonths() {
        let opened = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let expiry = ProductLifecycle.estimatedExpiryDate(openedDate: opened, paoMonths: 6, calendar: calendar)
        let expected = calendar.date(from: DateComponents(year: 2025, month: 7, day: 1))!
        XCTAssertEqual(expiry, expected)
    }

    func test_isLikelyExpired_trueWhenExpiryInThePast() {
        let opened = calendar.date(byAdding: .month, value: -13, to: .now)!
        XCTAssertTrue(ProductLifecycle.isLikelyExpired(openedDate: opened, paoMonths: 12, calendar: calendar))
    }

    func test_isLikelyExpired_falseWhenExpiryInTheFuture() {
        let opened = Date.now
        XCTAssertFalse(ProductLifecycle.isLikelyExpired(openedDate: opened, paoMonths: 12, calendar: calendar))
    }

    func test_isExpiringSoon_trueWithinWindow() {
        // Constructed so opened + 12 months lands 5 days from now,
        // using the same calendar arithmetic the code under test uses
        // (rather than approximating months as a day count, which
        // drifts depending on which months are in the range).
        let targetExpiry = calendar.date(byAdding: .day, value: 5, to: .now)!
        let opened = calendar.date(byAdding: .month, value: -12, to: targetExpiry)!
        XCTAssertTrue(ProductLifecycle.isExpiringSoon(openedDate: opened, paoMonths: 12, withinDays: 14, calendar: calendar))
    }

    func test_isExpiringSoon_falseWhenFarInFuture() {
        let opened = Date.now
        XCTAssertFalse(ProductLifecycle.isExpiringSoon(openedDate: opened, paoMonths: 12, withinDays: 14, calendar: calendar))
    }
}
