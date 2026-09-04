//
//  OpenBeautyFactsDTOs.swift
//  SkincareCompanion
//
//  Codable wire types for Open Beauty Facts (https://world.openbeautyfacts.org),
//  a free, keyless, community-maintained cosmetics database (sister project
//  to Open Food Facts). We only decode the fields we actually use — OBF
//  responses carry dozens of fields we don't need.
//
//  Search: GET https://world.openbeautyfacts.org/cgi/search.pl
//            ?search_terms=<query>&search_simple=1&action=process&json=1&page_size=20
//  Barcode lookup: GET https://world.openbeautyfacts.org/api/v2/product/<barcode>.json
//

import Foundation

struct OBFSearchResponse: Codable {
    let products: [OBFProduct]
}

struct OBFProductResponse: Codable {
    let status: Int?
    let product: OBFProduct?
}

struct OBFProduct: Codable {
    let code: String?
    let productName: String?
    let brands: String?
    let ingredientsText: String?
    let categoriesTags: [String]?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case ingredientsText = "ingredients_text"
        case categoriesTags = "categories_tags"
        case imageURL = "image_url"
    }

    /// Maps the raw API payload into our internal Product model. Returns
    /// nil for entries too sparse to be useful (no name).
    func toProduct() -> Product? {
        guard let name = productName, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }
        let id = code ?? UUID().uuidString
        let category = ProductCategory.infer(fromCategoryTags: categoriesTags ?? [])
        return Product(
            id: id,
            name: name,
            brand: brands,
            ingredientsText: ingredientsText,
            category: category,
            imageURL: imageURL.flatMap(URL.init(string:)),
            source: .openBeautyFacts
        )
    }
}
