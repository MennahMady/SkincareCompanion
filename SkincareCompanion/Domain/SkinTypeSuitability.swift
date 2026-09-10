//
//  SkinTypeSuitability.swift
//  SkincareCompanion
//
//  Infers which skin types a product commonly suits from its category
//  and detected ingredients — the same keyword-matching approach as
//  ProductCategory.infer and Active.detect, applied to a new question.
//  This is a heuristic, not a verified per-product claim: no brand
//  publishes "this suits oily/dry/combination/normal/sensitive skin" as
//  structured data, and Open Beauty Facts doesn't carry it either, so
//  there was nothing to look up — this reasons it out from what's
//  actually in the product, the same honest-approximation approach used
//  everywhere else in this dataset. Always patch test and check the
//  product's own packaging/marketing for anything you're unsure about.
//
//  Starts from "suits everyone" and removes a skin type only when the
//  product contains something commonly cited as a poor fit for it,
//  rather than trying to positively prove fit for each of the five —
//  positive claims are much easier to get wrong than exclusions.
//
import Foundation

enum SkinTypeSuitability {

    static func infer(category: ProductCategory, ingredientsText: String?, detectedActives: Set<Active>) -> [SkinType] {
        var suitable = Set(SkinType.allCases)
        let text = ingredientsText?.lowercased() ?? ""

        // Heavy, occlusive, oil-forward formulas tend to feel too rich
        // for oily/combination skin and can be more comedogenic there.
        let richKeywords = ["mineral oil", "shea butter", "cocoa butter", "coconut oil", "petrolatum", "lanolin"]
        let isRich = category == .faceOil || richKeywords.contains { text.contains($0) }
        if isRich {
            suitable.remove(.oily)
        }

        // Strong exfoliating/active concentrations and drying agents are
        // the most commonly cited irritants for sensitive skin.
        let harshActives: Set<Active> = [.retinoid, .glycolicAcid, .lacticAcid, .salicylicAcid, .benzoylPeroxide]
        let hasHarshActive = !detectedActives.isDisjoint(with: harshActives)
        let dryingKeywords = ["alcohol denat", "sd alcohol", "witch hazel", "menthol", "fragrance", "parfum"]
        let hasDryingIngredient = dryingKeywords.contains { text.contains($0) }
        if hasHarshActive || hasDryingIngredient {
            suitable.remove(.sensitive)
        }

        // Astringent/mattifying ingredients and a bare exfoliant/BHA
        // focus tend to be too drying for already-dry skin.
        if dryingKeywords.contains(where: { text.contains($0) }) || category == .exfoliant {
            suitable.remove(.dry)
        }

        // Barrier-supporting, calming ingredients are the classic
        // "good for sensitive skin" signal — add sensitive back if it
        // was excluded purely by a mild active, not a genuinely harsh one.
        let soothingKeywords: Set<Active> = [.centella, .ceramides, .glycerin]
        if !detectedActives.isDisjoint(with: soothingKeywords) && !hasHarshActive && !hasDryingIngredient {
            suitable.insert(.sensitive)
        }

        // Oil-control ingredients are a positive signal specifically for
        // oily/combination, without excluding anyone by having them.
        if detectedActives.contains(.clay) || detectedActives.contains(.salicylicAcid) {
            suitable.insert(.oily)
            suitable.insert(.combination)
        }

        return SkinType.allCases.filter { suitable.contains($0) }
    }
}
