//
//  RootView.swift
//  SkincareCompanion
//
//  Decides between onboarding and the main tab experience based on
//  whether a UserProfile already exists and is marked complete.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let profile = profiles.first, profile.onboardingComplete {
                MainTabView(profile: profile)
            } else {
                ProfileSetupView(profile: profiles.first)
            }
        }
    }
}

struct MainTabView: View {
    @Bindable var profile: UserProfile

    var body: some View {
        TabView {
            BagView()
                .tabItem { Label("My Bag", systemImage: "bag.fill") }

            RoutineView(profile: profile)
                .tabItem { Label("Routine", systemImage: "sparkles") }

            ProfileSetupView(profile: profile, isEditingExisting: true)
                .tabItem { Label("Profile", systemImage: "heart.circle.fill") }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [UserProfile.self, BagItem.self, SavedRoutine.self], inMemory: true)
}
