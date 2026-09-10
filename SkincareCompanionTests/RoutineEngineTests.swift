//
//  RoutineEngineTests.swift
//  SkincareCompanionTests
//

import XCTest
@testable import SkincareCompanion

final class RoutineEngineTests: XCTestCase {

    let engine = RoutineEngine()

    private func product(_ name: String, category: ProductCategory, ingredients: String? = nil) -> Product {
        Product(id: name, name: name, brand: nil, ingredientsText: ingredients, category: category, imageURL: nil, source: .manual)
    }

    func test_foundationalItems_alwaysIncluded_regardlessOfConcerns() {
        let cleanser = product("Gentle Cleanser", category: .cleanser)
        let moisturizer = product("Basic Moisturizer", category: .moisturizer)
        let routine = engine.generateRoutine(bag: [cleanser, moisturizer], concerns: [.breakouts])

        XCTAssertTrue(routine.amSteps.contains { $0.productName == "Gentle Cleanser" })
        XCTAssertTrue(routine.pmSteps.contains { $0.productName == "Gentle Cleanser" })
        XCTAssertTrue(routine.amSteps.contains { $0.productName == "Basic Moisturizer" })
    }

    func test_sunscreen_onlyAppearsInMorning() {
        let spf = product("Daily SPF", category: .sunscreen, ingredients: "Zinc Oxide, Water")
        let routine = engine.generateRoutine(bag: [spf], concerns: [])

        XCTAssertTrue(routine.amSteps.contains { $0.productName == "Daily SPF" })
        XCTAssertFalse(routine.pmSteps.contains { $0.productName == "Daily SPF" })
    }

    func test_retinoid_onlyAppearsInEvening() {
        let retinol = product("Retinol Serum", category: .serum, ingredients: "Retinol, Squalane")
        let routine = engine.generateRoutine(bag: [retinol], concerns: [.fineLines])

        XCTAssertTrue(routine.pmSteps.contains { $0.productName == "Retinol Serum" })
        XCTAssertFalse(routine.amSteps.contains { $0.productName == "Retinol Serum" })
    }

    func test_stepsWithinSession_areOrderedByApplicationOrder() {
        let cleanser = product("Cleanser", category: .cleanser)
        let moisturizer = product("Moisturizer", category: .moisturizer)
        let serum = product("Niacinamide Serum", category: .serum, ingredients: "Niacinamide")
        let routine = engine.generateRoutine(bag: [moisturizer, serum, cleanser], concerns: [.oiliness])

        let amCategories = routine.amSteps.map { $0.category }
        XCTAssertEqual(amCategories, amCategories.sorted { $0.applicationOrder < $1.applicationOrder })
        XCTAssertEqual(amCategories.first, .cleanser)
    }

    func test_conflictWarning_raisedForRetinoidAndAHAInSameSession() {
        // Both are PM-leaning actives, so both land in the same evening
        // session and should trigger the conflict rule.
        let retinol = product("Retinol Serum", category: .serum, ingredients: "Retinol")
        let glycolic = product("Glycolic Toner", category: .toner, ingredients: "Glycolic Acid")
        let routine = engine.generateRoutine(bag: [retinol, glycolic], concerns: [.unevenTexture, .fineLines])

        XCTAssertTrue(routine.warnings.contains { $0.title.contains("Retinoid + AHA") })
    }

    func test_conflictWarnings_dedupedWhenTwoRulesRenderTheSameText() {
        // Retinoid+glycolicAcid and retinoid+lacticAcid are separate
        // ConflictRule entries but both render as "Retinoid + AHA" since
        // glycolic and lactic are both AHAs. Owning a retinoid plus both
        // acids used to trip both rules and show the identical warning
        // card twice — this locks in the fix that collapses them to one.
        let retinol = product("Retinol Serum", category: .serum, ingredients: "Retinol")
        let glycolic = product("Glycolic Toner", category: .toner, ingredients: "Glycolic Acid")
        let lactic = product("Lactic Acid Treatment", category: .exfoliant, ingredients: "Lactic Acid")
        let routine = engine.generateRoutine(bag: [retinol, glycolic, lactic], concerns: [.unevenTexture, .fineLines])

        let ahaWarnings = routine.warnings.filter { $0.title.contains("Retinoid + AHA") }
        XCTAssertEqual(ahaWarnings.count, 1)
    }

