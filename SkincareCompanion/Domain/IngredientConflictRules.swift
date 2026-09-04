//
//  IngredientConflictRules.swift
//  SkincareCompanion
//
//  Encodes commonly-cited skincare-formulation guidance about actives
//  that shouldn't be layered in the same session. This is general
//  educational guidance, not dermatological advice, and the UI should
//  always present it that way — see RoutineView's disclaimer footer.
//

import Foundation

struct ConflictRule {
    let a: Active
    let b: Active
    let title: String
    let detail: String
}

enum IngredientConflictRules {

    static let rules: [ConflictRule] = [
        ConflictRule(
            a: .retinoid, b: .glycolicAcid,
            title: "Retinoid + AHA",
            detail: "Layering a retinoid with an AHA in the same routine can be irritating for a lot of people. Consider alternating nights instead of using both back to back."
        ),
        ConflictRule(
            a: .retinoid, b: .lacticAcid,
            title: "Retinoid + AHA",
            detail: "Layering a retinoid with an AHA in the same routine can be irritating for a lot of people. Consider alternating nights instead of using both back to back."
        ),
        ConflictRule(
            a: .retinoid, b: .salicylicAcid,
            title: "Retinoid + BHA",
            detail: "Combining a retinoid with a BHA in one session raises the odds of dryness and irritation. Many people alternate nights between the two."
        ),
        ConflictRule(
            a: .retinoid, b: .benzoylPeroxide,
            title: "Retinoid + Benzoyl Peroxide",
            detail: "Benzoyl peroxide can oxidize (deactivate) some retinoids and the combination is often drying. Using one in the AM and the other in the PM, or on alternating nights, is a common workaround."
        ),
        ConflictRule(
            a: .vitaminC, b: .retinoid,
            title: "Vitamin C + Retinoid",
            detail: "These are usually more stable and effective used at different times — vitamin C in the morning, retinoid at night — rather than layered together."
        ),
        ConflictRule(
            a: .glycolicAcid, b: .salicylicAcid,
            title: "AHA + BHA",
            detail: "Using two exfoliating acids in the same session compounds irritation risk. Most routines pick one per session."
        ),
        ConflictRule(
            a: .lacticAcid, b: .salicylicAcid,
            title: "AHA + BHA",
            detail: "Using two exfoliating acids in the same session compounds irritation risk. Most routines pick one per session."
        ),
    ]

    /// Returns the conflict rules that apply to a set of actives present
    /// in the same session (AM or PM).
    static func conflicts(among actives: Set<Active>) -> [ConflictRule] {
        rules.filter { actives.contains($0.a) && actives.contains($0.b) }
    }
}
