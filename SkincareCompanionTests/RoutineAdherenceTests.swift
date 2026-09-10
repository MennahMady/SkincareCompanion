//
//  RoutineAdherenceTests.swift
//  SkincareCompanionTests
//

import XCTest
@testable import SkincareCompanion

final class RoutineAdherenceTests: XCTestCase {
    private func completion(daysAgo: Int, session: String, from today: Date = .now) -> RoutineCompletion {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
        return RoutineCompletion(dayKey: RoutineViewModel.dayKey(for: date), sessionRaw: session)
    }

    func test_noCompletions_streakIsZero() {
        XCTAssertEqual(RoutineAdherence.currentStreak(completions: []), 0)
    }

    func test_consecutiveDaysEndingToday_countTowardStreak() {
        let completions = [
            completion(daysAgo: 0, session: "am"),
            completion(daysAgo: 1, session: "am"),
            completion(daysAgo: 2, session: "pm"),
        ]
        XCTAssertEqual(RoutineAdherence.currentStreak(completions: completions), 3)
    }

    func test_gapBreaksStreak() {
        let completions = [
            completion(daysAgo: 0, session: "am"),
            // daysAgo: 1 missing — gap
            completion(daysAgo: 2, session: "am"),
        ]
        XCTAssertEqual(RoutineAdherence.currentStreak(completions: completions), 1)
    }

    func test_todayNotYetMarked_doesNotZeroOutStreak() {
        let completions = [
            completion(daysAgo: 1, session: "am"),
            completion(daysAgo: 2, session: "am"),
        ]
        XCTAssertEqual(RoutineAdherence.currentStreak(completions: completions), 2)
    }

    func test_recentDays_marksFollowedWhenEitherSessionDone() {
        let today = Date()
        let completions = [completion(daysAgo: 0, session: "pm", from: today)]
        let days = RoutineAdherence.recentDays(completions: completions, today: today, days: 3)
        XCTAssertEqual(days.count, 3)
        XCTAssertTrue(days.last!.followed)
        XCTAssertFalse(days.last!.didAM)
        XCTAssertTrue(days.last!.didPM)
    }
}
