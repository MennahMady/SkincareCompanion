//
//  SkincareCompanionApp.swift
//  SkincareCompanion
//
//  App entry point. Wires up the SwiftData model container that backs
//  the user's profile, product bag, and saved routines — CloudKit-backed
//  so the same data follows the user across their own devices signed
//  into the same iCloud account, with a local-only fallback so the app
//  still runs standalone if that isn't set up.
//
//  CLOUDKIT SYNC — SETUP REQUIRED IN XCODE (can't be checked into this
//  repo since there's no .xcodeproj here — see README's "Setting up the
//  Xcode project" section):
//    1. Select the app target → Signing & Capabilities → "+ Capability"
//       → iCloud. Check "CloudKit" and add/select a container (the
//       default `iCloud.<your bundle identifier>` is fine).
//    2. "+ Capability" again → Background Modes → check
//       "Remote notifications" (needed for CloudKit's silent push sync).
//    3. Run on a simulator or device signed into an iCloud account. A
//       personal Apple ID is enough for development; a paid Apple
//       Developer Program membership is only needed to ship this to
//       other people's devices via TestFlight/App Store.
//  Every persisted model below has default values on every non-optional
//  property (a CloudKit/SwiftData requirement — every attribute has to
//  be optional or defaulted, since CKRecord fields are always nullable).
//  If the capability above isn't set up yet, ModelContainer creation
//  below falls back to a local-only store automatically, so nothing
//  crashes — sync just silently doesn't happen until it is.
//

import SwiftUI
import SwiftData

@main
struct SkincareCompanionApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            BagItem.self,
            SavedRoutine.self,
            ScheduleOverride.self,
            PersonalAllergen.self,
            ProgressPhoto.self,
            SkinCheckIn.self,
            RoutineCompletion.self
        ])

        // Preferred: a CloudKit-backed store, so a profile, bag, and
        // routine history follow the user to their other devices.
        let cloudConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        if let cloudContainer = try? ModelContainer(for: schema, configurations: [cloudConfiguration]) {
            return cloudContainer
        }

        // Falls back to local-only if the iCloud + CloudKit capability
        // hasn't been added in Xcode yet, or no iCloud account is signed
        // in — same "the extra setup is optional, the app still works
        // without it" principle as every other optional feature here
        // (barcode scanning, notifications, etc.). See the header
        // comment above for the setup steps that turn sync on.
        print("⚠️ CloudKit sync unavailable (no iCloud capability/account) — using a local-only store instead.")
        let localConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        CuteAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            // Pinned to light mode. An earlier pass tried genuinely
            // adaptive dark-mode colors (Theme.adaptive(light:dark:)),
            // but the actual dark palette looked muddy/unreadable on a
            // real device and was explicitly rejected in favor of the
            // single pastel "cute" look this app is designed around —
            // so the whole app now always renders in that light theme,
            // regardless of the system's Light/Dark Mode setting.
            RootView()
                .tint(Theme.accent)
                .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}
