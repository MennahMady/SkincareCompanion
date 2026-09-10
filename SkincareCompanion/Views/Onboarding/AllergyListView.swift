//
//  AllergyListView.swift
//  SkincareCompanion
//
//  Lets the user maintain a free-text list of ingredient terms they
//  personally react to — beyond the built-in Active list, which only
//  covers common actives (retinoid, niacinamide, etc.), not a specific
//  fragrance compound, a plant extract, lanolin, a nut oil, or anything
//  else only the user themselves would know to flag. Every term here is
//  matched (case-insensitive substring) against each bag product's
//  ingredients text when a routine is generated — see
//  RoutineEngine.allergenWarnings.
//

import SwiftUI
import SwiftData

struct AllergyListView: View {
    @Query(sort: \PersonalAllergen.dateAdded) private var allergens: [PersonalAllergen]
    @Environment(\.modelContext) private var modelContext
    @State private var newTerm = ""

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Add a Term", systemImage: "plus.circle.fill")
                            .font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
                        Text("Anything you personally react to — a fragrance, an oil, an extract. We'll flag it whenever it shows up in a bag product's ingredients.")
                            .font(.cuteCaption())
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 8) {
                            TextField("e.g. lanolin, coconut oil, fragrance", text: $newTerm)
                                .font(.cuteBody())
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                            Button {
                                add()
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(Theme.accent)
                            }
                            .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .cuteCard()

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Your List", systemImage: "list.bullet")
                            .font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)

                        if allergens.isEmpty {
                            Text("Nothing added yet — your routine won't show any personal-allergen warnings until you add one.")
                                .font(.cuteCaption())
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            ForEach(allergens) { allergen in
                                HStack {
                                    Text(allergen.term).font(.cuteBody()).foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Button {
                                        remove(allergen)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(Theme.blushDeep)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                                if allergen.id != allergens.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .cuteCard(tint: Theme.peach.opacity(0.4))

                    Text("This is a personal list you maintain, not a medical allergy test — always patch test anything new, and see an allergist for a confirmed diagnosis.")
                        .font(.cuteCaption(11))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .padding()
            }
        }
        .navigationTitle("My Allergens")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func add() {
        let trimmed = newTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !allergens.contains(where: { $0.term.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            newTerm = ""
            return
        }
        modelContext.insert(PersonalAllergen(term: trimmed))
        try? modelContext.save()
        newTerm = ""
    }

    private func remove(_ allergen: PersonalAllergen) {
        modelContext.delete(allergen)
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        AllergyListView()
            .modelContainer(for: [PersonalAllergen.self], inMemory: true)
    }
}
