//
//  RoutineEngine.swift
//  SkincareCompanion
//
//  Pure, testable rule-based logic that turns "what's in my bag" +
//  "what am I dealing with" into an ordered AM/PM routine, flags known
//  ingredient conflicts, and recommends product categories the bag is
//  missing for the selected concerns. No network or persistence code
//  lives here on purpose — see RoutineEngineTests for coverage.
//

import Foundation

struct RoutineEngine {

    /// Builds a routine from the user's bag and selected concerns.
    /// - Parameters:
    ///   - bag: every product the user owns.
    ///   - concerns: concerns selected for this routine. Empty means
    ///     "just organize what I own into an AM/PM order" with no
    ///     concern-specific filtering or recommendations.
    func generateRoutine(bag: [Product], concerns: [SkinConcern]) -> Routine {
        let relevantActives = Set(concerns.flatMap { $0.targetingActives })

        let itemsToInclude = bag.filter { product in
            guard !concerns.isEmpty else { return true }
            if isFoundational(product.category) { return true }
            return !product.detectedActives.isDisjoint(with: relevantActives)
        }

        var amSteps: [RoutineStep] = []
        var pmSteps: [RoutineStep] = []

        for product in itemsToInclude {
            let session = session(for: product)
            let step = RoutineStep(
                bagItemID: product.id,
                productName: product.name,
                brand: product.brand,
                category: product.category,
                note: note(for: product, concerns: concerns)
            )
            if session == .am || session == .both {
                amSteps.append(step)
            }
            if session == .pm || session == .both {
                pmSteps.append(step)
            }
        }

        amSteps.sort { $0.category.applicationOrder < $1.category.applicationOrder }
        pmSteps.sort { $0.category.applicationOrder < $1.category.applicationOrder }

        var warnings = conflictWarnings(in: itemsToInclude, session: .am, steps: amSteps)
        warnings.append(contentsOf: conflictWarnings(in: itemsToInclude, session: .pm, steps: pmSteps))
        warnings.append(contentsOf: sunscreenWarning(bag: bag, amSteps: amSteps, itemsToInclude: itemsToInclude))

        let recommendations = buildRecommendations(bag: bag, itemsToInclude: itemsToInclude, concerns: concerns)

        return Routine(
            concerns: concerns,
            amSteps: amSteps,
            pmSteps: pmSteps,
            warnings: warnings,
            recommendations: recommendations
        )
    }

    // MARK: - Session assignment

    private func isFoundational(_ category: ProductCategory) -> Bool {
        [.cleanser, .moisturizer, .sunscreen].contains(category)
    }

    private func session(for product: Product) -> RoutineSession {
        if product.category == .sunscreen { return .am }
        if product.category == .mask { return .both } // shown but typically used ad hoc, not daily

        let actives = product.detectedActives
        let windows = Set(actives.map { $0.conventionalWindow })

        if windows.contains(.pm) && !windows.contains(.am) { return .pm }
        if windows.contains(.am) && !windows.contains(.pm) { return .am }
        // No strong-opinion actives detected (or it has both AM- and
        // PM-leaning actives, which is unusual) — safe to use in both.
        return .both
    }

    private func note(for product: Product, concerns: [SkinConcern]) -> String? {
        let addressed = concerns.filter { !Set($0.targetingActives).isDisjoint(with: product.detectedActives) }
        guard !addressed.isEmpty else { return nil }
        let names = addressed.map { $0.displayName }.joined(separator: ", ")
        return "Helps with: \(names)"
    }

    // MARK: - Conflict detection

    private func conflictWarnings(in items: [Product], session: RoutineSession, steps: [RoutineStep]) -> [RoutineWarning] {
        let stepIDs = Set(steps.map { $0.bagItemID })
        let activesInSession = items
            .filter { stepIDs.contains($0.id) }
            .reduce(into: Set<Active>()) { $0.formUnion($1.detectedActives) }

        let sessionLabel = session == .am ? "morning" : "evening"
        return IngredientConflictRules.conflicts(among: activesInSession).map {
            RoutineWarning(title: "\($0.title) (\(sessionLabel))", detail: $0.detail)
        }
    }

    private func sunscreenWarning(bag: [Product], amSteps: [RoutineStep], itemsToInclude: [Product]) -> [RoutineWarning] {
        let usesActives = itemsToInclude.contains {
            !$0.detectedActives.isDisjoint(with: [.retinoid, .glycolicAcid, .lacticAcid, .salicylicAcid, .vitaminC, .azelaicAcid])
        }
        let hasSunscreen = bag.contains { $0.category == .sunscreen }
        guard usesActives, !hasSunscreen else { return [] }
        return [RoutineWarning(
            title: "No sunscreen in your bag",
            detail: "Your routine includes exfoliating or brightening actives that increase sun sensitivity. A daily SPF is the single highest-impact addition you're missing."
        )]
    }

    // MARK: - Recommendations

    private func buildRecommendations(bag: [Product], itemsToInclude: [Product], concerns: [SkinConcern]) -> [Recommendation] {
        var recommendations: [Recommendation] = []

        for concern in concerns {
            let alreadyAddressed = itemsToInclude.contains {
                !$0.detectedActives.isDisjoint(with: Set(concern.targetingActives))
            }
            guard !alreadyAddressed else { continue }

            let topActive = concern.targetingActives.first
            let missingCategory = defaultCategory(for: topActive)
            recommendations.append(Recommendation(
                concern: concern,
                missingCategory: missingCategory,
                suggestedActives: Array(concern.targetingActives.prefix(3)),
                reason: "Nothing in your bag targets \(concern.displayName.lowercased()) yet."
            ))
        }

        if !bag.contains(where: { $0.category == .cleanser }) {
            recommendations.append(Recommendation(
                concern: concerns.first ?? .dullness,
                missingCategory: .cleanser,
                suggestedActives: [],
                reason: "Every routine needs a cleanser and your bag doesn't have one yet."
            ))
        }
        if !bag.contains(where: { $0.category == .moisturizer }) {
            recommendations.append(Recommendation(
                concern: concerns.first ?? .dryness,
                missingCategory: .moisturizer,
                suggestedActives: [.ceramides, .hyaluronicAcid],
                reason: "A moisturizer helps balance out actives and support the skin barrier."
            ))
        }
        if !bag.contains(where: { $0.category == .sunscreen }) {
            recommendations.append(Recommendation(
                concern: concerns.first ?? .hyperpigmentation,
                missingCategory: .sunscreen,
                suggestedActives: [.spfFilter],
                reason: "Daily SPF protects skin barrier health and prevents actives from causing sun sensitivity issues."
            ))
        }

        return recommendations
    }

    private func defaultCategory(for active: Active?) -> ProductCategory {
        switch active {
        case .retinoid, .vitaminC, .niacinamide, .azelaicAcid, .hyaluronicAcid, .peptides:
            return .serum
        case .glycolicAcid, .lacticAcid, .salicylicAcid:
            return .exfoliant
        case .benzoylPeroxide:
            return .treatment
        case .ceramides, .squalane, .glycerin, .centella:
            return .moisturizer
        case .clay:
            return .mask
        case .spfFilter:
            return .sunscreen
        case .none:
            return .other
        }
    }
}
