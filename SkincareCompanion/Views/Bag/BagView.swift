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
    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []

    private var groupedItems: [(ProductCategory, [BagItem])] {
        let groups = Dictionary(grouping: bagItems, by: { $0.category })
        return ProductCategory.allCases.compactMap { category in
            guard let items = groups[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    /// Flags when 2+ active-containing products were added to the bag
    /// in a short window — see PatchTestAdvisor. A nudge, not a block.
    private var patchTestAdvisory: PatchTestAdvisory? {
        PatchTestAdvisor.advisory(items: bagItems.map { ($0.asProduct, $0.dateAdded) })
    }

    private var expiringOrExpiredItems: [BagItem] {
        bagItems.filter { $0.isLikelyExpired || $0.isExpiringSoon }
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
                            if let advisory = patchTestAdvisory {
                                PatchTestAdvisoryCard(advisory: advisory)
                            }
                            if !expiringOrExpiredItems.isEmpty {
                                ExpiringSoonCard(items: expiringOrExpiredItems)
                            }
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
                                            if isSelecting {
                                                Button {
                                                    toggleSelection(item)
                                                } label: {
                                                    BagItemRow(
                                                        item: item,
                                                        tint: Theme.pastel(for: index),
                                                        isSelecting: true,
                                                        isSelected: selectedIDs.contains(item.id)
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                            } else {
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
                        }
                        .padding()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                CuteGlassHeader("My Bag 🎀") {
                    if !bagItems.isEmpty {
                        Button(isSelecting ? "Deselect All" : "Select") {
                            if isSelecting {
                                selectedIDs.removeAll()
                            } else {
                                isSelecting = true
                            }
                        }
                        .buttonStyle(CuteGlassPillButtonStyle())
                    }
                } trailing: {
                    if isSelecting {
                        Button("Cancel") { exitSelection() }
                            .buttonStyle(CuteGlassPillButtonStyle())
                    } else {
                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(10)
                        }
                        .background(
                            Circle()
                                .fill(Theme.accent)
                                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                                .shadow(color: Theme.blushDeep.opacity(0.3), radius: 6, x: 0, y: 3)
                        )
                    }
                }
            }
            // Deliberately NOT a `.toolbar { ToolbarItemGroup(placement:
            // .bottomBar) }` here — on iOS's floating/"glass" tab bar
            // style, a bottom-bar toolbar can render underneath and
            // overlap the tab bar itself instead of sitting in its own
            // space above it, turning into an unreadable jumble of both.
            // `.safeAreaInset(edge: .bottom)` reserves genuine space for
            // this bar above the tab bar instead of fighting it for the
            // same strip of screen.
            .safeAreaInset(edge: .bottom) {
                if isSelecting {
                    HStack {
                        Text(selectedIDs.isEmpty ? "Select products" : "\(selectedIDs.count) selected")
                            .font(.cuteCaption(13))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Button(role: .destructive) {
                            deleteSelected()
                        } label: {
                            Text("Remove")
                                .font(.cuteHeadline(14))
                        }
                        .disabled(selectedIDs.isEmpty)
                        .opacity(selectedIDs.isEmpty ? 0.4 : 1)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(.regularMaterial)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddProductSheet()
            }
        }
    }

    private func toggleSelection(_ item: BagItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    private func exitSelection() {
        isSelecting = false
        selectedIDs.removeAll()
    }

    private func deleteSelected() {
        for item in bagItems where selectedIDs.contains(item.id) {
            modelContext.delete(item)
        }
        try? modelContext.save()
        exitSelection()
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
    var isSelecting: Bool = false
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.5))
                AsyncImage(url: item.imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fit)
                            .padding(4)
                            .frame(width: 46, height: 46)
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

            if !isSelecting {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .cuteCard()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .stroke(isSelected ? Theme.accent : .clear, lineWidth: 2)
        )
    }
}

/// Nudges toward introducing new actives one at a time — see
/// PatchTestAdvisor. Deliberately not dismissible/persisted as
/// "acknowledged" — it's cheap enough to just re-derive from the bag's
/// actual state each time, so it naturally goes away once the window
/// passes.
private struct PatchTestAdvisoryCard: View {
    let advisory: PatchTestAdvisory

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Multiple new actives at once", systemImage: "exclamationmark.triangle.fill")
                .font(.cuteHeadline(14)).foregroundStyle(Theme.textPrimary)
            Text("You've added \(advisory.recentActiveProducts.count) active-containing products in the last \(advisory.windowDays) days (\(advisory.recentActiveProducts.map { $0.name }.joined(separator: ", "))). Introducing one new active at a time makes it much easier to tell what's actually causing a reaction, if one shows up.")
                .font(.cuteCaption(12))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cuteCard(tint: Theme.peach.opacity(0.5))
    }
}

/// Surfaces bag items whose estimated PAO (Period After Opening) expiry
/// has passed or is coming up soon — see ProductLifecycle.
private struct ExpiringSoonCard: View {
    let items: [BagItem]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Expiring Soon", systemImage: "hourglass").font(.cuteHeadline(14)).foregroundStyle(Theme.textPrimary)
            ForEach(items) { item in
                HStack {
                    Text(item.name).font(.cuteCaption(13)).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if let expiry = item.estimatedExpiryDate {
                        Text(item.isLikelyExpired ? "Expired \(Self.dateFormatter.string(from: expiry))" : "Expires \(Self.dateFormatter.string(from: expiry))")
                            .font(.cuteCaption(11))
                            .foregroundStyle(item.isLikelyExpired ? Theme.blushDeep : Theme.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cuteCard(tint: Theme.cream)
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
