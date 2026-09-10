//
//  ProductSearchViewModel.swift
//  SkincareCompanion
//
//  Debounced search-as-you-type against Open Beauty Facts, merged with
//  the bundled CuratedProductStore. The curated set is searched
//  synchronously and shown instantly (no network round trip); the live
//  API results are appended once they arrive, deduplicated against
//  whatever the curated set already matched.
//

import Foundation
import Combine

@MainActor
final class ProductSearchViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet { scheduleSearch() }
    }
    @Published private(set) var results: [Product] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: ProductSearching
    private var searchTask: Task<Void, Never>?

    // Deliberately NOT `init(service: ProductSearching = OpenBeautyFactsService())`.
    // Default parameter *values* are evaluated in a nonisolated context by
    // the Swift compiler even when the initializer itself runs on the
    // main actor (this class is @MainActor) — so constructing
    // OpenBeautyFactsService there trips "call to main-actor-isolated
    // initializer in a synchronous nonisolated context" under newer
    // Xcode's stricter concurrency checking. Falling back inside the
    // init body instead runs on the main actor, where it's allowed.
    init(service: ProductSearching? = nil) {
        self.service = service ?? OpenBeautyFactsService()
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            isLoading = false
            errorMessage = nil
            return
        }

        // Curated results are local and instant — show them right away
        // rather than waiting on the debounce + network round trip.
        let curatedMatches = CuratedProductStore.search(matching: trimmed)
        results = curatedMatches
        errorMessage = nil

        searchTask = Task { [weak self] in
            guard let self else { return }
            // Debounce: wait a beat in case the user is still typing.
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }

            // Only show the spinner if we have nothing on screen yet —
            // if curated already matched something, let it sit there
            // uninterrupted while live results load in behind it.
            self.isLoading = curatedMatches.isEmpty

            do {
                let apiProducts = try await self.service.searchProducts(matching: trimmed)
                guard !Task.isCancelled else { return }
                self.results = Self.merge(curated: curatedMatches, api: apiProducts)
            } catch {
                guard !Task.isCancelled else { return }
                // If curated already found something, a live-search
                // failure (offline, API hiccup) shouldn't wipe that out.
                if curatedMatches.isEmpty {
                    self.errorMessage = error.localizedDescription
                }
            }
            self.isLoading = false
        }
    }

    /// Combines the two result sets, keeping curated entries first and
    /// dropping any live-search result that's clearly the same product
    /// (matched by lowercased name + brand).
    private static func merge(curated: [Product], api: [Product]) -> [Product] {
        var seen = Set(curated.map(dedupeKey))
        var combined = curated
        for product in api where !seen.contains(dedupeKey(for: product)) {
            seen.insert(dedupeKey(for: product))
            combined.append(product)
        }
        return combined
    }

    private static func dedupeKey(for product: Product) -> String {
        "\(product.name.lowercased())|\(product.brand?.lowercased() ?? "")"
    }
}
