//
//  RecommendationDetailView.swift
//  SkincareCompanion
//
//  Tapping a "You Might Need" recommendation (e.g. "try a treatment for
//  breakouts") lands here: real candidate products from the curated
//  starter set for that category, ranked by how many of the concern's
//  targeting actives each one actually contains. This is a single-user,
//  offline app with no purchase history or other users to draw a "people
//  who bought X also bought Y" signal from — the honest, buildable
//  equivalent is ranking by ingredient fit against the concern itself,
//  which is what this screen does.
//

import SwiftUI
import SwiftData

struct RecommendationDetailView: View {
    let recommendation: Recommendation

    @Environment(\.modelContext) private var modelContext
    @Query private var bagItems: [BagItem]

    private var addedIDs: Set<String> {
        Set(bagItems.map(\.id))
    }

    private struct Match: Identifiable {
        let product: Product
        let percent: Int
        var id: String { product.id }
    }

    private var matches: [Match] {
        let candidates = CuratedProductStore.all.filter { $0.category == recommendation.missingCategory }
        let wanted = Set(recommendation.suggestedActives)
        return candidates
            .map { product -> Match in
                if wanted.isEmpty {
                    // A plain category gap (e.g. "you have no cleanser
                    // at all") — every candidate is an equally valid fix.
                    return Match(product: product, percent: 100)
                }
                let overlap = product.detectedActives.intersection(wanted)
                let percent = Int((Double(overlap.count) / Double(wanted.count) * 100).rounded())
                return Match(product: product, percent: percent)
            }
            .sorted { $0.percent == $1.percent ? $0.product.name < $1.product.name : $0.percent > $1.percent }
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(recommendation.reason)
                        .font(.cuteBody())
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 4)

                    if matches.isEmpty {
                        Text("No matching products in the starter set for this yet — try Search for a specific product instead.")
                            .font(.cuteCaption())
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 8)
                    } else {
                        Text("Match % = how many of the actives this concern usually calls for (\(RoutineEngine.naturalList(recommendation.suggestedActives))) that product actually has.")
                            .font(.cuteCaption(11))
                            .foregroundStyle(Theme.textSecondary)

                        ForEach(matches.prefix(20)) { match in
                            let isAdded = addedIDs.contains(match.product.id)
                            Button {
                                toggle(match.product, isAdded: isAdded)
                            } label: {
                                MatchRow(product: match.product, percent: match.percent, isAdded: isAdded)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(recommendation.missingCategory.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ product: Product, isAdded: Bool) {
        if isAdded {
            if let existing = bagItems.first(where: { $0.id == product.id }) {
                modelContext.delete(existing)
            }
        } else {
            modelContext.insert(BagItem(product: product))
        }
        try? modelContext.save()
    }
}

private struct MatchRow: View {
    let product: Product
    let percent: Int
    var isAdded: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(.cuteBody()).foregroundStyle(Theme.textPrimary)
                if let brand = product.brand {
                    Text(brand).font(.cuteCaption()).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            // Explicit foregroundStyle here matters more than it looks —
            // this Text is a Button's label, and an unstyled Text inside
            // a Button can pick up the ambient tint color instead of a
            // normal readable one, which is exactly what made this badge
            // nearly invisible against its own pastel background on a
            // real device.
            Text("\(percent)% match")
                .font(.cuteCaption(11))
                .foregroundStyle(Theme.onAccentText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(percent >= 66 ? Theme.mint.opacity(0.7) : Theme.peach.opacity(0.7)))
            Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(isAdded ? Theme.mint : Theme.accent)
        }
        .cuteCard()
    }
}
