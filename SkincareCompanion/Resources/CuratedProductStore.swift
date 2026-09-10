//
//  CuratedProductStore.swift
//  SkincareCompanion
//
//  A small, hand-curated set of well-known skincare products bundled
//  directly with the app (Resources/CuratedProducts.json). Open Beauty
//  Facts' community-tagged catalog has decent coverage for mass-market
//  brands but very thin coverage for premium/indie brands — this store
//  exists to guarantee a set of recognizable products across every
//  price point show up in search even when OBF has nothing for them.
//
//  Ingredient lists here were hand-entered from publicly published
//  product information to demonstrate the app's active-ingredient
//  detection and routine building — they are a good-faith approximation
//  for a portfolio project, not a guaranteed-current formulation
//  record. A real product would source this from a licensed ingredient
//  database or the brand's own API. Always defer to the actual product
//  packaging.
//
//  ProductSearchViewModel merges this local, instant result set with
//  the live Open Beauty Facts search so users get the best of both:
//  guaranteed known products immediately, plus everything else Open
//  Beauty Facts can find.
//

import Foundation

enum CuratedProductStore {

    private struct Entry: Decodable {
        let name: String
        let brand: String
        let category: String
        let ingredientsText: String
    }

    static let all: [Product] = {
        guard
            let url = Bundle.main.url(forResource: "CuratedProducts", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else {
            return []
        }

        return entries.map { entry in
            let slug = "\(entry.brand)-\(entry.name)"
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
            return Product(
                id: "curated-\(slug)",
                name: entry.name,
                brand: entry.brand,
                ingredientsText: entry.ingredientsText,
                category: ProductCategory(rawValue: entry.category) ?? .other,
                imageURL: nil,
                source: .curated
            )
        }
    }()

    /// Case-insensitive substring match over name and brand — kept
    /// intentionally simple since the bundled set is small (tens, not
    /// thousands, of products) and doesn't need fuzzy matching.
    static func search(matching query: String) -> [Product] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }
        return all.filter {
            $0.name.lowercased().contains(needle) || ($0.brand?.lowercased().contains(needle) ?? false)
        }
    }
}
