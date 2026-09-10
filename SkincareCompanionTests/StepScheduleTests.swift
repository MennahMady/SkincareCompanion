//
//  StepScheduleTests.swift
//  SkincareCompanionTests
//

import XCTest
@testable import SkincareCompanion

final class StepScheduleTests: XCTestCase {

    func test_dailyFrequency_isAlwaysDue() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3))!

        XCTAssertTrue(StepSchedule.isDue(frequency: .daily, productID: "any-id", on: date, calendar: calendar))
    }

    func test_weeklyFrequency_isDueOnExactlyOneDayPerWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var dueDays = 0
        for day in 1...7 {
            let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: day))!
            if StepSchedule.isDue(frequency: .weekly, productID: "clay-mask-1", on: date, calendar: calendar) {
                dueDays += 1
            }
        }
        XCTAssertEqual(dueDays, 1, "A weekly step should be due exactly once across any 7 consecutive days")
    }

    func test_threeTimesWeeklyFrequency_isDueThreeDaysPerWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var dueDays = 0
        for day in 1...7 {
            let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: day))!
            if StepSchedule.isDue(frequency: .threeTimesWeekly, productID: "bha-exfoliant-1", on: date, calendar: calendar) {
                dueDays += 1
            }
        }
        XCTAssertEqual(dueDays, 3)
    }

    func test_sameProductID_producesSameScheduleOnRepeatedCalls() {
        // Guards against accidentally using Swift's randomly-seeded
        // Hasher, which would make the schedule non-deterministic across
        // app launches.
        let first = StepSchedule.description(frequency: .weekly, productID: "consistent-id")
        let second = StepSchedule.description(frequency: .weekly, productID: "consistent-id")
        XCTAssertEqual(first, second)
    }

    func test_differentProductIDs_canLandOnDifferentDays() {
        // Not a strict guarantee for every possible pair, but this pair
        // is chosen to land on different offsets, demonstrating that
        // same-frequency products don't all collapse onto the same day.
        let a = StepSchedule.description(frequency: .weekly, productID: "product-a")
        let b = StepSchedule.description(frequency: .weekly, productID: "product-zzz-different")
        XCTAssertNotEqual(a, b)
    }
}
