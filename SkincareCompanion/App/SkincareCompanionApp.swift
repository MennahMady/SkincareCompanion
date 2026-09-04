//
//  SkincareCompanionApp.swift
//  SkincareCompanion
//
//  App entry point. Wires up the SwiftData model container that backs
//  the user's profile, product bag, and saved routines.
//

import SwiftUI
import SwiftData

@main
struct SkincareCompanionApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            BagItem.self,
            SavedRoutine.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        CuteAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
        }
        .modelContainer(sharedModelContainer)
    }
}
