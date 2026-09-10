//
//  SkinAssessmentView.swift
//  SkincareCompanion
//
//  A guided, multi-step "tell us more so we can pick better" flow —
//  what this app builds INSTEAD of a camera-based "scan your face and
//  we'll analyze your skin" feature. That's a deliberate call, not an
//  oversight: identifying acne, redness, pore size, or wrinkle depth
//  from a photo needs a trained dermatology-specific image model this
//  app doesn't have, and a home-grown heuristic (average pixel redness,
//  say) would be pseudo-scientific — it would look like an analysis
//  without being one, which is worse than not having the feature at
//  all in a health-adjacent app. What actually makes recommendations
//  more accurate, and IS honestly buildable, is asking better
//  questions — so this combines every relevant input the app already
//  has (skin-type quiz, concerns, age range, pregnancy/nursing,
//  personal allergens) into one guided sequence instead of leaving
//  them scattered across the Profile screen, and ends by generating a
//  routine from the combined answers. A reference photo is offered at
//  the end for the user's own before/after use (saved as a normal
//  ProgressPhoto) — explicitly NOT analyzed by anything here.
//

import SwiftUI
import SwiftData
import PhotosUI

struct SkinAssessmentView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    private let totalSteps = 5

    // Step 1: skin-type quiz answers
    @State private var shinyByMidday = false
    @State private var tightOrFlakyCheeks = false
    @State private var easilyIrritated = false

    // Step 2: concerns
    @State private var concerns: Set<SkinConcern>

    // Step 3: life stage
    @State private var ageRange: AgeRange?
    @State private var isPregnantOrNursing: Bool

    // Step 4: allergens
    @State private var newAllergenTerm = ""
    @Query(sort: \PersonalAllergen.dateAdded) private var allergens: [PersonalAllergen]

    // Step 5: optional reference photo
    @State private var pickerItem: PhotosPickerItem?
    @State private var pendingImageData: Data?

    init(profile: UserProfile) {
        self.profile = profile
        _concerns = State(initialValue: Set(profile.selectedConcerns))
        _ageRange = State(initialValue: profile.ageRange)
        _isPregnantOrNursing = State(initialValue: profile.isPregnantOrNursing)
    }

    private var computedSkinType: SkinType {
        SkinTypeQuiz.result(for: .init(shinyByMidday: shinyByMidday, tightOrFlakyCheeks: tightOrFlakyCheeks, easilyIrritated: easilyIrritated))
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressView(value: Double(step + 1), total: Double(totalSteps))
                    .tint(Theme.accent)
                    .padding(.horizontal)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 16) {
                        switch step {
                        case 0: skinTypeStep
                        case 1: concernsStep
                        case 2: lifeStageStep
                        case 3: allergensStep
                        default: summaryStep
                        }
                    }
                    .padding()
                }

                HStack {
                    if step > 0 {
                        Button("Back") { withAnimation { step -= 1 } }
                            .buttonStyle(CuteSecondaryButtonStyle())
                    }
                    if step < totalSteps - 1 {
                        Button("Next") { withAnimation { step += 1 } }
                            .buttonStyle(CuteButtonStyle())
                    } else {
                        Button("Save & Build Routine") { saveAndFinish() }
                            .buttonStyle(CuteButtonStyle())
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Skin Assessment")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var skinTypeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("A few quick questions to nail down your skin type — you can always change it later.")
                .font(.cuteCaption())
                .foregroundStyle(Theme.textSecondary)
            quizQuestion("Does your T-zone (forehead, nose, chin) get visibly shiny or oily by midday?", isOn: $shinyByMidday)
            quizQuestion("Do your cheeks feel tight, rough, or flaky — especially right after washing?", isOn: $tightOrFlakyCheeks)
            quizQuestion("Do new products often make your skin sting, turn red, or itch?", isOn: $easilyIrritated)
        }
    }

    private var concernsStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What are you hoping to improve?").font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
            Text("Pick as many as apply — this is what your recommendations are matched against.")
                .font(.cuteCaption())
                .foregroundStyle(Theme.textSecondary)
            FlowConcernGrid(selected: $concerns)
        }
    }

    private var lifeStageStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A little more context").font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
            Text("Age range").font(.cuteCaption()).foregroundStyle(Theme.textSecondary)
            AgeRangePicker(selection: $ageRange)

            Toggle(isOn: $isPregnantOrNursing) {
                Text("Pregnant or nursing").font(.cuteBody(14))
            }
            .tint(Theme.accent)
            .padding(.top, 10)
            if isPregnantOrNursing {
                Text("We'll flag retinoids and a couple of other commonly-cited ingredients — general info, not medical advice. Check with your OB or midwife.")
                    .font(.cuteCaption(12))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var allergensStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Anything you personally react to?").font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
            Text("A fragrance, an oil, an extract — optional, but it sharpens every warning going forward.")
                .font(.cuteCaption())
                .foregroundStyle(Theme.textSecondary)
            HStack {
                TextField("e.g. lanolin, coconut oil", text: $newAllergenTerm)
                    .font(.cuteBody())
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                Button {
                    addAllergen()
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Theme.accent)
                }
                .disabled(newAllergenTerm.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ForEach(allergens) { allergen in
                Text("• \(allergen.term)").font(.cuteCaption(13)).foregroundStyle(Theme.textPrimary)
            }
        }
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Here's what we'll use").font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                summaryRow("Skin type", computedSkinType.displayName)
                summaryRow("Concerns", concerns.isEmpty ? "None picked" : concerns.map { $0.displayName }.joined(separator: ", "))
                summaryRow("Age range", ageRange?.displayName ?? "Not set")
                if isPregnantOrNursing {
                    summaryRow("Pregnancy/nursing caution", "On")
                }
                if !allergens.isEmpty {
                    summaryRow("Allergens flagged", allergens.map { $0.term }.joined(separator: ", "))
                }
            }
            .cuteCard()

            VStack(alignment: .leading, spacing: 8) {
                Label("Optional reference photo", systemImage: "camera.fill").font(.cuteHeadline(14)).foregroundStyle(Theme.textPrimary)
                Text("For your own before/after comparison in Progress — nothing here analyzes it.")
                    .font(.cuteCaption(11))
                    .foregroundStyle(Theme.textSecondary)
                if let pendingImageData, let uiImage = UIImage(data: pendingImageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .background(RoundedRectangle(cornerRadius: Theme.cardCornerRadius).fill(Color.white))
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(pendingImageData == nil ? "Add a Photo" : "Choose a Different Photo", systemImage: "photo.badge.plus")
                }
                .buttonStyle(CuteSecondaryButtonStyle())
                .onChange(of: pickerItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            pendingImageData = data
                        }
                    }
                }
            }
            .cuteCard(tint: Theme.lavender.opacity(0.4))
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.cuteCaption(12)).foregroundStyle(Theme.textSecondary).frame(width: 110, alignment: .leading)
            Text(value).font(.cuteBody(13)).foregroundStyle(Theme.textPrimary)
        }
    }

    private func quizQuestion(_ text: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text).font(.cuteBody()).foregroundStyle(Theme.textPrimary)
            HStack(spacing: 10) {
                choiceButton("Yes", isSelected: isOn.wrappedValue) { isOn.wrappedValue = true }
                choiceButton("No", isSelected: !isOn.wrappedValue) { isOn.wrappedValue = false }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cuteCard()
    }

    private func choiceButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.cuteCaption(13))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(isSelected ? Theme.accent : Theme.mint.opacity(0.5)))
                .foregroundStyle(isSelected ? .white : Theme.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private func addAllergen() {
        let trimmed = newAllergenTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !allergens.contains(where: { $0.term.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            newAllergenTerm = ""
            return
        }
        modelContext.insert(PersonalAllergen(term: trimmed))
        try? modelContext.save()
        newAllergenTerm = ""
    }

    private func saveAndFinish() {
        profile.skinType = computedSkinType
        profile.selectedConcerns = Array(concerns)
        profile.ageRange = ageRange
        profile.isPregnantOrNursing = isPregnantOrNursing
        if let pendingImageData {
            modelContext.insert(ProgressPhoto(note: "Skin assessment reference photo", imageData: pendingImageData))
        }
        try? modelContext.save()
        dismiss()
    }
}
