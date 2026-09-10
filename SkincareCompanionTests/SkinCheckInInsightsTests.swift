//
//  SkinCheckInInsightsTests.swift
//  SkincareCompanionTests
//

import XCTest
@testable import SkincareCompanion

final class SkinCheckInInsightsTests: XCTestCase {
    private func product(_ name: String, ingredients: String, category: ProductCategory = .serum) -> Product {
        Product(id: name, name: name, brand: nil, ingredientsText: ingredients, category: category, imageURL: nil, source: .manual)
    }

    func test_fewerThanMinimumIrritatedDays_returnsNoFlags() {
        let dailyRetinoid = product("Retinol", ingredients: "Retinol")
        let checkIns: [(date: Date, feeling: SkinFeeling)] = [
            (date: .now, feeling: .irritated),
            (date: .now, feeling: .irritated),
        ]
        // Only 2 irritated days, default minimum is 3.
        XCTAssertTrue(SkinCheckInInsights.flareFlags(checkIns: checkIns, bag: [dailyRetinoid]).isEmpty)
    }

    func test_dailyProduct_neverFlagged_sinceItsNotDisproportionate() {
        // A daily-use product is "due" every day regardless of feeling,
        // so its irritated-day rate can never exceed its overall
        // baseline rate — it should never surface as a flag.
        let dailyCleanser = product("Gentle Cleanser", ingredients: "Water, Glycerin", category: .cleanser)
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let today = Date.now
        let checkIns: [(date: Date, feeling: SkinFeeling)] = (0..<5).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            return (date: date, feeling: offset < 3 ? .irritated : .great)
        }
        let flags = SkinCheckInInsights.flareFlags(checkIns: checkIns, bag: [dailyCleanser], calendar: calendar)
        XCTAssertTrue(flags.isEmpty)
    }

    func test_emptyBag_returnsNoFlags() {
        let checkIns: [(date: Date, feeling: SkinFeeling)] = [
            (date: .now, feeling: .irritated),
            (date: .now, feeling: .irritated),
            (date: .now, feeling: .irritated),
        ]
        XCTAssertTrue(SkinCheckInInsights.flareFlags(checkIns: checkIns, bag: []).isEmpty)
    }
}
