//
//  OpenBeautyFactsService.swift
//  SkincareCompanion
//
//  Thin async/await client for the Open Beauty Facts REST API. No API
//  key is required. `URLSessionProtocol` is injected so tests can swap
//  in a mock (see SkincareCompanionTests/OpenBeautyFactsServiceTests.swift)
//  without hitting the network.
//

import Foundation

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

protocol ProductSearching {
    func searchProducts(matching query: String) async throws -> [Product]
    func fetchProduct(barcode: String) async throws -> Product
}

// `nonisolated` here is deliberate: newer Xcode versions can default a
// whole target's actor isolation to @MainActor (a project-level Swift 6
// concurrency setting). This is a plain networking client with no UI or
// shared mutable state — it shouldn't be forced onto the main actor, and
// leaving it implicitly MainActor-isolated is what caused "call to
// main-actor-isolated initializer 'init(session:)' in a synchronous
// nonisolated context" wherever it was constructed with a default
// argument (see ProductSearchViewModel's init).
nonisolated final class OpenBeautyFactsService: ProductSearching {

    private let session: URLSessionProtocol
    private let baseHost = "world.openbeautyfacts.org"
    private let decoder: JSONDecoder

    init(session: URLSessionProtocol = URLSession.shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    /// Free-text search across Open Beauty Facts. We deliberately do NOT
    /// also filter by category tag here: OBF's category tagging is
    /// crowd-sourced and inconsistent (see README "Known limitations"),
    /// and an additional "must be tagged skin care" filter combined with
    /// a text search was found to return zero results for most real
    /// queries. `ProductCategory.infer` does its best to classify
    /// whatever comes back, and the user can always correct a product's
    /// category after adding it (see ProductDetailView).
    func searchProducts(matching query: String) async throws -> [Product] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = baseHost
        components.path = "/cgi/search.pl"
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "24")
        ]

        guard let url = components.url else { throw NetworkError.invalidURL }

        let response: OBFSearchResponse = try await performRequest(url: url)
        return response.products.compactMap { $0.toProduct() }
    }

    /// Looks a single product up by its barcode (e.g. from a camera
    /// scan, if barcode scanning is added later).
    func fetchProduct(barcode: String) async throws -> Product {
        var components = URLComponents()
        components.scheme = "https"
        components.host = baseHost
        components.path = "/api/v2/product/\(barcode).json"

        guard let url = components.url else { throw NetworkError.invalidURL }

        let response: OBFProductResponse = try await performRequest(url: url)
        guard let obfProduct = response.product, let product = obfProduct.toProduct() else {
            throw NetworkError.notFound
        }
        return product
    }

    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        // OBF asks integrators to identify themselves in a header rather
        // than requiring a key: https://world.openbeautyfacts.org/data
        request.setValue("SkincareCompanion-iOS - Version 1.0", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.requestFailed(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(underlying: URLError(.badServerResponse))
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.badStatusCode(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(underlying: error)
        }
    }
}
