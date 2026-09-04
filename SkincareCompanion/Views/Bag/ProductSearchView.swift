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
                                    .background(
                                        Capsule().fill(mode == option ? Theme.accent : Color.white)
                                    )
                                    .foregroundStyle(mode == option ? .white : Theme.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()

                    switch mode {
                    case .search:
                        ProductSearchView(onAdd: { dismiss() })
                    case .manual:
                        ManualProductEntryView(onAdd: { dismiss() })
                    }
                }
            }
            .navigationTitle("Add a Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct ProductSearchView: View {
    @StateObject private var viewModel = ProductSearchViewModel()
    @Environment(\.modelContext) private var modelContext
    let onAdd: () -> Void

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
                TextField("Try \"vitamin c serum\" 💫", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.cuteBody())
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
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
                            Button {
                                add(product)
                            } label: {
                                SearchResultRow(product: product, tint: Theme.pastel(for: index))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func add(_ product: Product) {
        let item = BagItem(product: product)
        modelContext.insert(item)
        try? modelContext.save()
        onAdd()
    }
}

private struct SearchResultRow: View {
    let product: Product
    var tint: Color = Theme.blush

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.5))
                AsyncImage(url: product.imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
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
                Text(product.category.displayName)
                    .font(.cuteCaption())
                    .foregroundStyle(Theme.lavenderDeep)
            }

            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.accent)
        }
        .cuteCard()
    }
}
