//
//  RoutineView.swift
//  SkincareCompanion
//
//  The core "what do I actually do" screen: pick concerns, generate a
//  routine from the current bag, and surface conflict warnings plus
//  shopping recommendations for gaps.
//

import SwiftUI
import SwiftData

struct RoutineView: View {
    let profile: UserProfile

    @Query private var bagItems: [BagItem]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = RoutineViewModel()
    @State private var justSaved = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                if bagItems.isEmpty {
                    CuteEmptyState(
                        emoji: "🌸",
                        title: "Add products first",
                        message: "Once you've added a few products to My Bag, come back here to build your routine.",
                        actionTitle: "Got it"
                    ) {}
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("What are you dealing with?", systemImage: "heart.text.square.fill")
                                    .font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
                                FlowConcernGrid(selected: $viewModel.selectedConcerns)

                                Button("Generate My Routine ✨") {
                                    viewModel.generate(bagItems: bagItems)
                                    justSaved = false
                                }
                                .buttonStyle(CuteButtonStyle())
                            }
                            .cuteCard()

                            if let routine = viewModel.routine {
                                if !routine.warnings.isEmpty {
                                    sectionBlock(title: "Heads Up", icon: "exclamationmark.triangle.fill", tint: Theme.peach.opacity(0.5)) {
                                        ForEach(routine.warnings) { WarningRow(warning: $0) }
                                    }
                                }

                                sectionBlock(title: "Morning ☀️", icon: "sun.max.fill", tint: Theme.butter.opacity(0.6)) {
                                    if routine.amSteps.isEmpty {
                                        Text("No AM steps from your current bag.").font(.cuteBody()).foregroundStyle(Theme.textSecondary)
                                    } else {
                                        ForEach(Array(routine.amSteps.enumerated()), id: \.element.id) { index, step in
                                            StepRow(index: index + 1, step: step, tint: Theme.butter)
                                        }
                                    }
                                }

                                sectionBlock(title: "Evening 🌙", icon: "moon.stars.fill", tint: Theme.lavender.opacity(0.6)) {
                                    if routine.pmSteps.isEmpty {
                                        Text("No PM steps from your current bag.").font(.cuteBody()).foregroundStyle(Theme.textSecondary)
                                    } else {
                                        ForEach(Array(routine.pmSteps.enumerated()), id: \.element.id) { index, step in
                                            StepRow(index: index + 1, step: step, tint: Theme.lavender)
                                        }
                                    }
                                }

                                if !routine.recommendations.isEmpty {
                                    sectionBlock(title: "You Might Need 🛍️", icon: "cart.fill", tint: Theme.mint.opacity(0.5)) {
                                        ForEach(routine.recommendations) { RecommendationRow(recommendation: $0) }
                                    }
                                }

                                VStack(spacing: 6) {
                                    Button(justSaved ? "Saved to History 💕" : "Save This Routine") {
                                        saveRoutine(routine)
                                        withAnimation { justSaved = true }
                                    }
                                    .buttonStyle(CuteButtonStyle(background: Theme.lavenderDeep))

                                    Text("General educational guidance based on commonly-known skincare practices — not dermatological advice. See a dermatologist for persistent or severe concerns.")
                                        .font(.cuteCaption(11))
                                        .foregroundStyle(Theme.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Routine")
            .onAppear {
                if viewModel.selectedConcerns.isEmpty {
                    viewModel.selectedConcerns = Set(profile.selectedConcerns)
                }
                viewModel.generate(bagItems: bagItems)
            }
        }
    }

    @ViewBuilder
    private func sectionBlock<Content: View>(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
            VStack(spacing: 8) { content() }
        }
        .cuteCard(tint: tint)
    }

    private func saveRoutine(_ routine: Routine) {
        modelContext.insert(SavedRoutine(routine: routine))
        try? modelContext.save()
    }
}

private struct StepRow: View {
    let index: Int
    let step: RoutineStep
    var tint: Color = Theme.blush

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.cuteHeadline(13))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Theme.accent))

            VStack(alignment: .leading, spacing: 2) {
                Text(step.productName).font(.cuteBody()).foregroundStyle(Theme.textPrimary)
                Text(step.category.displayName).font(.cuteCaption()).foregroundStyle(Theme.textSecondary)
                if let note = step.note {
                    Text(note).font(.cuteCaption(11)).foregroundStyle(Theme.lavenderDeep)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.7)))
    }
}

private struct WarningRow: View {
    let warning: RoutineWarning

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(warning.title, systemImage: "exclamationmark.triangle.fill")
                .font(.cuteHeadline(14))
                .foregroundStyle(Theme.blushDeep)
            Text(warning.detail).font(.cuteCaption()).foregroundStyle(Theme.textSecondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.7)))
    }
}

private struct RecommendationRow: View {
    let recommendation: Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recommendation.missingCategory.displayName).font(.cuteHeadline(14)).foregroundStyle(Theme.textPrimary)
            Text(recommendation.reason).font(.cuteCaption()).foregroundStyle(Theme.textSecondary)
            if !recommendation.suggestedActives.isEmpty {
                Text("Look for: " + recommendation.suggestedActives.map { $0.displayName }.joined(separator: ", "))
                    .font(.cuteCaption(11))
                    .foregroundStyle(Theme.lavenderDeep)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.7)))
    }
}
