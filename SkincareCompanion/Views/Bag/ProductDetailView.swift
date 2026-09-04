//
//  ProductDetailView.swift
//  SkincareCompanion
//
//  Shows a bag item's detail, including which actives were detected
//  from its ingredients text and lets the user correct the category
//  if our inference (from OBF tags, or manual entry) got it wrong.
//

import SwiftUI
import SwiftData

struct ProductDetailView: View {
    @Bindable var item: BagItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if let url = item.imageURL {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fit)
                            } else {
                                Color.white
                            }
                        }
                        .frame(maxHeight: 160)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: Theme.cardCornerRadius).fill(Color.white))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.name).font(.cuteTitle(20)).foregroundStyle(Theme.textPrimary)
                        if let brand = item.brand {
                            Text(brand).font(.cuteBody()).foregroundStyle(Theme.textSecondary)
                        }

                        Text("Category").font(.cuteCaption()).foregroundStyle(Theme.textSecondary).padding(.top, 6)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ProductCategory.allCases) { cat in
                                    Button {
                                        item.category = cat
                                        try? modelContext.save()
                                    } label: {
                                        Text(cat.displayName)
                                            .font(.cuteCaption(13))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Capsule().fill(item.category == cat ? Theme.accent : Theme.lavender.opacity(0.6)))
                                            .foregroundStyle(item.category == cat ? .white : Theme.textPrimary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .cuteCard()

                    if !item.detectedActives.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Detected Actives", systemImage: "wand.and.stars")
                                .font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
                            FlexibleWrap(items: Array(item.detectedActives).sorted(by: { $0.displayName < $1.displayName })) { active, index in
                                CutePill(text: active.displayName, tint: Theme.pastel(for: index))
                            }
                        }
                        .cuteCard(tint: Theme.mint.opacity(0.5))
                    }

                    if let ingredients = item.ingredientsText, !ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Ingredients", systemImage: "list.bullet")
                                .font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
                            Text(ingredients).font(.cuteCaption(13)).foregroundStyle(Theme.textSecondary)
                        }
                        .cuteCard()
                    }

                    Button("Remove from Bag 🗑️", role: .destructive) {
                        modelContext.delete(item)
                        try? modelContext.save()
                        dismiss()
                    }
                    .buttonStyle(CuteSecondaryButtonStyle(tint: Theme.blushDeep))
                }
                .padding()
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A simple wrapping layout for pill-shaped tags — used for the
/// detected-actives list. iOS 16+ Layout protocol, so it wraps
/// naturally instead of scrolling horizontally off-screen.
struct FlexibleWrap<Item: Hashable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item, Int) -> Content

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                content(item, index)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
