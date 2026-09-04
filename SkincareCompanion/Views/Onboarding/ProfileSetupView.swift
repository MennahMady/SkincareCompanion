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
    @State private var justSaved = false

    private let existingProfile: UserProfile?
    let isEditingExisting: Bool

    init(profile: UserProfile?, isEditingExisting: Bool = false) {
        self.existingProfile = profile
        self.isEditingExisting = isEditingExisting
        _name = State(initialValue: profile?.name ?? "")
        _skinType = State(initialValue: profile?.skinType)
        _concerns = State(initialValue: Set(profile?.selectedConcerns ?? []))
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
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))

                            Text("Skin type").font(.cuteCaption()).foregroundStyle(Theme.textSecondary).padding(.top, 4)
                            SkinTypePicker(selection: $skinType)
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
                            Button(justSaved ? "Saved! 💕" : "Save Changes") {
                                save()
                                withAnimation { justSaved = true }
                            }
                            .buttonStyle(CuteButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditingExisting ? "My Profile" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isEditingExisting {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Let's Go! ✨") { save(completingOnboarding: true) }
                            .font(.cuteHeadline())
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
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

    private func save(completingOnboarding: Bool = false) {
        let profile = existingProfile ?? UserProfile()
        profile.name = name
        profile.skinType = skinType
        profile.selectedConcerns = Array(concerns)
        if completingOnboarding {
            profile.onboardingComplete = true
        }
        if existingProfile == nil {
            modelContext.insert(profile)
        }
        try? modelContext.save()
    }
}

private struct SkinTypePicker: View {
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
                .foregroundStyle(isOn ? .white : Theme.textPrimary)
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
                        .foregroundStyle(isOn ? .white : Theme.textPrimary)
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
