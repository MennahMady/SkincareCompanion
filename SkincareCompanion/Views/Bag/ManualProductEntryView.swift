//
//  ManualProductEntryView.swift
//  SkincareCompanion
//
//  Fallback for products that aren't in Open Beauty Facts (common for
//  smaller/indie brands). The ingredients field is optional but drives
//  active-ingredient detection, so we nudge the user to paste it from
//  the product's packaging if they have it handy.
//

import SwiftUI
import SwiftData

struct ManualProductEntryView: View {
    @Environment(\.modelContext) private var modelContext
    let onAdd: () -> Void

    @State private var name = ""
    @State private var brand = ""
    @State private var category: ProductCategory = .serum
    @State private var ingredientsText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Product Details", systemImage: "tag.fill")
                        .font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)

                    cuteField("Name", text: $name)
                    cuteField("Brand (optional)", text: $brand)

                    Text("Category").font(.cuteCaption()).foregroundStyle(Theme.textSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ProductCategory.allCases) { cat in
                                Button {
                                    category = cat
                                } label: {
                                    Text(cat.displayName)
                                        .font(.cuteCaption(13))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(category == cat ? Theme.accent : Theme.mint.opacity(0.6)))
                                        .foregroundStyle(category == cat ? .white : Theme.textPrimary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .cuteCard()

                VStack(alignment: .leading, spacing: 8) {
                    Label("Ingredients (optional)", systemImage: "list.bullet.clipboard.fill")
                        .font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
                    Text("Paste it from the box or bottle — we'll spot actives like retinol, niacinamide, or vitamin C automatically. ✨")
                        .font(.cuteCaption())
                        .foregroundStyle(Theme.textSecondary)
                    TextEditor(text: $ingredientsText)
                        .font(.cuteBody(14))
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                }
                .cuteCard(tint: Theme.peach.opacity(0.4))

                Button("Add to Bag 🎀", action: save)
                    .buttonStyle(CuteButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding()
        }
    }

    private func cuteField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.cuteBody())
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cream))
    }

    private func save() {
        let product = Product.manual(
            name: name,
            brand: brand.isEmpty ? nil : brand,
            category: category,
            ingredientsText: ingredientsText.isEmpty ? nil : ingredientsText
        )
        modelContext.insert(BagItem(product: product))
        try? modelContext.save()
        onAdd()
    }
}
