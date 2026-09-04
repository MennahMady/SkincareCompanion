//
//  BagItem.swift
//  SkincareCompanion
//
//  A product the user owns, persisted with SwiftData. Stores a snapshot
//  of the fields we need rather than re-fetching from the network every
//  launch — the API is a catalog to search, not a live source of truth
//  for what's already in someone's bag.
//

import Foundation
import SwiftData

@Model
final class BagItem {
    var id: String
    var name: String
    var brand: String?
    var ingredientsText: String?
    var categoryRaw: String
    var imageURLString: String?
    var sourceRaw: String
    var dateAdded: Date

    init(product: Product, dateAdded: Date = .now) {
        self.id = product.id
        self.name = product.name
        self.brand = product.brand
        self.ingredientsText = product.ingredientsText
        self.categoryRaw = product.category.rawValue
        self.imageURLString = product.imageURL?.absoluteString
        self.sourceRaw = product.source.rawValue
        self.dateAdded = dateAdded
    }

    var category: ProductCategory {
        get { ProductCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var source: Product.Source {
        Product.Source(rawValue: sourceRaw) ?? .manual
    }

    var imageURL: URL? {
        imageURLString.flatMap(URL.init(string:))
    }

    var detectedActives: Set<Active> {
        Active.detect(in: ingredientsText)
    }

    /// Converts back to the lightweight Product struct the routine
    /// engine and search UI operate on.
    var asProduct: Product {
        Product(
            id: id,
            name: name,
            brand: brand,
            ingredientsText: ingredientsText,
            category: category,
            imageURL: imageURL,
            source: source
        )
    }
}
