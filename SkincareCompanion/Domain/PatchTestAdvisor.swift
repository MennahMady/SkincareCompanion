//
//  PatchTestAdvisor.swift
//  SkincareCompanion
//
//  Dermatologist-cited guidance is to introduce one new active at a time
//  so a reaction can actually be traced back to something — this flags
//  when the bag picked up multiple active-containing products in a
//  short window, which is exactly the situation that makes a reaction
//  untraceable. A nudge, not a block: nothing here prevents adding a
//  product, it just surfaces the tradeoff.
//

import Foundation

struct PatchTestAdvisory {
    let recentActiveProducts: [Product]
    let windowDays: Int
}

enum PatchTestAdvisor {
    /// `items` pairs each product with when it was added to the bag.
    /// Flags when 2+ active-containing products were added within
    /// `windowDays` of `asOf` (today, by default).
    static func advisory(items: [(product: Product, dateAdded: Date)], asOf date: Date = .now, windowDays: Int = 7, calendar: Calendar = .current) -> PatchTestAdvisory? {
        guard let cutoff = calendar.date(byAdding: .day, value: -windowDays, to: date) else { return nil }

        let recentActive = items
            .filter { $0.dateAdded >= cutoff && $0.dateAdded <= date && !$0.product.detectedActives.isEmpty }
            .map { $0.product }

        guard recentActive.count >= 2 else { return nil }
        return PatchTestAdvisory(recentActiveProducts: recentActive, windowDays: windowDays)
    }
}
