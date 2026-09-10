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
    @Query private var scheduleOverrides: [ScheduleOverride]
    @Query private var personalAllergens: [PersonalAllergen]
    @Query private var routineCompletions: [RoutineCompletion]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = RoutineViewModel()
    @State private var justSaved = false
    /// Collapsed by default — dermatologist-cited "core" AM routines are
    /// just cleanse/moisturize/SPF; everything else (toners, extra
    /// serums, etc.) is optional add-on layered on top, so mornings stay
    /// short unless you tap to see more.
    @State private var amExtrasExpanded = false

    /// The day being previewed — defaults to today, but tapping another
    /// day in the WeekStrip switches this so you can check "what am I
    /// supposed to do on Wednesday" without waiting for Wednesday.
    @State private var selectedDate = Date()

    /// Read fresh each time the view renders rather than cached in
    /// @State, so "today" always reflects the actual current day — no
    /// stale value if the app was left open overnight.
    private var today: Date { Date() }

    private var isViewingToday: Bool {
        Calendar.current.isDate(selectedDate, inSameDayAs: today)
    }

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
                                    viewModel.generate(bagItems: bagItems, ageRange: profile.ageRange, personalAllergens: personalAllergens.map { $0.term }, isPregnantOrNursing: profile.isPregnantOrNursing)
                                    justSaved = false
                                }
                                .buttonStyle(CuteButtonStyle())
                            }
                            .cuteCard()

                            if let routine = viewModel.routine {
                                WeekStrip(today: today, selectedDate: $selectedDate)

                                HStack {
                                    Text(isViewingToday ? "Showing: Today" : "Showing: \(Self.weekdayFormatter.string(from: selectedDate))")
                                        .font(.cuteCaption(12))
                                        .foregroundStyle(Theme.textSecondary)
                                    Spacer()
                                    if !isViewingToday {
                                        Button("Jump to Today") {
                                            withAnimation { selectedDate = Date() }
                                        }
                                        .font(.cuteCaption(12))
                                        .foregroundStyle(Theme.lavenderDeep)
                                    }
                                }
                                .padding(.horizontal, 4)

                                let amDue = viewModel.applyOverrides(scheduleOverrides, toDueSteps: routine.amSteps(on: selectedDate), allSteps: routine.amSteps, on: selectedDate)
                                let pmDue = viewModel.applyOverrides(scheduleOverrides, toDueSteps: routine.pmSteps(on: selectedDate), allSteps: routine.pmSteps, on: selectedDate)
                                let generalWarnings = routine.warnings.filter { $0.relatedBagItemIDs.isEmpty }

                                sectionBlock(title: "Morning ☀️", icon: "sun.max.fill", tint: Theme.butter.opacity(0.6)) {
                                    markDoneButton(session: "am")
                                } content: {
                                    if amDue.isEmpty {
                                        Text("No AM steps from your current bag.").font(.cuteBody()).foregroundStyle(Theme.textSecondary)
                                    } else {
                                        let essential = amDue.filter { isEssential($0.category) }
                                        let extra = amDue.filter { !isEssential($0.category) }
                                        ForEach(Array(essential.enumerated()), id: \.element.id) { index, step in
                                            StepRow(index: index + 1, step: step, tint: Theme.butter, warnings: warnings(for: step, in: routine)) {
                                                skipToday(step)
                                            }
                                        }
                                        if !extra.isEmpty {
                                            DisclosureGroup(isExpanded: $amExtrasExpanded) {
                                                VStack(spacing: 8) {
                                                    ForEach(Array(extra.enumerated()), id: \.element.id) { index, step in
                                                        StepRow(index: essential.count + index + 1, step: step, tint: Theme.butter, warnings: warnings(for: step, in: routine)) {
                                                            skipToday(step)
                                                        }
                                                    }
                                                }
                                                .padding(.top, 8)
                                            } label: {
                                                Text("+\(extra.count) more \(extra.count == 1 ? "step" : "steps") — cleanse/moisturize/SPF covers the dermatologist-cited core; the rest is optional")
                                                    .font(.cuteCaption(12))
                                                    .foregroundStyle(Theme.lavenderDeep)
                                            }
                                            .tint(Theme.lavenderDeep)
                                        }
                                    }
                                }

                                sectionBlock(title: "Evening 🌙", icon: "moon.stars.fill", tint: Theme.lavender.opacity(0.6)) {
                                    markDoneButton(session: "pm")
                                } content: {
                                    if pmDue.isEmpty {
                                        Text("No PM steps from your current bag.").font(.cuteBody()).foregroundStyle(Theme.textSecondary)
                                    } else {
                                        ForEach(Array(pmDue.enumerated()), id: \.element.id) { index, step in
                                            StepRow(index: index + 1, step: step, tint: Theme.lavender, warnings: warnings(for: step, in: routine)) {
                                                skipToday(step)
                                            }
                                        }
                                    }
                                }

                                let shownIDs = Set(amDue.map { $0.bagItemID } + pmDue.map { $0.bagItemID })
                                let allKnownSteps = uniqued(routine.amSteps + routine.pmSteps)
                                let restOfWeek = allKnownSteps.filter { !shownIDs.contains($0.bagItemID) }
                                if !restOfWeek.isEmpty {
                                    sectionBlock(title: isViewingToday ? "Not Today" : "Not on \(Self.weekdayFormatter.string(from: selectedDate))", icon: "calendar", tint: Theme.cream) {
                                        Text("These are in your routine but only used a few times a week. Missed one on its usual day? Do it today instead.")
                                            .font(.cuteCaption(11))
                                            .foregroundStyle(Theme.textSecondary)
                                        ForEach(restOfWeek) { step in
                                            NotTodayRow(step: step) {
                                                doToday(step)
                                            }
                                        }
                                    }
                                }

                                if !routine.recommendations.isEmpty {
                                    sectionBlock(title: "You Might Need 🛍️", icon: "cart.fill", tint: Theme.mint.opacity(0.5)) {
                                        ForEach(routine.recommendations) { recommendation in
                                            NavigationLink {
                                                RecommendationDetailView(recommendation: recommendation)
                                            } label: {
                                                RecommendationRow(recommendation: recommendation)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                // Heads Up now only holds routine-wide
                                // warnings with no single product to pin
                                // them to (e.g. "no sunscreen in your
                                // bag") — anything tied to a specific
                                // product shows as a tappable warning
                                // icon right on that product's row
                                // instead, so you see it when you open
                                // that step rather than in a big list
                                // before you've even looked at the routine.
                                if !generalWarnings.isEmpty {
                                    sectionBlock(title: "Heads Up", icon: "exclamationmark.triangle.fill", tint: Theme.peach.opacity(0.5)) {
                                        ForEach(generalWarnings) { WarningRow(warning: $0) }
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
                viewModel.generate(bagItems: bagItems, ageRange: profile.ageRange, personalAllergens: personalAllergens.map { $0.term }, isPregnantOrNursing: profile.isPregnantOrNursing)
            }
        }
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    @ViewBuilder
    private func sectionBlock<Content: View, Accessory: View>(title: String, icon: String, tint: Color, @ViewBuilder accessory: () -> Accessory = { EmptyView() }, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon).font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
                Spacer()
                accessory()
            }
            VStack(spacing: 8) { content() }
        }
        .cuteCard(tint: tint)
    }

    private func isCompleted(session: String) -> Bool {
        let key = RoutineViewModel.dayKey(for: selectedDate)
        return routineCompletions.contains { $0.dayKey == key && $0.sessionRaw == session }
    }

    private func toggleCompleted(session: String) {
        let key = RoutineViewModel.dayKey(for: selectedDate)
        if let existing = routineCompletions.first(where: { $0.dayKey == key && $0.sessionRaw == session }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(RoutineCompletion(dayKey: key, sessionRaw: session))
        }
        try? modelContext.save()
    }

    @ViewBuilder
    private func markDoneButton(session: String) -> some View {
        let done = isCompleted(session: session)
        Button {
            withAnimation { toggleCompleted(session: session) }
        } label: {
            Label(done ? "Done" : "Mark Done", systemImage: done ? "checkmark.circle.fill" : "circle")
                .font(.cuteCaption(11))
                .foregroundStyle(done ? Theme.mint : Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func saveRoutine(_ routine: Routine) {
        modelContext.insert(SavedRoutine(routine: routine))
        try? modelContext.save()
    }

    /// The dermatologist-cited "core" categories (cleanse, moisturize,
    /// protect) — see the Morning section's collapsed extras. Everything
    /// else is a legitimate part of the routine, just not part of the
    /// evidence-backed minimum, so it's collapsed rather than hidden.
    private func isEssential(_ category: ProductCategory) -> Bool {
        [.cleanser, .moisturizer, .sunscreen].contains(category)
    }

    private func warnings(for step: RoutineStep, in routine: Routine) -> [RoutineWarning] {
        routine.warnings.filter { $0.relatedBagItemIDs.contains(step.bagItemID) }
    }

    private func uniqued(_ steps: [RoutineStep]) -> [RoutineStep] {
        var seen = Set<String>()
        return steps.filter { seen.insert($0.bagItemID).inserted }
    }

    /// Marks a step as done for `selectedDate` even though it wasn't
    /// naturally due — for "I missed this on its usual day, let me catch
    /// up today" — without touching the product's ongoing weekly pattern.
    private func doToday(_ step: RoutineStep) {
        upsertOverride(bagItemID: step.bagItemID, isDueOverride: true)
    }

    /// Marks a step as skipped for `selectedDate` only, even though it's
    /// naturally due — for "not doing this one today" without changing
    /// the product's ongoing schedule.
    private func skipToday(_ step: RoutineStep) {
        upsertOverride(bagItemID: step.bagItemID, isDueOverride: false)
    }

    private func upsertOverride(bagItemID: String, isDueOverride: Bool) {
        let key = RoutineViewModel.dayKey(for: selectedDate)
        if let existing = scheduleOverrides.first(where: { $0.bagItemID == bagItemID && $0.dayKey == key }) {
            existing.isDueOverride = isDueOverride
        } else {
            modelContext.insert(ScheduleOverride(bagItemID: bagItemID, dayKey: key, isDueOverride: isDueOverride))
        }
        try? modelContext.save()
    }
}

/// A row of 7 tappable day circles for the current week (today
/// highlighted, the selected day filled in) — tap any day to preview
/// what's due then, since some steps only show up on certain days.
private struct WeekStrip: View {
    let today: Date
    @Binding var selectedDate: Date
    private let calendar = Calendar.current

    /// The 7 actual dates (Sun...Sat) of the week `today` falls in, so
    /// taps select a real calendar date rather than just "day 3."
    private var weekDates: [Date] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(weekDates, id: \.self) { date in
                let symbol = String(calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: date) - 1].prefix(1))
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = calendar.isDate(date, inSameDayAs: today)

                Button {
                    withAnimation { selectedDate = date }
                } label: {
                    VStack(spacing: 3) {
                        Text(symbol)
                            .font(.cuteHeadline(13))
                            .foregroundStyle(isSelected ? .white : Theme.onAccentText)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(isSelected ? Theme.accent : Color.white.opacity(0.6)))
                        Circle()
                            .fill(isToday ? Theme.accent : .clear)
                            .frame(width: 4, height: 4)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StepRow: View {
    let index: Int
    let step: RoutineStep
    var tint: Color = Theme.blush
    var warnings: [RoutineWarning] = []
    var onSkipToday: (() -> Void)?

    @State private var showingWarnings = false
    @State private var showingTip = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(index)")
                    .font(.cuteHeadline(13))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Theme.accent))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(step.productName).font(.cuteBody()).foregroundStyle(Theme.textPrimary)
                        if !warnings.isEmpty {
                            Button {
                                withAnimation { showingWarnings.toggle() }
                            } label: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.blushDeep)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 6) {
                        Button {
                            withAnimation { showingTip.toggle() }
                        } label: {
                            HStack(spacing: 3) {
                                Text(step.category.displayName).font(.cuteCaption()).foregroundStyle(Theme.textSecondary)
                                if step.category.applicationTip != nil || step.category.prepNote != nil {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Theme.lavenderDeep)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(step.category.applicationTip == nil && step.category.prepNote == nil)
                        if step.frequency != .daily {
                            Text(step.scheduleDescription)
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.onAccentTextSecondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.peach.opacity(0.7)))
                        }
                    }
                    if let note = step.note {
                        Text(note).font(.cuteCaption(11)).foregroundStyle(Theme.lavenderDeep)
                    }
                }
                Spacer()
            }

            // Tapping the category ("Toner", "Serum"...) reveals both
            // what your skin should be like going into this step (wet,
            // damp, fully dry) and how it's conventionally applied — e.g.
            // a toner is commonly layered 1-2 times, not just "used once."
            if showingTip, (step.category.prepNote != nil || step.category.applicationTip != nil) {
                VStack(alignment: .leading, spacing: 6) {
                    if let prep = step.category.prepNote {
                        Text("Before this: \(prep)")
                            .font(.cuteCaption(11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if let tip = step.category.applicationTip {
                        Text("How to apply: \(tip)")
                            .font(.cuteCaption(11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.lavender.opacity(0.35)))
            }

            // Tapping the warning icon reveals the actual warning right
            // here, on the product it's about — instead of a big list of
            // warnings shown before you've even seen the routine.
            if showingWarnings {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(warnings) { warning in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(warning.title).font(.cuteHeadline(12)).foregroundStyle(Theme.blushDeep)
                            Text(warning.detail).font(.cuteCaption(11)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.peach.opacity(0.35)))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.7)))
        .contextMenu {
            if let onSkipToday {
                Button("Not doing this today", systemImage: "xmark.circle") {
                    onSkipToday()
                }
            }
        }
    }
}

/// Compact row for a step that's in the routine but not due today —
/// answers "where did my exfoliant go" instead of it just vanishing.
/// "Do Today" lets you catch up on one you missed on its usual day.
private struct NotTodayRow: View {
    let step: RoutineStep
    var onDoToday: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: step.category.systemImage)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(step.productName).font(.cuteCaption(13)).foregroundStyle(Theme.textPrimary)
                Text(step.scheduleDescription).font(.cuteCaption(11)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if let onDoToday {
                Button("Do Today", action: onDoToday)
                    .font(.cuteCaption(11))
                    .foregroundStyle(Theme.lavenderDeep)
            }
        }
        .padding(.vertical, 4)
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
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.7)))
    }
}

private struct RecommendationRow: View {
    let recommendation: Recommendation

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: recommendation.missingCategory.systemImage)
                        .font(.caption)
                        .foregroundStyle(Theme.lavenderDeep)
                    Text(recommendation.missingCategory.displayName)
                        .font(.cuteHeadline(14))
                        .foregroundStyle(Theme.textPrimary)
                }
                // The reason is written as a full, natural sentence (e.g.
                // "Since you're dealing with breakouts, try a treatment with
                // salicylic acid or benzoyl peroxide.") so this reads like
                // advice rather than a raw ingredient dump.
                Text(recommendation.reason).font(.cuteCaption()).foregroundStyle(Theme.textSecondary)
                Text("Tap to see matching products").font(.cuteCaption(10)).foregroundStyle(Theme.lavenderDeep)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.textSecondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.7)))
    }
}
