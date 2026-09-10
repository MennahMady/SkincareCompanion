//
//  Product.swift
//  SkincareCompanion
//
//  A lightweight, storage-agnostic representation of a product, built
//  either from an Open Beauty Facts API response or from manual entry.
//  This is what search results and the "add to bag" flow work with;
//  BagItem (a SwiftData model) snapshots the fields it needs from this
//  struct when the user actually saves it to their bag.
//

import Foundation

struct Product: Identifiable, Hashable, Codable {
    /// Barcode when it came from Open Beauty Facts; a generated UUID
    /// string for manually-entered products.
    let id: String
    var name: String
    var brand: String?
    var ingredientsText: String?
    var category: ProductCategory
    var imageURL: URL?
    var source: Source

    enum Source: String, Codable {
        case openBeautyFacts
        case manual
        case curated
    }

    var detectedActives: Set<Active> {
        Active.detect(in: ingredientsText)
    }

    /// Best-guess skin types this product suits, inferred from its
    /// category and ingredients — see SkinTypeSuitability for the
    /// (heuristic, not verified) reasoning.
    var suitableSkinTypes: [SkinType] {
        SkinTypeSuitability.infer(category: category, ingredientsText: ingredientsText, detectedActives: detectedActives)
    }

    static func manual(name: String, brand: String?, category: ProductCategory, ingredientsText: String?) -> Product {
        Product(
            id: UUID().uuidString,
            name: name,
            brand: brand,
            ingredientsText: ingredientsText,
            category: category,
            imageURL: nil,
            source: .manual
        )
    }
}
