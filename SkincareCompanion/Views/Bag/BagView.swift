//
//  BagView.swift
//  SkincareCompanion
//
//  Lists everything the user owns, grouped by category. Uses @Query
//  directly (idiomatic SwiftData) rather than routing simple CRUD
//  through a ViewModel layer.
//

import SwiftUI
import SwiftData

struct BagView: View {
    @Query(sort: \BagItem.dateAdded, order: .reverse) private var bagItems: [BagItem]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddSheet = false

    private var groupedItems: [(ProductCategory, [BagItem])] {
        let groups = Dictionary(grouping: bagItems, by: { $0.category })
        return ProductCategory.allCases.compactMap { category in
            guard let items = groups[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                if bagItems.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(Array(groupedItems.enumerated()), id: \.element.0) { index, group in
                                let (category, items) = group
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Circle().fill(Theme.pastel(for: index)).frame(width: 8, height: 8)
                                        Text(category.displayName)
                                            .font(.cuteHeadline())
                                            .foregroundStyle(Theme.textPrimary)
                                        Spacer()
                                        Text("\(items.count)")
                                            .font(.cuteCaption())
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    .padding(.horizontal, 4)

                                    VStack(spacing: 8) {
                                        ForEach(items) { item in
                                            NavigationLink {
                                                ProductDetailView(item: item)
                                            } label: {
                                                BagItemRow(item: item, tint: Theme.pastel(for: index))
                                            }
                                            .buttonStyle(.plain)
                                            .contextMenu {
                                                Button("Remove", role: .destructive) { delete(item) }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Bag 🎀")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddProductSheet()
            }
        }
    }

    private var emptyState: some View {
        CuteEmptyState(
            emoji: "🧴",
            title: "Your bag is empty",
            message: "Add the products you already own so we can build a routine from what you actually have.",
            actionTitle: "Add a Product"
        ) {
            showingAddSheet = true
        }
    }

    private func delete(_ item: BagItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

private struct BagItemRow: View {
    let item: BagItem
    var tint: Color = Theme.blush

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.5))
                AsyncImage(url: item.imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "sparkle")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.cuteBody()).foregroundStyle(Theme.textPrimary)
                if let brand = item.brand {
                    Text(brand).font(.cuteCaption()).foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            if !item.detectedActives.isEmpty {
                CutePill(text: "\(item.detectedActives.count)", tint: tint, icon: "sparkle")
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .cuteCard()
    }
}

/// Reusable pastel empty-state used across tabs — a big emoji instead
/// of a plain SF Symbol keeps things feeling soft and friendly.
struct CuteEmptyState: View {
    let emoji: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(emoji).font(.system(size: 56))
            Text(title).font(.cuteTitle(22)).foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.cuteBody())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(actionTitle, action: action)
                .buttonStyle(CuteButtonStyle())
                .padding(.horizontal, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    BagView()
        .modelContainer(for: [BagItem.self], inMemory: true)
}
