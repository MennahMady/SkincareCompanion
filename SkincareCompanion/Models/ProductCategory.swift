//
//  ProductCategory.swift
//  SkincareCompanion
//
//  The step categories a product can occupy in a routine, in the order
//  they're typically applied (thinnest/most-active-first, occlusive-last).
//

import Foundation

enum ProductCategory: String, CaseIterable, Codable, Identifiable {
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

    /// Lower sorts earlier within a single AM or PM session.
    var applicationOrder: Int {
        switch self {
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

    var displayName: String {
        switch self {
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
