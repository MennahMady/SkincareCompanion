//
//  ProfileSetupView.swift
//  SkincareCompanion
//
//  Doubles as first-run onboarding and the "Profile" tab for editing
//  later. `isEditingExisting` controls whether we show a "Get Started"
//  CTA (onboarding) or just let edits save silently (settings-style).
//

import SwiftUI
import SwiftData

struct ProfileSetupView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var name: String
    @State private var skinType: SkinType?
    @State private var concerns: Set<SkinConcern>
    @State private var ageRange: AgeRange?
    @State private var acknowledgedDisclaimer: Bool
    @State private var isPregnantOrNursing: Bool
    @State private var justSaved = false
    @State private var showingQuiz = false

    private let existingProfile: UserProfile?
    let isEditingExisting: Bool

    init(profile: UserProfile?, isEditingExisting: Bool = false) {
        self.existingProfile = profile
        self.isEditingExisting = isEditingExisting
        _name = State(initialValue: profile?.name ?? "")
        _skinType = State(initialValue: profile?.skinType)
        _concerns = State(initialValue: Set(profile?.selectedConcerns ?? []))
        _ageRange = State(initialValue: profile?.ageRange)
        _acknowledgedDisclaimer = State(initialValue: profile?.acknowledgedDisclaimer ?? false)
        _isPregnantOrNursing = State(initialValue: profile?.isPregnantOrNursing ?? false)
    }

    /// Onboarding can't proceed until an age range is picked (and never
    /// for "Under 13" — see AgeRange.isEligible), and until the
    /// disclaimer is acknowledged. Editing an existing profile is more
    /// forgiving (it's not a new signup, and the disclaimer was already
    /// accepted once), but still won't let anyone switch to "Under 13."
    private var canContinue: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, ageRange?.isEligible ?? false else { return false }
        return isEditingExisting || acknowledgedDisclaimer
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        if !isEditingExisting {
                            header
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("About You", icon: "person.fill")
                            TextField("What should we call you?", text: $name)
                                .font(.cuteBody())
                                .foregroundStyle(Theme.onAccentText)
                                .tint(Theme.accent)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))

                            HStack {
                                Text("Skin type").font(.cuteCaption()).foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Button {
                                    showingQuiz = true
                                } label: {
                                    Text("Not sure? Take a quick quiz")
                                        .font(.cuteCaption(11))
                                        .foregroundStyle(Theme.lavenderDeep)
                                        .underline()
                                }
                            }
                            .padding(.top, 4)
                            SkinTypePicker(selection: $skinType)

                            Text("Age range").font(.cuteCaption()).foregroundStyle(Theme.textSecondary).padding(.top, 4)
                            AgeRangePicker(selection: $ageRange)

                            if let ageRange, !ageRange.isEligible {
                                Text("This app isn't available for users under 13. Sorry! 💛")
                                    .font(.cuteCaption(12))
                                    .foregroundStyle(Theme.blushDeep)
                                    .padding(.top, 2)
                            } else if ageRange?.needsActiveCaution == true {
                                Text("We'll go gentler on strong actives like retinoids in your routine and flag anything worth checking with a dermatologist first.")
                                    .font(.cuteCaption(12))
                                    .foregroundStyle(Theme.textSecondary)
                                    .padding(.top, 2)
                            }

                            Toggle(isOn: $isPregnantOrNursing) {
                                Text("Pregnant or nursing").font(.cuteBody(14))
                            }
                            .tint(Theme.accent)
                            .padding(.top, 10)
                            if isPregnantOrNursing {
                                Text("We'll flag retinoids and a couple of other commonly-cited ingredients already in your bag — general educational info, not medical advice. Always check with your OB or midwife.")
                                    .font(.cuteCaption(12))
                                    .foregroundStyle(Theme.textSecondary)
                                    .padding(.top, 2)
                            }
                        }
                        .cuteCard()

                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("General Concerns", icon: "sparkles")
                            Text("Pick your defaults — you can always change these per-routine.")
                                .font(.cuteCaption())
                                .foregroundStyle(Theme.textSecondary)

                            FlowConcernGrid(selected: $concerns)
                        }
                        .cuteCard(tint: Theme.lavender.opacity(0.5))

                        if isEditingExisting {
                            VStack(spacing: 10) {
                                if let existingProfile {
                                    linkRow(title: "Skin Assessment", icon: "sparkle.magnifyingglass") {
                                        SkinAssessmentView(profile: existingProfile)
                                    }
                                }
                                linkRow(title: "My Allergens", icon: "exclamationmark.shield.fill") {
                                    AllergyListView()
                                }
                                linkRow(title: "Routine Reminders", icon: "bell.fill") {
                                    RemindersSettingsView(profile: existingProfile)
                                }
                                linkRow(title: "Progress Photos", icon: "photo.on.rectangle.angled") {
                                    ProgressLogView()
                                }
                                linkRow(title: "Legal & Disclaimer", icon: "doc.text.fill") {
                                    DisclaimerView()
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Button {
                                    acknowledgedDisclaimer.toggle()
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: acknowledgedDisclaimer ? "checkmark.square.fill" : "square")
                                            .font(.title3)
                                            .foregroundStyle(acknowledgedDisclaimer ? Theme.accent : Theme.textSecondary)
                                        Text("I understand this app provides general educational skincare information — not medical advice — and I should check with a dermatologist for anything persistent or severe.")
                                            .font(.cuteCaption(12))
                                            .foregroundStyle(Theme.textPrimary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                .buttonStyle(.plain)

                                NavigationLink {
                                    DisclaimerView()
                                } label: {
                                    Text("Read the full disclaimer")
                                        .font(.cuteCaption(12))
                                        .foregroundStyle(Theme.lavenderDeep)
                                        .underline()
                                }
                            }
                            .cuteCard(tint: Theme.peach.opacity(0.4))
                        }

                        if isEditingExisting {
                            Button(justSaved ? "Saved! 💕" : "Save Changes") {
                                save()
                                withAnimation { justSaved = true }
                            }
                            .buttonStyle(CuteButtonStyle())
                            .disabled(!canContinue)
                            .opacity(canContinue ? 1 : 0.5)
                        }
                    }
                    .padding()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                if isEditingExisting {
                    CuteGlassHeader("My Profile")
                } else {
                    CuteGlassHeader("") { } trailing: {
                        Button("Let's Go! ✨") { save(completingOnboarding: true) }
                            .buttonStyle(CuteGlassPillButtonStyle())
                            .disabled(!canContinue)
                            .opacity(canContinue ? 1 : 0.5)
                    }
                }
            }
            .sheet(isPresented: $showingQuiz) {
                SkinTypeQuizView { result in
                    skinType = result
                }
            }
            // SkinAssessmentView (pushed via the link row below) writes
            // straight to the shared UserProfile instance rather than
            // routing back through this screen's local @State copies —
            // simpler than threading a completion closure through a
            // NavigationLink. Re-syncing here on reappearance (which
            // NavigationStack triggers when popping back to this screen)
            // is what keeps the fields on THIS screen from showing stale
            // values after a round trip through the assessment.
            .onAppear { refreshFromProfile() }
        }
    }

    private func refreshFromProfile() {
        guard let existingProfile else { return }
        name = existingProfile.name
        skinType = existingProfile.skinType
        concerns = Set(existingProfile.selectedConcerns)
        ageRange = existingProfile.ageRange
        isPregnantOrNursing = existingProfile.isPregnantOrNursing
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.blush, Theme.lavender], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                Image(systemName: "sparkles")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
            }
            Text("Welcome to Glow Guide 🌸")
                .font(.cuteTitle())
                .foregroundStyle(Theme.textPrimary)
            Text("Let's get to know your skin so we can put together routines from what you already own.")
                .font(.cuteBody())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(.top, 12)
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.cuteHeadline())
            .foregroundStyle(Theme.textPrimary)
    }

    @ViewBuilder
    private func linkRow<Destination: View>(title: String, icon: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                Label(title, systemImage: icon)
                    .font(.cuteHeadline(14))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous).fill(Theme.surface.opacity(0.7)))
    }

    private func save(completingOnboarding: Bool = false) {
        guard canContinue else { return }
        let profile = existingProfile ?? UserProfile()
        profile.name = name
        profile.skinType = skinType
        profile.selectedConcerns = Array(concerns)
        profile.ageRange = ageRange
        profile.isPregnantOrNursing = isPregnantOrNursing
        if !isEditingExisting {
            profile.acknowledgedDisclaimer = acknowledgedDisclaimer
        }
        if completingOnboarding {
            profile.onboardingComplete = true
        }
        if existingProfile == nil {
            modelContext.insert(profile)
        }
        try? modelContext.save()
    }
}

