//
//  ProductFitScorer.swift
//  SkincareCompanion
//
//  "Scan this at the store and tell me how good it is for me" — a
//  transparent, rule-based percentage score for one specific product
//  against one specific person's actual profile (skin type, concerns,
//  personal allergens, pregnancy/nursing status, age range, and what's
//  already in their bag). Every point added or subtracted has a
//  human-readable reason attached — same "no black box" principle as
//  the rest of RoutineEngine, just aimed at a single scanned product
//  instead of a whole routine.
//
//  This is NOT a substitute for reading the label yourself, and it
//  only knows what the built-in Active list and the user's own
//  personal-allergen list can detect — an unusual or newly-studied
//  ingredient concern won't be caught.
//

import Foundation

struct ProductFitContext {
    var skinType: SkinType?
    var concerns: [SkinConcern] = []
    var personalAllergens: [String] = []
    var isPregnantOrNursing: Bool = false
    var ageRange: AgeRange? = nil
    /// Actives already in use elsewhere in the bag — used to catch a
    /// conflict this specific product would newly introduce.
    var currentBagActives: Set<Active> = []
}

struct ProductFit {
    enum Verdict: String {
        case avoid = "Avoid"
        case caution = "Use Caution"
        case good = "Good Fit"
        case great = "Great Fit"
    }

    let percentage: Int
    let verdict: Verdict
    /// Human-readable reasons, most important first.
    let reasons: [String]
}

enum ProductFitScorer {
    static func score(product: Product, context: ProductFitContext) -> ProductFit {
        var reasons: [String] = []

        // MARK: Hard stops — these override the numeric score entirely,
        // since "contains something you're personally allergic to" or
        // "commonly avoided during pregnancy" matters more than any
        // amount of ingredient-fit points.
        let allergenHit = context.personalAllergens.first {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            product.ingredientsText?.range(of: $0, options: .caseInsensitive) != nil
        }
        if let allergenHit {
            reasons.append("Contains \"\(allergenHit)\" — you've flagged this as something you react to.")
            return ProductFit(percentage: 5, verdict: .avoid, reasons: reasons)
        }

        if context.isPregnantOrNursing {
            for flag in PregnancySafety.flags where flag.severity == .avoid && product.detectedActives.contains(flag.active) {
                reasons.append("Contains \(flag.active.displayName.lowercased()) — \(flag.detail)")
                return ProductFit(percentage: 10, verdict: .avoid, reasons: reasons)
            }
        }

        // MARK: Additive scoring for everything else — starts neutral,
        // moves up or down with a stated reason for each shift.
        var score = 50

        if context.isPregnantOrNursing {
            for flag in PregnancySafety.flags where flag.severity == .checkWithProvider && product.detectedActives.contains(flag.active) {
                score -= 25
                reasons.append("Contains \(flag.active.displayName.lowercased()) — \(flag.detail)")
            }
        }

        if context.ageRange?.needsActiveCaution == true, product.detectedActives.contains(.retinoid) {
            score -= 20
            reasons.append("Contains a retinoid — commonly advised to hold off on, or check with a dermatologist first, given the age range on your profile.")
        }

        let newConflicts = IngredientConflictRules.conflicts(among: context.currentBagActives.union(product.detectedActives))
            .filter { rule in
                let pair: Set<Active> = [rule.a, rule.b]
                // Only count it if this product is actually one side of
                // the conflict AND the other side is already in the bag
                // — a conflict entirely within the existing bag isn't
                // this product's fault.
                return !product.detectedActives.isDisjoint(with: pair) && !context.currentBagActives.isDisjoint(with: pair)
            }
        for rule in newConflicts {
            score -= 20
            reasons.append("\(rule.title): \(rule.detail)")
        }

        let relevantActives = Set(context.concerns.flatMap { $0.targetingActives })
        let addressedConcerns = context.concerns.filter { !Set($0.targetingActives).isDisjoint(with: product.detectedActives) }
        if !relevantActives.isEmpty {
            if !addressedConcerns.isEmpty {
                score += 20
                reasons.append("Targets what you're dealing with: \(addressedConcerns.map { $0.displayName }.joined(separator: ", ")).")
            } else if !product.detectedActives.isEmpty {
                reasons.append("Doesn't contain actives that target your selected concerns — not bad, just not targeted.")
            }
        }

        if let skinType = context.skinType, product.category.hasIngredients {
            let suitable = product.suitableSkinTypes
            if suitable.count < SkinType.allCases.count {
                if suitable.contains(skinType) {
                    score += 10
                    reasons.append("A best-guess match for \(skinType.displayName.lowercased()) skin.")
                } else {
                    score -= 10
                    reasons.append("Best-guess suited for \(Self.naturalSkinTypeList(suitable)), not \(skinType.displayName.lowercased()) — worth a second look.")
                }
            }
        }

        if reasons.isEmpty {
            reasons.append("No red flags detected, but also nothing that specifically targets your profile — a neutral pick.")
        }

        let clamped = max(0, min(100, score))
        let verdict: ProductFit.Verdict
        switch clamped {
        case 0..<35: verdict = .caution
        case 35..<65: verdict = .good
        default: verdict = .great
        }

        return ProductFit(percentage: clamped, verdict: verdict, reasons: reasons)
    }

    private static func naturalSkinTypeList(_ types: [SkinType]) -> String {
        let names = types.map { $0.displayName.lowercased() }
        switch names.count {
        case 0: return "no particular skin type"
        case 1: return names[0]
        case 2: return "\(names[0]) or \(names[1])"
        default: return "\(names.dropLast().joined(separator: ", ")), or \(names.last!)"
        }
    }
}
