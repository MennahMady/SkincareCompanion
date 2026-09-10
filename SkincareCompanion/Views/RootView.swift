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

/// The four top-level destinations, plus what a `CuteFloatingTabBar` needs
/// to draw a row for each one.
enum MainTab: Hashable, CaseIterable {
    case bag, routine, progress, profile

    var title: String {
        switch self {
        case .bag: "My Bag"
        case .routine: "Routine"
        case .progress: "Progress"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .bag: "bag.fill"
        case .routine: "sparkles"
        case .progress: "photo.on.rectangle.angled"
        case .profile: "heart.circle.fill"
        }
    }
}

/// The native `UITabBar` can't be styled into a floating, fully-rounded
/// "bubble" pill on every iOS version this app might run on (that look
/// only comes for free on iOS 26's Liquid Glass tab bar) — so instead of
/// fighting `UITabBarAppearance`, the native tab bar is hidden entirely
/// and this view draws the floating pill by hand: a capsule inset from
/// both the screen edges and the bottom safe area, with a soft pastel
/// highlight behind whichever tab is selected.
struct MainTabView: View {
    @Bindable var profile: UserProfile
    @State private var selectedTab: MainTab = .bag

    var body: some View {
        TabView(selection: $selectedTab) {
            BagView()
                .tabItem { Label(MainTab.bag.title, systemImage: MainTab.bag.icon) }
                .tag(MainTab.bag)

            RoutineView(profile: profile)
                .tabItem { Label(MainTab.routine.title, systemImage: MainTab.routine.icon) }
                .tag(MainTab.routine)

            NavigationStack {
                ProgressLogView()
            }
            .tabItem { Label(MainTab.progress.title, systemImage: MainTab.progress.icon) }
            .tag(MainTab.progress)

            ProfileSetupView(profile: profile, isEditingExisting: true)
                .tabItem { Label(MainTab.profile.title, systemImage: MainTab.profile.icon) }
                .tag(MainTab.profile)
        }
        .tint(Theme.accent)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            CuteFloatingTabBar(selectedTab: $selectedTab)
        }
    }
}

/// A floating, capsule-shaped tab bar drawn entirely in SwiftUI — inset
/// from both side edges and lifted above the home indicator, with the
/// selected item picked out by a soft rounded highlight rather than just
/// a tint color change, so it reads as a "bubble" the same way the rest
/// of this app's chip/pill components do.
private struct CuteFloatingTabBar: View {
    @Binding var selectedTab: MainTab

    // Drives the sliding highlight below: `matchedGeometryEffect` needs a
    // shared namespace so SwiftUI can interpolate one highlight's frame
    // from its old tab's position to its new one, instead of the plain
    // per-button opacity swap this had before (which had no motion to
    // animate — a color fading in in-place doesn't read as "an
    // animation" the way a sliding pill does).
    @Namespace private var tabHighlight

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 19, weight: .semibold))
                            .scaleEffect(isSelected ? 1.08 : 1.0)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    // Unselected icons/labels are a near-black rather than
                    // the muted mauve `Theme.textSecondary` — flagged
                    // against a reference screenshot as reading too faded;
                    // black-on-glass is also just the more common "system"
                    // tab bar look this is going for.
                    .foregroundStyle(isSelected ? Theme.accent : Color.black.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if isSelected {
                            // Capsule, not a fixed corner radius — fully
                            // round ends so the highlight itself reads as
                            // a little pill/bubble rather than a rounded
                            // rectangle, per the reference screenshot.
                            Capsule(style: .continuous)
                                .fill(.regularMaterial)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .fill(Theme.accent.opacity(0.18))
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(.white.opacity(0.7), lineWidth: 1)
                                )
                                .shadow(color: Theme.blushDeep.opacity(0.25), radius: 6, x: 0, y: 3)
                                .matchedGeometryEffect(id: "highlight", in: tabHighlight)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .glass(cornerRadius: 100, tint: Theme.cream, tintOpacity: 0.4)
        .shadow(color: Theme.blushDeep.opacity(0.20), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [UserProfile.self, BagItem.self, SavedRoutine.self], inMemory: true)
}
