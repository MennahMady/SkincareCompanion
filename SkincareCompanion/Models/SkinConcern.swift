//
//  SkinConcern.swift
//  SkincareCompanion
//
//  The concerns a user can select. Each concern maps to the active
//  ingredients that address it, used by RoutineEngine to match bag
//  items against selected concerns and to power recommendations.
//

import Foundation

enum SkinConcern: String, CaseIterable, Codable, Identifiable {
    case breakouts
    case unevenTexture
    case hyperpigmentation
    case dullness
    case dryness
    case oiliness
    case rednessSensitivity
    case fineLines
    case largePores

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakouts: return "Breakouts"
        case .unevenTexture: return "Uneven Texture"
        case .hyperpigmentation: return "Dark Spots / Hyperpigmentation"
        case .dullness: return "Dullness"
        case .dryness: return "Dryness"
        case .oiliness: return "Excess Oil"
        case .rednessSensitivity: return "Redness / Sensitivity"
        case .fineLines: return "Fine Lines"
        case .largePores: return "Large Pores"
        }
    }

    var systemImage: String {
        switch self {
        case .breakouts: return "circle.hexagongrid.fill"
        case .unevenTexture: return "waveform.path"
        case .hyperpigmentation: return "circle.dotted"
        case .dullness: return "moon.haze.fill"
        case .dryness: return "drop.fill"
        case .oiliness: return "sparkles"
        case .rednessSensitivity: return "flame.fill"
        case .fineLines: return "line.3.crossed.swirl.circle.fill"
        case .largePores: return "circle.grid.3x3.fill"
        }
    }

    /// Active ingredients (as they'd appear substring-matched in an
    /// ingredients list) that are commonly used to address this concern,
    /// ranked roughly by how directly they target it.
    var targetingActives: [Active] {
        switch self {
        case .breakouts:
            return [.salicylicAcid, .benzoylPeroxide, .niacinamide, .azelaicAcid, .retinoid]
        case .unevenTexture:
            return [.glycolicAcid, .lacticAcid, .salicylicAcid, .retinoid]
        case .hyperpigmentation:
            return [.vitaminC, .azelaicAcid, .niacinamide, .retinoid, .glycolicAcid]
        case .dullness:
            return [.vitaminC, .glycolicAcid, .lacticAcid, .niacinamide]
        case .dryness:
            return [.hyaluronicAcid, .ceramides, .squalane, .glycerin]
        case .oiliness:
            return [.niacinamide, .salicylicAcid, .clay]
        case .rednessSensitivity:
            return [.niacinamide, .centella, .ceramides, .azelaicAcid]
        case .fineLines:
            return [.retinoid, .peptides, .vitaminC, .hyaluronicAcid]
        case .largePores:
            return [.salicylicAcid, .niacinamide, .clay, .retinoid]
        }
    }
}
