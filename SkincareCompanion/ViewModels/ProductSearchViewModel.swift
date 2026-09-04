//
//  ProductSearchViewModel.swift
//  SkincareCompanion
//
//  Debounced search-as-you-type against Open Beauty Facts. Runs on the
//  main actor since it publishes directly to SwiftUI, but the actual
//  network call happens off the calling task via the injected service.
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

    init(service: ProductSearching = OpenBeautyFactsService()) {
        self.service = service
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            isLoading = false
            return
        }

        searchTask = Task { [weak self] in
            guard let self else { return }
            // Debounce: wait a beat in case the user is still typing.
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }

            self.isLoading = true
            self.errorMessage = nil
            do {
                let products = try await self.service.searchProducts(matching: trimmed)
                guard !Task.isCancelled else { return }
                self.results = products
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
                self.results = []
            }
            self.isLoading = false
        }
    }
}