struct AgeRangePicker: View {
    @Binding var selection: AgeRange?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AgeRange.allCases) { range in
                    pill(title: range.displayName, isOn: selection == range) { selection = range }
                }
            }
        }
    }

    private func pill(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.cuteCaption(13))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(isOn ? Theme.accent : Theme.mint.opacity(0.6)))
                .foregroundStyle(isOn ? .white : Theme.onAccentText)
        }
        .buttonStyle(.plain)
    }
}

struct SkinTypePicker: View {
    @Binding var selection: SkinType?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(title: "Not sure", isOn: selection == nil) { selection = nil }
                ForEach(SkinType.allCases) { type in
                    pill(title: type.displayName, isOn: selection == type) { selection = type }
                }
            }
        }
    }

    private func pill(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.cuteCaption(13))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(isOn ? Theme.accent : Theme.blush.opacity(0.5)))
                .foregroundStyle(isOn ? .white : Theme.onAccentText)
        }
        .buttonStyle(.plain)
    }
}

/// A wrapping grid of pastel concern chips, each tinted a different
/// color from the theme's pastel cycle so the grid doesn't read flat.
struct FlowConcernGrid: View {
    @Binding var selected: Set<SkinConcern>
    let columns = [GridItem(.adaptive(minimum: 150), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(SkinConcern.allCases.enumerated()), id: \.element) { index, concern in
                let isOn = selected.contains(concern)
                let tint = Theme.pastel(for: index)
                Button {
                    if isOn { selected.remove(concern) } else { selected.insert(concern) }
                } label: {
                    Label(concern.displayName, systemImage: concern.systemImage)
                        .font(.cuteCaption(13))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.chipCornerRadius)
                                .fill(isOn ? Theme.accent : tint.opacity(0.55))
                        )
                        .foregroundStyle(isOn ? .white : Theme.onAccentText)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    ProfileSetupView(profile: nil)
        .modelContainer(for: [UserProfile.self], inMemory: true)
}
