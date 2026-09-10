//
//  Active.swift
//  SkincareCompanion
//
//  Recognized active ingredients. `keywords` are lowercased substrings
//  matched against a product's INCI ingredients text pulled from Open
//  Beauty Facts. This keyword-match approach is intentionally simple
//  (no full INCI parser) but covers the common actives well enough to
//  drive routine building and conflict detection.
//

import Foundation

enum Active: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }

    case retinoid          // retinol, retinal, retinaldehyde, tretinoin, adapalene
    case salicylicAcid     // BHA
    case glycolicAcid      // AHA
    case lacticAcid        // AHA
    case benzoylPeroxide
    case niacinamide
    case vitaminC          // ascorbic acid and derivatives
    case hyaluronicAcid
    case azelaicAcid
    case ceramides
    case peptides
    case centella           // cica / centella asiatica
    case squalane
    case glycerin
    case clay
    case spfFilter          // mineral or chemical UV filters

    var displayName: String {
        switch self {
        case .retinoid: return "Retinoid"
        case .salicylicAcid: return "Salicylic Acid (BHA)"
        case .glycolicAcid: return "Glycolic Acid (AHA)"
        case .lacticAcid: return "Lactic Acid (AHA)"
        case .benzoylPeroxide: return "Benzoyl Peroxide"
        case .niacinamide: return "Niacinamide"
        case .vitaminC: return "Vitamin C"
        case .hyaluronicAcid: return "Hyaluronic Acid"
        case .azelaicAcid: return "Azelaic Acid"
        case .ceramides: return "Ceramides"
        case .peptides: return "Peptides"
        case .centella: return "Centella Asiatica (Cica)"
        case .squalane: return "Squalane"
        case .glycerin: return "Glycerin"
        case .clay: return "Clay"
        case .spfFilter: return "UV Filter"
        }
    }

    var keywords: [String] {
        switch self {
        case .retinoid:
            return ["retinol", "retinal", "retinaldehyde", "tretinoin", "adapalene", "retinyl palmitate", "hydroxypinacolone retinoate"]
        case .salicylicAcid:
            return ["salicylic acid", "bha"]
        case .glycolicAcid:
            return ["glycolic acid"]
        case .lacticAcid:
            return ["lactic acid"]
        case .benzoylPeroxide:
            return ["benzoyl peroxide"]
        case .niacinamide:
            return ["niacinamide", "nicotinamide"]
        case .vitaminC:
            return ["ascorbic acid", "ascorbyl", "sodium ascorbyl phosphate", "magnesium ascorbyl phosphate", "3-o-ethyl ascorbic acid", "tetrahexyldecyl ascorbate"]
        case .hyaluronicAcid:
            return ["hyaluronic acid", "sodium hyaluronate"]
        case .azelaicAcid:
            return ["azelaic acid"]
        case .ceramides:
            return ["ceramide"]
        case .peptides:
            return ["peptide"]
        case .centella:
            return ["centella asiatica", "cica", "madecassoside", "asiaticoside"]
        case .squalane:
            return ["squalane"]
        case .glycerin:
            return ["glycerin", "glycerol"]
        case .clay:
            return ["kaolin", "bentonite", "clay"]
        case .spfFilter:
            return ["titanium dioxide", "zinc oxide", "octinoxate", "avobenzone", "octocrylene", "homosalate", "octisalate", "ensulizole", "tinosorb"]
        }
    }

    /// Plain-language "what does this actually do" — shown when someone
    /// taps an ingredient chip. General educational summary, not medical
    /// or dermatological advice (same caveat as the rest of the app).
    var whatItDoes: String {
        switch self {
        case .retinoid:
            return "A vitamin A derivative that speeds up cell turnover and boosts collagen production. Commonly used for fine lines, texture, and acne — but it's the most irritation-prone active here, so it's usually introduced slowly."
        case .salicylicAcid:
            return "An oil-soluble exfoliating acid (BHA) that gets into pores to clear out oil and dead skin. A common go-to for blackheads, breakouts, and enlarged pores."
        case .glycolicAcid:
            return "A small-molecule exfoliating acid (AHA) that dissolves the \"glue\" between dead skin cells on the surface. Commonly used for texture, dullness, and mild discoloration."
        case .lacticAcid:
            return "An AHA similar to glycolic acid but a larger molecule, so it exfoliates a bit more gently while also drawing in some moisture. Often chosen by people who find glycolic acid too irritating."
        case .benzoylPeroxide:
            return "An antibacterial that kills the acne-causing bacteria C. acnes. A common first-line acne treatment, though it can bleach fabric and dry out skin."
        case .niacinamide:
            return "A form of vitamin B3 that's broadly well-tolerated. Commonly used for oil control, redness, enlarged-pore appearance, and as general barrier support."
        case .vitaminC:
            return "An antioxidant that helps defend against environmental damage (UV, pollution) and is commonly cited for brightening and mild dark-spot fading over time."
        case .hyaluronicAcid:
            return "A humectant that pulls water into the skin's surface layer. Used to hydrate rather than treat — pairs with most other actives without much conflict."
        case .azelaicAcid:
            return "A gentler multi-tasking acid commonly used for redness, mild breakouts, and post-acne discoloration. Considered one of the better-tolerated actives for sensitive skin."
        case .ceramides:
            return "Lipids that are naturally part of the skin's barrier. Topical ceramides are used to help reinforce that barrier, especially after using drying actives."
        case .peptides:
            return "Short chains of amino acids marketed for supporting collagen production and firmness. Generally well-tolerated with limited conflict risk."
        case .centella:
            return "A plant extract (also called cica) commonly used for calming redness and irritation and supporting the skin barrier."
        case .squalane:
            return "A lightweight, non-greasy emollient oil that mimics skin's own natural oils. Used to seal in moisture without feeling heavy."
        case .glycerin:
            return "A basic humectant found in most moisturizing products — draws water into the skin's surface. Very well-tolerated and rarely a source of irritation on its own."
        case .clay:
            return "An absorbent mineral used to soak up excess oil, commonly in masks and cleansers for oily/combination skin."
        case .spfFilter:
            return "A UV-filtering ingredient (mineral like zinc oxide/titanium dioxide, or a chemical filter) that protects against sun damage — commonly cited as the single highest-impact anti-aging step there is."
        }
    }

    /// Every other active this one is commonly flagged for layering
    /// with, pulled straight from IngredientConflictRules so this stays
    /// in sync with the actual conflict-detection logic instead of
    /// duplicating it.
    var knownConflicts: [(other: Active, detail: String)] {
        IngredientConflictRules.rules.compactMap { rule in
            if rule.a == self { return (rule.b, rule.detail) }
            if rule.b == self { return (rule.a, rule.detail) }
            return nil
        }
    }

    /// Scans an ingredients string (as returned by Open Beauty Facts'
    /// `ingredients_text`, or typed manually) and returns every active
    /// it can identify.
    static func detect(in ingredientsText: String?) -> Set<Active> {
        guard let text = ingredientsText?.lowercased(), !text.isEmpty else { return [] }
        var found = Set<Active>()
        for active in Active.allCases {
            if active.keywords.contains(where: { text.contains($0) }) {
                found.insert(active)
            }
        }
        return found
    }

    /// AM, PM, or both — the conventional window this active is used in.
    /// Used to slot a bag item into a session when building a routine.
    var conventionalWindow: RoutineSession {
        switch self {
        case .retinoid: return .pm
        case .vitaminC: return .am
        case .spfFilter: return .am
        case .glycolicAcid, .lacticAcid, .salicylicAcid, .benzoylPeroxide:
            return .pm
        default:
            return .both
        }
    }
}

enum RoutineSession: String, Codable {
    case am
    case pm
    case both
}
