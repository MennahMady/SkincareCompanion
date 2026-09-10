//
//  ProductSearchView.swift
//  SkincareCompanion
//
//  Search-as-you-type against Open Beauty Facts; tapping a result adds
//  it to the bag as a BagItem. Presented inside AddProductSheet.
//

import SwiftUI
import SwiftData

struct AddProductSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .search

    enum Mode: String, CaseIterable {
        case search = "🔍 Search"
        case scan = "📷 Scan"
        case manual = "✏️ Enter Manually"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        ForEach(Mode.allCases, id: \.self) { option in
                            Button {
                                mode = option
                            } label: {
                                Text(option.rawValue)
                                    .font(.cuteCaption(14))
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(mode == option ? .white : Theme.onAccentText)
                                    .glass(
                                        cornerRadius: 100,
                                        tint: mode == option ? Theme.accent : .white,
                                        tintOpacity: mode == option ? 0.65 : 0.25,
                                        material: mode == option ? .regularMaterial : .ultraThinMaterial
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()

                    switch mode {
                    case .search:
                        ProductSearchView()
                    case .scan:
                        ProductScannerView()
                    case .manual:
                        ManualProductEntryView(onAdd: { dismiss() })
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                CuteGlassHeader("Add Products") {
                    Button("Close") { dismiss() }
                        .buttonStyle(CuteGlassPillButtonStyle())
                } trailing: {
                    Button("Done") { dismiss() }
                        .buttonStyle(CuteGlassPillButtonStyle())
                }
            }
        }
    }
}

struct ProductSearchView: View {
    @StateObject private var viewModel = ProductSearchViewModel()
    @Environment(\.modelContext) private var modelContext
    @Query private var bagItems: [BagItem]

    private var addedIDs: Set<String> {
        Set(bagItems.map(\.id))
    }

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
                TextField("Try \"vitamin c serum\" 💫", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.cuteBody())
                    .foregroundStyle(Theme.onAccentText)
                    .tint(Theme.accent)
                    .autocorrectionDisabled()
            }
            .padding(12)
            .glass(cornerRadius: 16, tint: .white, tintOpacity: 0.3)
            .padding(.horizontal)

            if viewModel.isLoading {
                ProgressView().tint(Theme.accent).padding(.top, 24)
                Spacer()
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Text("😖 Something went wrong").font(.cuteHeadline())
                    Text(error).font(.cuteBody()).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else if viewModel.results.isEmpty && viewModel.query.count >= 2 {
                Text("No matches yet — try a different search, or enter it manually. 🌷")
                    .font(.cuteBody())
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .padding(.horizontal, 32)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, product in
                            let isAdded = addedIDs.contains(product.id)
                            Button {
                                toggle(product, isAdded: isAdded)
                            } label: {
                                SearchResultRow(product: product, tint: Theme.pastel(for: index), isAdded: isAdded)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .padding(.bottom, 8)

                    if !addedIDs.isEmpty {
                        Text("\(addedIDs.count) added — tap **Done** when you're finished 🎀")
                            .font(.cuteCaption())
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.bottom, 16)
                    }
                }
            }
        }
    }

    /// Tapping a result adds it; tapping an already-added result removes
    /// it again. The sheet stays open the whole time so several products
    /// can be added in one pass — closing it (via Done/Close) is what
    /// ends the session, not each individual tap.
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

private struct SearchResultRow: View {
    let product: Product
    var tint: Color = Theme.blush
    var isAdded: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.5))
                AsyncImage(url: product.imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fit)
                            .padding(4)
                            .frame(width: 46, height: 46)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "sparkle").foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(.cuteBody()).foregroundStyle(Theme.textPrimary)
                if let brand = product.brand {
                    Text(brand).font(.cuteCaption()).foregroundStyle(Theme.textSecondary)
                }
                HStack(spacing: 6) {
                    Text(product.category.displayName)
                        .font(.cuteCaption())
                        .foregroundStyle(Theme.lavenderDeep)
                    if let firstSkinType = product.suitableSkinTypes.first, product.suitableSkinTypes.count < SkinType.allCases.count {
                        Text("· \(firstSkinType.displayName)\(product.suitableSkinTypes.count > 1 ? "+" : "")")
                            .font(.cuteCaption(11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if product.source == .curated {
                        Text("STARTER SET")
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.onAccentTextSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.mint.opacity(0.7)))
                    }
                }
            }

            Spacer()
            Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(isAdded ? Theme.mint : Theme.accent)
        }
        .cuteCard()
        .opacity(isAdded ? 0.85 : 1)
    }
}
