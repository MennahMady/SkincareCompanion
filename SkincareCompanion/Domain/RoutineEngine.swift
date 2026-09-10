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
    ///   - ageRange: the profile's selected age bucket, if any. Used to
    ///     flag retinoids as needing extra caution for teens and to keep
    ///     retinoid out of gap recommendations for that age range — see
    ///     `AgeRange.needsActiveCaution`. `nil` (no age set yet) applies
    ///     no age-based adjustment.
    /// - Parameters:
    ///   - personalAllergens: free-text ingredient terms the user has
    ///     flagged for themselves (beyond the built-in Active list) —
    ///     see PersonalAllergen. Matched as a case-insensitive substring
    ///     against each product's ingredients text.
    ///   - isPregnantOrNursing: optional, off by default — see
    ///     PregnancySafety. Flags retinoids/salicylic acid already in
    ///     the bag and keeps retinoid out of gap recommendations, same
    ///     "caution not removal" pattern as the teen age-range handling.
    func generateRoutine(bag: [Product], concerns: [SkinConcern], ageRange: AgeRange? = nil, personalAllergens: [String] = [], isPregnantOrNursing: Bool = false) -> Routine {
        let relevantActives = Set(concerns.flatMap { $0.targetingActives })

        let concernFiltered = bag.filter { product in
            guard !concerns.isEmpty else { return true }
            if isFoundational(product.category) { return true }
            return !product.detectedActives.isDisjoint(with: relevantActives)
        }

        // Owning 3 cleansers doesn't mean you lather with all 3 in one
        // sitting — a foundational category (cleanser/moisturizer/
        // sunscreen) is used once per session, so only one representative
        // product per category makes it into the actual routine. The
        // rest stay in the bag; a note on the chosen step says how many
        // others exist so it isn't a silent surprise.
        let dedup = dedupFoundational(concernFiltered, concerns: concerns)
        let itemsToInclude = dedup.items

        let scheduleKeys = assignScheduleKeys(itemsToInclude)

        var amSteps: [RoutineStep] = []
        var pmSteps: [RoutineStep] = []

        for product in itemsToInclude {
            let session = session(for: product)
            let frequency = StepSchedule.frequency(for: product)
            let scheduleKey = scheduleKeys[product.id] ?? product.id
            let step = RoutineStep(
                bagItemID: product.id,
                productName: product.name,
                brand: product.brand,
                category: product.category,
                note: note(for: product, concerns: concerns, extraInCategory: dedup.extraCounts[product.category] ?? 0),
                frequency: frequency,
                scheduleDescription: StepSchedule.description(frequency: frequency, productID: scheduleKey),
                scheduleKey: scheduleKey
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
        warnings.append(contentsOf: ageCautionWarnings(itemsToInclude: itemsToInclude, ageRange: ageRange))
        warnings.append(contentsOf: allergenWarnings(itemsToInclude: itemsToInclude, personalAllergens: personalAllergens))
        warnings.append(contentsOf: pregnancySafetyWarnings(itemsToInclude: itemsToInclude, isPregnantOrNursing: isPregnantOrNursing))

        let recommendations = buildRecommendations(bag: bag, itemsToInclude: itemsToInclude, concerns: concerns, ageRange: ageRange, isPregnantOrNursing: isPregnantOrNursing)

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

    private struct DedupResult {
        let items: [Product]
        /// Per foundational category, how many *other* products of that
        /// category were left out (0 when there's no duplicate).
        let extraCounts: [ProductCategory: Int]
    }

    /// Keeps every non-foundational product, but only one product per
    /// foundational category (cleanser/moisturizer/sunscreen) — whichever
    /// one already targets a selected concern, falling back to the first
    /// one encountered.
    private func dedupFoundational(_ items: [Product], concerns: [SkinConcern]) -> DedupResult {
        let relevantActives = Set(concerns.flatMap { $0.targetingActives })
        var chosen: [ProductCategory: Product] = [:]
        var counts: [ProductCategory: Int] = [:]
        var nonFoundational: [Product] = []

        for product in items {
            guard isFoundational(product.category) else {
                nonFoundational.append(product)
                continue
            }
            counts[product.category, default: 0] += 1
            if let existing = chosen[product.category] {
                let candidateMatches = !product.detectedActives.isDisjoint(with: relevantActives)
                let existingMatches = !existing.detectedActives.isDisjoint(with: relevantActives)
                if candidateMatches && !existingMatches {
                    chosen[product.category] = product
                }
            } else {
                chosen[product.category] = product
            }
        }

        let extraCounts = counts.mapValues { max($0 - 1, 0) }.filter { $0.value > 0 }
        return DedupResult(items: nonFoundational + Array(chosen.values), extraCounts: extraCounts)
    }

    /// Two unrelated non-daily products (say, a BHA exfoliant and a
    /// separate lactic-acid treatment) each get their own day pattern by
    /// hashing their own id — but with only two possible patterns for
    /// "3x a week" / "every other day", two products have a 50/50 chance
    /// of hashing to the *same* pattern and landing on the same days.
    /// When that happens the days they DO overlap on end up stacked with
    /// every daily step too, which is exactly the "why do I have 7
    /// things today" problem. This spreads same-frequency products
    /// across the two available patterns deterministically (first one
    /// keeps its natural hash-based pattern; a later one that would
    /// collide gets nudged onto the other pattern instead) so exfoliating/
    /// active-heavy products land on different days from each other
    /// where possible.
    private func assignScheduleKeys(_ items: [Product]) -> [String: String] {
        var keys: [String: String] = [:]
        var usedOffsetsByFrequency: [StepFrequency: Set<Int>] = [:]

        for product in items {
            let frequency = StepSchedule.frequency(for: product)
            guard let naturalOffset = StepSchedule.patternOffset(frequency: frequency, productID: product.id) else {
                continue // .daily has no pattern to collide on
            }
            var used = usedOffsetsByFrequency[frequency] ?? []
            if !used.contains(naturalOffset) {
                used.insert(naturalOffset)
                usedOffsetsByFrequency[frequency] = used
                continue // keep default key (== product.id); no collision
            }
            // Collided with an earlier product on this frequency. A
            // single fixed suffix isn't reliable — the djb2 hash of
            // "id#alt-schedule" can land back on the exact same bucket
            // as "id" (verified: it isn't rare enough to ignore) — so
            // search a small sequence of stable, deterministic candidate
            // keys until one actually lands on a free pattern.
            var resolved = false
            for attempt in 1...8 {
                let candidateKey = "\(product.id)#alt-schedule-\(attempt)"
                guard let candidateOffset = StepSchedule.patternOffset(frequency: frequency, productID: candidateKey) else { break }
                if !used.contains(candidateOffset) {
                    keys[product.id] = candidateKey
                    used.insert(candidateOffset)
                    resolved = true
                    break
                }
            }
            if !resolved {
                used.insert(naturalOffset) // no free pattern found in range; accept the overlap
            }
            usedOffsetsByFrequency[frequency] = used
        }
        return keys
    }

    private func pluralLabel(for category: ProductCategory) -> String {
        switch category {
        case .cleanser: return "cleansers"
        case .moisturizer: return "moisturizers"
        case .sunscreen: return "sunscreens"
        default: return category.displayName.lowercased() + "s"
        }
    }

    private func session(for product: Product) -> RoutineSession {
        if product.category == .sunscreen { return .am }
        if product.category == .mask { return .both } // shown but typically used ad hoc, not daily
        if product.category == .tool { return .both } // steamers etc. — ad hoc, before either session

        let actives = product.detectedActives
        let windows = Set(actives.map { $0.conventionalWindow })

        if windows.contains(.pm) && !windows.contains(.am) { return .pm }
        if windows.contains(.am) && !windows.contains(.pm) { return .am }
        // No strong-opinion actives detected (or it has both AM- and
        // PM-leaning actives, which is unusual) — safe to use in both.
        return .both
    }

    private func note(for product: Product, concerns: [SkinConcern], extraInCategory: Int = 0) -> String? {
        let addressed = concerns.filter { !Set($0.targetingActives).isDisjoint(with: product.detectedActives) }
        var parts: [String] = []
        if !addressed.isEmpty {
            parts.append("Helps with: \(addressed.map { $0.displayName }.joined(separator: ", "))")
        }
        if extraInCategory > 0 {
            let total = extraInCategory + 1
            parts.append("You have \(total) \(pluralLabel(for: product.category)) — using this one today, swap it in My Bag anytime.")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    // MARK: - Conflict detection

    private func conflictWarnings(in items: [Product], session: RoutineSession, steps: [RoutineStep]) -> [RoutineWarning] {
        let stepIDs = Set(steps.map { $0.bagItemID })
        let itemsInSession = items.filter { stepIDs.contains($0.id) }
        let activesInSession = itemsInSession.reduce(into: Set<Active>()) { $0.formUnion($1.detectedActives) }

        let sessionLabel = session == .am ? "morning" : "evening"

        // IngredientConflictRules has separate entries per specific acid
        // (e.g. retinoid+glycolicAcid AND retinoid+lacticAcid both read
        // as "Retinoid + AHA", since glycolic and lactic are both AHAs).
        // Someone whose bag contains both acids alongside a retinoid
        // would otherwise trip both rules and see the same warning card
        // twice. Since the title+detail are user-facing text, collapsing
        // to unique (title, detail) pairs is the right dedup key here —
        // two rules that render identically should read as one warning.
        var seen = Set<String>()
        var warnings: [RoutineWarning] = []
        for rule in IngredientConflictRules.conflicts(among: activesInSession) {
            let title = "\(rule.title) (\(sessionLabel))"
            let key = "\(title)|\(rule.detail)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            // Pin this warning to the specific products whose actives
            // triggered it, so the UI can show a warning icon right on
            // those rows instead of a general upfront list.
            let relatedIDs = itemsInSession
                .filter { !$0.detectedActives.isDisjoint(with: [rule.a, rule.b]) }
                .map { $0.id }
            warnings.append(RoutineWarning(title: title, detail: rule.detail, relatedBagItemIDs: relatedIDs))
        }
        return warnings
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

    // MARK: - Age-based caution

    /// Flags retinoid-containing products already in the bag as worth a
    /// second look for teen users — see `AgeRange.needsActiveCaution`.
    /// This is a caution, not a removal: the product still appears in
    /// the routine (it's already owned), it's just called out.
    private func ageCautionWarnings(itemsToInclude: [Product], ageRange: AgeRange?) -> [RoutineWarning] {
        guard let ageRange, ageRange.needsActiveCaution else { return [] }
        let retinoidProducts = itemsToInclude.filter { $0.detectedActives.contains(.retinoid) }
        guard !retinoidProducts.isEmpty else { return [] }
        let names = retinoidProducts.map { $0.name }.joined(separator: ", ")
        return [RoutineWarning(
            title: "Retinoid + your age range",
            detail: "\(names) contains a retinoid. Commonly-cited guidance is to hold off on retinoids until later teens/adulthood, or check with a dermatologist first, given the age range on your profile (\(ageRange.displayName))."
            , relatedBagItemIDs: retinoidProducts.map { $0.id }
        )]
    }

    // MARK: - Pregnancy/nursing caution

    /// Same "caution, not removal" pattern as ageCautionWarnings — see
    /// PregnancySafety for which actives are flagged and why. Off
    /// entirely unless isPregnantOrNursing is explicitly set.
    private func pregnancySafetyWarnings(itemsToInclude: [Product], isPregnantOrNursing: Bool) -> [RoutineWarning] {
        guard isPregnantOrNursing else { return [] }

        var warnings: [RoutineWarning] = []
        for flag in PregnancySafety.flags {
            let matches = itemsToInclude.filter { $0.detectedActives.contains(flag.active) }
            guard !matches.isEmpty else { continue }
            let names = matches.map { $0.name }.joined(separator: ", ")
            let title = flag.severity == .avoid ? "\(flag.active.displayName) during pregnancy/nursing" : "\(flag.active.displayName) — worth checking"
            warnings.append(RoutineWarning(
                title: title,
                detail: "\(names) contains \(flag.active.displayName.lowercased()). \(flag.detail)",
                relatedBagItemIDs: matches.map { $0.id }
            ))
        }
        return warnings
    }

    // MARK: - Personal allergens

    /// Matches the user's own free-text allergen terms (PersonalAllergen)
    /// against each included product's ingredients text — a simple
    /// case-insensitive substring check, the same approach Active.detect
    /// uses for the built-in active list. This catches things the fixed
    /// Active enum has no idea about (a specific fragrance compound, a
    /// plant extract, lanolin, a nut oil, etc.) since the user is the
    /// authority on their own reactions.
    private func allergenWarnings(itemsToInclude: [Product], personalAllergens: [String]) -> [RoutineWarning] {
        let terms = personalAllergens
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return [] }

        var warnings: [RoutineWarning] = []
        for term in terms {
            let matches = itemsToInclude.filter {
                $0.ingredientsText?.range(of: term, options: .caseInsensitive) != nil
            }
            guard !matches.isEmpty else { continue }
            let names = matches.map { $0.name }.joined(separator: ", ")
            warnings.append(RoutineWarning(
                title: "Contains \(term)",
                detail: "\(names) lists \"\(term)\" in its ingredients — you flagged this as something you react to.",
                relatedBagItemIDs: matches.map { $0.id }
            ))
        }
        return warnings
    }

    // MARK: - Recommendations

    private func buildRecommendations(bag: [Product], itemsToInclude: [Product], concerns: [SkinConcern], ageRange: AgeRange? = nil, isPregnantOrNursing: Bool = false) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        let avoidRetinoidSuggestions = ageRange?.needsActiveCaution == true || isPregnantOrNursing

        for concern in concerns {
            let alreadyAddressed = itemsToInclude.contains {
                !$0.detectedActives.isDisjoint(with: Set(concern.targetingActives))
            }
            guard !alreadyAddressed else { continue }

            // Never suggest shopping for a retinoid for a teen profile —
            // steer toward whatever the concern's next-best active is.
            let candidateActives = avoidRetinoidSuggestions
                ? concern.targetingActives.filter { $0 != .retinoid }
                : concern.targetingActives
            guard !candidateActives.isEmpty else { continue }

            let topActive = candidateActives.first
            let missingCategory = defaultCategory(for: topActive)
            let suggestedActives = Array(candidateActives.prefix(3))
            recommendations.append(Recommendation(
                concern: concern,
                missingCategory: missingCategory,
                suggestedActives: suggestedActives,
                reason: "Since you're dealing with \(concern.displayName.lowercased()), try a \(missingCategory.displayName.lowercased()) with \(Self.naturalList(suggestedActives))."
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
            let actives: [Active] = [.ceramides, .hyaluronicAcid]
            recommendations.append(Recommendation(
                concern: concerns.first ?? .dryness,
                missingCategory: .moisturizer,
                suggestedActives: actives,
                reason: "Your bag doesn't have a moisturizer yet — try one with \(Self.naturalList(actives)) to support your skin barrier."
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

    /// Joins active ingredient names into a natural-sounding phrase, e.g.
    /// "salicylic acid (BHA), benzoyl peroxide, or niacinamide" — used to
    /// turn a bare list of actives into a sentence a user would actually
    /// say, matching the tone of the sunscreen warning above.
    static func naturalList(_ actives: [Active]) -> String {
        let names = actives.map { $0.displayName.lowercased() }
        switch names.count {
        case 0: return "the right actives for it"
        case 1: return names[0]
        case 2: return "\(names[0]) or \(names[1])"
        default:
            let allButLast = names.dropLast().joined(separator: ", ")
            return "\(allButLast), or \(names.last!)"
        }
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
