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
    @State private var selectedActive: Active?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

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

                        if let prep = item.category.prepNote {
                            Text("Before this: \(prep)")
                                .font(.cuteCaption(12))
                                .foregroundStyle(Theme.lavenderDeep)
                                .padding(.top, 4)
                        }
                        if let tip = item.category.applicationTip {
                            Text("How to apply: \(tip)")
                                .font(.cuteCaption(12))
                                .foregroundStyle(Theme.lavenderDeep)
                        }
                    }
                    .cuteCard()

                    if !item.detectedActives.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Detected Actives", systemImage: "wand.and.stars")
                                .font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
                            Text("Tap one to see what it does and what it conflicts with.")
                                .font(.cuteCaption(11))
                                .foregroundStyle(Theme.textSecondary)
                            FlexibleWrap(items: Array(item.detectedActives).sorted(by: { $0.displayName < $1.displayName })) { active, index in
                                Button {
                                    selectedActive = active
                                } label: {
                                    CutePill(text: active.displayName, tint: Theme.pastel(for: index))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .cuteCard(tint: Theme.mint.opacity(0.5))
                    }

                    if item.category.hasIngredients && !item.suitableSkinTypes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Best For", systemImage: "person.fill.checkmark")
                                .font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
                            FlexibleWrap(items: item.suitableSkinTypes) { skinType, index in
                                CutePill(text: skinType.displayName, tint: Theme.pastel(for: index))
                            }
                            Text("A best-guess from this product's category and ingredients, not a verified brand claim — always patch test something new.")
                                .font(.cuteCaption(10))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .cuteCard(tint: Theme.butter.opacity(0.5))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Track Expiry", systemImage: "hourglass").font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
                        Text("Most packaging has a little jar icon like \"12M\" — how many months it's good for once opened.")
                            .font(.cuteCaption())
                            .foregroundStyle(Theme.textSecondary)

                        Toggle(isOn: Binding(
                            get: { item.openedDate != nil },
                            set: { isOn in
                                item.openedDate = isOn ? .now : nil
                                if isOn, item.paoMonths == nil { item.paoMonths = 12 }
                                try? modelContext.save()
                            }
                        )) {
                            Text("I've opened this").font(.cuteBody(14))
                        }
                        .tint(Theme.accent)

                        if item.openedDate != nil {
                            DatePicker("Opened on", selection: Binding(
                                get: { item.openedDate ?? .now },
                                set: { item.openedDate = $0; try? modelContext.save() }
                            ), displayedComponents: .date)
                            .font(.cuteCaption(13))

                            Stepper(value: Binding(
                                get: { item.paoMonths ?? 12 },
                                set: { item.paoMonths = $0; try? modelContext.save() }
                            ), in: 1...36) {
                                Text("Good for \(item.paoMonths ?? 12) months (PAO)").font(.cuteCaption(13))
                            }

                            if let expiry = item.estimatedExpiryDate {
                                Text(item.isLikelyExpired ? "Estimated to have expired \(Self.dateFormatter.string(from: expiry))." : "Estimated to expire \(Self.dateFormatter.string(from: expiry)).")
                                    .font(.cuteCaption(12))
                                    .foregroundStyle(item.isLikelyExpired ? Theme.blushDeep : Theme.textSecondary)
                            }
                        }
                    }
                    .cuteCard(tint: Theme.cream)

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
        .sheet(item: $selectedActive) { active in
            ActiveInfoSheet(active: active)
        }
    }
}

/// What an ingredient actually does, plus anything it's commonly flagged
/// for layering with — shown when someone taps a detected-active chip.
private struct ActiveInfoSheet: View {
    let active: Active

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("What It Does", systemImage: "wand.and.stars")
                            .font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
                        Text(active.whatItDoes).font(.cuteBody(14)).foregroundStyle(Theme.textSecondary)
                    }
                    .cuteCard(tint: Theme.mint.opacity(0.5))

                    if !active.knownConflicts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Watch Out For", systemImage: "exclamationmark.triangle.fill")
                                .font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
                            ForEach(Array(active.knownConflicts.enumerated()), id: \.offset) { _, conflict in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(conflict.other.displayName).font(.cuteHeadline(13)).foregroundStyle(Theme.blushDeep)
                                    Text(conflict.detail).font(.cuteCaption(12)).foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .cuteCard(tint: Theme.peach.opacity(0.5))
                    } else {
                        Text("No commonly-cited layering conflicts for this one — it plays well with most other actives.")
                            .font(.cuteCaption())
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 4)
                    }

                    Text("General educational info, not dermatological advice.")
                        .font(.cuteCaption(10))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding()
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle(active.displayName)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
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