    func test_conflictWarning_isPinnedToTheSpecificProductsThatCausedIt() {
        // relatedBagItemIDs is what lets the UI show a warning icon on
        // the exact product row instead of a general upfront list — this
        // locks in that it actually names the right two products and
        // not, say, every item in the session.
        let retinol = product("Retinol Serum", category: .serum, ingredients: "Retinol")
        let glycolic = product("Glycolic Toner", category: .toner, ingredients: "Glycolic Acid")
        let plainMoisturizer = product("Plain Moisturizer", category: .moisturizer)
        let routine = engine.generateRoutine(bag: [retinol, glycolic, plainMoisturizer], concerns: [.unevenTexture, .fineLines])

        guard let warning = routine.warnings.first(where: { $0.title.contains("Retinoid + AHA") }) else {
            return XCTFail("Expected a Retinoid + AHA warning")
        }
        XCTAssertEqual(Set(warning.relatedBagItemIDs), Set(["Retinol Serum", "Glycolic Toner"]))
    }

    func test_noConflictWarning_whenActivesAreInDifferentSessions() {
        let vitaminC = product("Vitamin C Serum", category: .serum, ingredients: "Ascorbic Acid")
        let retinol = product("Retinol Serum", category: .serum, ingredients: "Retinol")
        let routine = engine.generateRoutine(bag: [vitaminC, retinol], concerns: [.dullness, .fineLines])

        XCTAssertTrue(routine.amSteps.contains { $0.productName == "Vitamin C Serum" })
        XCTAssertTrue(routine.pmSteps.contains { $0.productName == "Retinol Serum" })
        XCTAssertFalse(routine.warnings.contains { $0.title.contains("Vitamin C") })
    }

    func test_missingSunscreenWarning_whenActivesPresentButNoSPFInBag() {
        let retinol = product("Retinol Serum", category: .serum, ingredients: "Retinol")
        let routine = engine.generateRoutine(bag: [retinol], concerns: [.fineLines])

        XCTAssertTrue(routine.warnings.contains { $0.title == "No sunscreen in your bag" })
    }

    func test_recommendation_generatedForUnaddressedConcern() {
        let cleanser = product("Cleanser", category: .cleanser)
        let routine = engine.generateRoutine(bag: [cleanser], concerns: [.hyperpigmentation])

        XCTAssertTrue(routine.recommendations.contains { $0.concern == .hyperpigmentation })
    }

    func test_noRecommendation_whenConcernAlreadyAddressed() {
        let azelaic = product("Azelaic Acid Serum", category: .serum, ingredients: "Azelaic Acid")
        let routine = engine.generateRoutine(bag: [azelaic], concerns: [.hyperpigmentation])

        XCTAssertFalse(routine.recommendations.contains { $0.concern == .hyperpigmentation })
    }

    func test_emptyConcerns_includesEntireBagWithNoFiltering() {
        let randomSerum = product("Random Serum", category: .serum, ingredients: "Water")
        let routine = engine.generateRoutine(bag: [randomSerum], concerns: [])

        XCTAssertTrue(routine.amSteps.contains { $0.productName == "Random Serum" } ||
                      routine.pmSteps.contains { $0.productName == "Random Serum" })
    }

    func test_multipleCleansers_onlyOneMakesItIntoTheRoutine() {
        let cleanserA = product("Cleanser A", category: .cleanser)
        let cleanserB = product("Cleanser B", category: .cleanser)
        let routine = engine.generateRoutine(bag: [cleanserA, cleanserB], concerns: [])

        let cleanserSteps = routine.amSteps.filter { $0.category == .cleanser }
        XCTAssertEqual(cleanserSteps.count, 1, "Only one cleanser should appear in a single session, even with two in the bag")
    }

    func test_maskFrequency_isWeekly_notDaily() {
        let mask = product("Clay Mask", category: .mask)
        let routine = engine.generateRoutine(bag: [mask], concerns: [])

        let step = (routine.amSteps + routine.pmSteps).first { $0.productName == "Clay Mask" }
        XCTAssertEqual(step?.frequency, .weekly)
    }

    func test_exfoliantFrequency_isThreeTimesWeekly_notDaily() {
        let exfoliant = product("BHA Exfoliant", category: .exfoliant, ingredients: "Salicylic Acid")
        let routine = engine.generateRoutine(bag: [exfoliant], concerns: [])

        let step = (routine.amSteps + routine.pmSteps).first { $0.productName == "BHA Exfoliant" }
        XCTAssertEqual(step?.frequency, .threeTimesWeekly)
    }

