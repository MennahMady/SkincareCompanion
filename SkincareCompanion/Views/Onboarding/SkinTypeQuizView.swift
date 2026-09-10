//
//  SkinTypeQuizView.swift
//  SkincareCompanion
//
//  3-question sheet for "not sure what my skin type is" — hands the
//  result back to ProfileSetupView via onComplete rather than writing
//  to SwiftData itself, so it stays a reusable, storage-agnostic view.
//

import SwiftUI

struct SkinTypeQuizView: View {
    let onComplete: (SkinType) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var shinyByMidday = false
    @State private var tightOrFlakyCheeks = false
    @State private var easilyIrritated = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        Text("A few quick questions to guess a starting point — you can always change it later.")
                            .font(.cuteCaption())
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)

                        question(
                            "Does your T-zone (forehead, nose, chin) get visibly shiny or oily by midday?",
                            isOn: $shinyByMidday
                        )
                        question(
                            "Do your cheeks feel tight, rough, or flaky — especially right after washing?",
                            isOn: $tightOrFlakyCheeks
                        )
                        question(
                            "Do new products often make your skin sting, turn red, or itch?",
                            isOn: $easilyIrritated
                        )

                        Button("See My Result") {
                            let result = SkinTypeQuiz.result(for: .init(
                                shinyByMidday: shinyByMidday,
                                tightOrFlakyCheeks: tightOrFlakyCheeks,
                                easilyIrritated: easilyIrritated
                            ))
                            onComplete(result)
                            dismiss()
                        }
                        .buttonStyle(CuteButtonStyle())

                        Text("A best-guess starting point, not a dermatological diagnosis.")
                            .font(.cuteCaption(10))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) { header }
        }
        .presentationDetents([.medium, .large])
    }

    // Pulled out of `body` on purpose — see the identical note in
    // BagView.swift's `header` property: inlining this directly into
    // `.safeAreaInset` risks a Swift type-checker timeout that surfaces
    // as a confusing "Ambiguous use of 'init'" error elsewhere in body.
    private var header: some View {
        CuteGlassHeader("Skin Type Quiz") {
            Button("Cancel") { dismiss() }
                .buttonStyle(CuteGlassPillButtonStyle())
        } trailing: {
            EmptyView()
        }
    }

    private func question(_ text: String, isOn: Binding<Bool>) -> some View {
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
                .foregroundStyle(isSelected ? .white : Theme.onAccentText)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SkinTypeQuizView { _ in }
}
