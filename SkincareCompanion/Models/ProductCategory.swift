//
//  ProductCategory.swift
//  SkincareCompanion
//
//  The step categories a product can occupy in a routine, in the order
//  they're typically applied (thinnest/most-active-first, occlusive-last).
//

import Foundation

enum ProductCategory: String, CaseIterable, Codable, Identifiable {
    case tool           // devices/tools: facial steamer, jade roller, gua sha — no ingredients
    case cleanser
    case toner
    case exfoliant
    case treatment      // spot treatments, actives-only serums
    case serum
    case eyeCream
    case moisturizer
    case faceOil
    case sunscreen
    case mask
    case other

    var id: String { rawValue }

    /// Lower sorts earlier within a single AM or PM session. Tools like
    /// a steamer are a pre-cleanse step, so they sort before everything
    /// else — including the cleanser itself.
    var applicationOrder: Int {
        switch self {
        case .tool: return -1
        case .cleanser: return 0
        case .toner: return 1
        case .exfoliant: return 2
        case .treatment: return 3
        case .serum: return 4
        case .eyeCream: return 5
        case .moisturizer: return 6
        case .faceOil: return 7
        case .sunscreen: return 8
        case .mask: return 9 // used standalone, not in daily AM/PM order
        case .other: return 10
        }
    }

    var systemImage: String {
        switch self {
        case .tool: return "wind"
        case .cleanser: return "drop.circle.fill"
        case .toner: return "sparkles"
        case .exfoliant: return "circle.grid.3x3.fill"
        case .treatment: return "bandage.fill"
        case .serum: return "eyedropper.halffull"
        case .eyeCream: return "eye.fill"
        case .moisturizer: return "cloud.fill"
        case .faceOil: return "drop.fill"
        case .sunscreen: return "sun.max.fill"
        case .mask: return "face.smiling.fill"
        case .other: return "questionmark.circle.fill"
        }
    }

    var displayName: String {
        switch self {
        case .tool: return "Tool / Device"
        case .cleanser: return "Cleanser"
        case .toner: return "Toner"
        case .exfoliant: return "Exfoliant"
        case .treatment: return "Treatment"
        case .serum: return "Serum"
        case .eyeCream: return "Eye Cream"
        case .moisturizer: return "Moisturizer"
        case .faceOil: return "Face Oil"
        case .sunscreen: return "Sunscreen (SPF)"
        case .mask: return "Mask"
        case .other: return "Other"
        }
    }

    /// Whether this category has actual ingredients to speak of — tools
    /// (a steamer, a roller) don't, so ingredient-detection, conflict
    /// checking, and "detected actives" UI should all just skip them
    /// rather than showing an empty/misleading ingredients section.
    var hasIngredients: Bool {
        self != .tool
    }

    /// How this category is conventionally applied — the kind of
    /// technique note ("layer a toner 1-2 times", "use a nickel-sized
    /// amount of sunscreen") that's easy to miss if a routine just names
    /// the product and category with no guidance on the how. General
    /// educational technique guidance, not a product-specific instruction
    /// (always defer to what's actually printed on the packaging).
    var applicationTip: String? {
        switch self {
        case .tool:
            return "Move it slowly and continuously — don't hold a steamer or a hot tool in one spot, and keep enough distance that it warms skin rather than stinging it."
        case .cleanser:
            return "Massage into damp skin for 30-60 seconds before rinsing — that's roughly how long it takes to actually lift dirt and makeup, not just wet the surface."
        case .toner:
            return "Commonly applied in 1-2 thin layers, patted (not wiped) into skin — a second layer is often used for extra hydration before the next step, especially on drier days."
        case .exfoliant:
            return "Leave on for the time the packaging specifies, then move on — don't add a second exfoliating product in the same session even if it's a different acid."
        case .treatment:
            return "Applied to clean, dry skin, usually before moisturizer so it can absorb directly rather than through a layer of cream."
        case .serum:
            return "Press in with your palms rather than rubbing — serums are usually lightweight enough that rubbing just moves product around instead of helping it absorb."
        case .eyeCream:
            return "A small amount (rice-grain sized), patted on gently with your ring finger — the skin here is thinner and doesn't need much product."
        case .moisturizer:
            return "Applied last (or second-to-last before sunscreen) in upward motions, once other actives have had a moment to absorb."
        case .faceOil:
            return "Applied after moisturizer to seal it in — oils sit on top of water-based products, not underneath them."
        case .sunscreen:
            return "About 1/4 teaspoon (roughly a nickel-sized amount) for the face alone — most people apply noticeably less than the amount actually tested to give the SPF on the label."
        case .mask:
            return "Follow the packaging's timing exactly — leaving a mask on well past its stated time doesn't add benefit and can just dry out or irritate skin."
        case .other:
            return nil
        }
    }

    /// What your skin should be like *before* this step — wet, damp, or
    /// fully dry — so a routine doesn't just list product names and
    /// leave you guessing whether to pat dry first. Shown alongside
    /// applicationTip.
    var prepNote: String? {
        switch self {
        case .tool:
            return "Start with a clean, completely dry face — this comes before cleansing, not after."
        case .cleanser:
            return "Wet your face with lukewarm water first (hot water can be more irritating/drying than it feels in the moment)."
        case .toner:
            return "Skin should be freshly cleansed and patted mostly dry — some people leave it slightly damp on purpose for extra dewiness, but that's a preference, not a requirement."
        case .exfoliant:
            return "Skin should be completely dry — acids can sting or absorb unevenly on damp skin."
        case .treatment:
            return "Skin should be dry to the touch."
        case .serum:
            return "Skin should be dry to the touch, after the previous step has had a moment to absorb."
        case .eyeCream:
            return "Skin should be dry."
        case .moisturizer:
            return "Skin should be dry, after any serums/treatments underneath have absorbed (usually 30-60 seconds)."
        case .faceOil:
            return "Applied on top of moisturizer once it's mostly absorbed, not underneath it."
        case .sunscreen:
            return "Wait until everything underneath is fully dry to the touch — applying over damp product is a common cause of pilling."
        case .mask:
            return "Start with clean, dry skin unless the product specifically says to apply over damp skin."
        case .other:
            return nil
        }
    }

    /// Best-effort mapping from Open Beauty Facts category tags to our
    /// internal categories. OBF's taxonomy is crowd-sourced and messy,
    /// so this is a substring match over the lowercased tag list.
    static func infer(fromCategoryTags tags: [String]) -> ProductCategory {
        let joined = tags.joined(separator: " ").lowercased()

        if joined.contains("sunscreen") || joined.contains("spf") || joined.contains("sun-protection") {
            return .sunscreen
        }
        if joined.contains("cleanser") || joined.contains("cleansing") || joined.contains("face-wash") || joined.contains("micellar") {
            return .cleanser
        }
        if joined.contains("toner") || joined.contains("lotion-tonique") {
            return .toner
        }
        if joined.contains("exfoliant") || joined.contains("scrub") || joined.contains("peel") {
            return .exfoliant
        }
        if joined.contains("eye-cream") || joined.contains("eye-contour") {
            return .eyeCream
        }
        if joined.contains("face-oil") || joined.contains("facial-oil") {
            return .faceOil
        }
        if joined.contains("mask") || joined.contains("masque") {
            return .mask
        }
        if joined.contains("moisturizer") || joined.contains("moisturiser") || joined.contains("face-cream") || joined.contains("day-cream") || joined.contains("night-cream") {
            return .moisturizer
        }
        if joined.contains("serum") {
            return .serum
        }
        if joined.contains("treatment") || joined.contains("spot") {
            return .treatment
        }
        return .other
    }
}
