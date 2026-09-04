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

enum Active: String, CaseIterable, Codable {
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
