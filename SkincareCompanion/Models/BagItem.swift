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

// CloudKit-backed SwiftData requires every non-optional attribute to
// carry a default value at its declaration (not just in `init`) — see
// SkincareCompanionApp's CloudKit sync section for why.
@Model
final class BagItem {
    var id: String = ""
    var name: String = ""
    var brand: String?
    var ingredientsText: String?
    var categoryRaw: String = ProductCategory.other.rawValue
    var imageURLString: String?
    var sourceRaw: String = Product.Source.manual.rawValue
    var dateAdded: Date = Date.now

    /// PAO (Period After Opening) tracking — the "12M" jar icon on
    /// packaging. Both optional since most products won't have this
    /// filled in; see ProductLifecycle for the expiry math.
    var openedDate: Date?
    var paoMonths: Int?

    init(product: Product, dateAdded: Date = .now) {
        self.id = product.id
        self.name = product.name
        self.brand = product.brand
        self.ingredientsText = product.ingredientsText
        self.categoryRaw = product.category.rawValue
        self.imageURLString = product.imageURL?.absoluteString
        self.sourceRaw = product.source.rawValue
        self.dateAdded = dateAdded
        self.openedDate = nil
        self.paoMonths = nil
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

    var suitableSkinTypes: [SkinType] {
        SkinTypeSuitability.infer(category: category, ingredientsText: ingredientsText, detectedActives: detectedActives)
    }

    var estimatedExpiryDate: Date? {
        ProductLifecycle.estimatedExpiryDate(openedDate: openedDate, paoMonths: paoMonths)
    }

    var isLikelyExpired: Bool {
        ProductLifecycle.isLikelyExpired(openedDate: openedDate, paoMonths: paoMonths)
    }

    var isExpiringSoon: Bool {
        ProductLifecycle.isExpiringSoon(openedDate: openedDate, paoMonths: paoMonths)
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