    func test_twoNonDailyProductsThatWouldHashToTheSamePattern_getSpreadAcrossDifferentDays() {
        // These two specific names are a known real collision: both
        // independently hash (via StepSchedule's djb2-based offset) to
        // the same "3x a week" pattern, which used to mean both landed
        // on the exact same three days and stacked with every daily
        // step — a big part of why some days had 7 steps at once.
        let bha = product("BHA Exfoliant", category: .exfoliant, ingredients: "Salicylic Acid")
        let lactic = product("Lactic Acid Treatment", category: .treatment, ingredients: "Lactic Acid")
        let routine = engine.generateRoutine(bag: [bha, lactic], concerns: [])

        let calendar = Calendar(identifier: .gregorian)
        var overlapDays = 0
        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now))!
            let dueToday = (routine.amSteps + routine.pmSteps).filter { $0.isDue(on: date) }
            let namesToday = Set(dueToday.map { $0.productName })
            if namesToday.contains("BHA Exfoliant") && namesToday.contains("Lactic Acid Treatment") {
                overlapDays += 1
            }
        }
        XCTAssertEqual(overlapDays, 0, "The two acids should be spread onto different days, not stacked together every time both are due.")
    }

    func test_teenAgeRange_flagsRetinoidInBagWithCautionWarning() {
        let retinol = product("Retinol Serum", category: .serum, ingredients: "Retinol")
        let routine = engine.generateRoutine(bag: [retinol], concerns: [], ageRange: .teen13to17)

        XCTAssertTrue(routine.warnings.contains { $0.title == "Retinoid + your age range" })
    }

    func test_adultAgeRange_doesNotFlagRetinoid() {
        let retinol = product("Retinol Serum", category: .serum, ingredients: "Retinol")
        let routine = engine.generateRoutine(bag: [retinol], concerns: [], ageRange: .age25to34)

        XCTAssertFalse(routine.warnings.contains { $0.title == "Retinoid + your age range" })
    }

    func test_teenAgeRange_neverRecommendsRetinoidForFineLines() {
        let cleanser = product("Cleanser", category: .cleanser)
        let routine = engine.generateRoutine(bag: [cleanser], concerns: [.fineLines], ageRange: .teen13to17)

        let fineLinesRec = routine.recommendations.first { $0.concern == .fineLines }
        XCTAssertFalse(fineLinesRec?.suggestedActives.contains(.retinoid) ?? true)
    }

    func test_dailyStep_isAlwaysDue_regardlessOfDate() {
        let cleanser = product("Cleanser", category: .cleanser)
        let routine = engine.generateRoutine(bag: [cleanser], concerns: [])
        let step = routine.amSteps.first { $0.productName == "Cleanser" }

        XCTAssertEqual(step?.frequency, .daily)
        XCTAssertTrue(step?.isDue(on: Date()) ?? false)
    }

    func test_personalAllergen_matchedAgainstIngredientsText_raisesWarningPinnedToThatProduct() {
        let cleanser = product("Oat Cleanser", category: .cleanser, ingredients: "Water, Colloidal Oatmeal, Glycerin")
        let routine = engine.generateRoutine(bag: [cleanser], concerns: [], personalAllergens: ["oatmeal"])

        let warning = routine.warnings.first { $0.title.localizedCaseInsensitiveContains("oatmeal") }
        XCTAssertNotNil(warning)
        XCTAssertEqual(warning?.relatedBagItemIDs, ["Oat Cleanser"])
    }

    func test_personalAllergen_noMatch_raisesNoWarning() {
        let cleanser = product("Plain Cleanser", category: .cleanser, ingredients: "Water, Glycerin")
        let routine = engine.generateRoutine(bag: [cleanser], concerns: [], personalAllergens: ["lanolin"])

        XCTAssertFalse(routine.warnings.contains { $0.title.localizedCaseInsensitiveContains("lanolin") })
    }

    func test_pregnancyFlag_off_byDefault_noRetinoidWarning() {
        let retinolSerum = product("Retinol Serum", category: .serum, ingredients: "Retinol")
        let routine = engine.generateRoutine(bag: [retinolSerum], concerns: [])
        XCTAssertFalse(routine.warnings.contains { $0.title.localizedCaseInsensitiveContains("pregnan") })
    }

    func test_pregnancyFlag_on_flagsRetinoidInBag() {
        let retinolSerum = product("Retinol Serum", category: .serum, ingredients: "Retinol")
        let routine = engine.generateRoutine(bag: [retinolSerum], concerns: [], isPregnantOrNursing: true)

        let warning = routine.warnings.first { $0.relatedBagItemIDs.contains(retinolSerum.id) && $0.title.localizedCaseInsensitiveContains("pregnan") }
        XCTAssertNotNil(warning)
    }

    func test_pregnancyFlag_on_neverRecommendsRetinoidForUnaddressedConcern() {
        let cleanser = product("Cleanser", category: .cleanser)
        let routine = engine.generateRoutine(bag: [cleanser], concerns: [.fineLines], isPregnantOrNursing: true)

        let fineLinesRec = routine.recommendations.first { $0.concern == .fineLines }
        XCTAssertFalse(fineLinesRec?.suggestedActives.contains(.retinoid) ?? true)
    }
}
