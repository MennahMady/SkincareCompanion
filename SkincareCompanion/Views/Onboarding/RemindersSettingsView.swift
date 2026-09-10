//
//  RemindersSettingsView.swift
//  SkincareCompanion
//
//  Toggle + two time pickers for the AM/PM routine reminders. Talks to
//  NotificationScheduler directly on every change so the actual
//  scheduled local notifications always match what's on screen.
//

import SwiftUI
import SwiftData

struct RemindersSettingsView: View {
    @Bindable var profile: UserProfile

    @State private var authorizationDenied = false

    init(profile: UserProfile?) {
        // RemindersSettingsView is only ever pushed from the "editing
        // existing profile" path, where a profile always exists — but
        // the call site (ProfileSetupView) holds an Optional, so this
        // keeps the two views' types decoupled without force-unwrapping
        // at the call site.
        self.profile = profile ?? UserProfile()
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: Binding(
                            get: { profile.remindersEnabled },
                            set: { toggle($0) }
                        )) {
                            Label("Daily Reminders", systemImage: "bell.fill")
                                .font(.cuteHeadline())
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .tint(Theme.accent)

                        Text("A gentle local notification at times you pick — nothing leaves your device.")
                            .font(.cuteCaption())
                            .foregroundStyle(Theme.textSecondary)

                        if authorizationDenied {
                            Text("Notifications are turned off for this app in iOS Settings. Enable them there to get reminders.")
                                .font(.cuteCaption(12))
                                .foregroundStyle(Theme.blushDeep)
                        }
                    }
                    .cuteCard()

                    if profile.remindersEnabled {
                        VStack(alignment: .leading, spacing: 14) {
                            timeRow(
                                label: "Morning",
                                icon: "sun.max.fill",
                                time: Binding(
                                    get: { profile.amReminderTime ?? Self.defaultAM },
                                    set: { newValue in
                                        profile.amReminderTime = newValue
                                        NotificationScheduler.scheduleAM(at: newValue)
                                    }
                                )
                            )
                            Divider()
                            timeRow(
                                label: "Evening",
                                icon: "moon.stars.fill",
                                time: Binding(
                                    get: { profile.pmReminderTime ?? Self.defaultPM },
                                    set: { newValue in
                                        profile.pmReminderTime = newValue
                                        NotificationScheduler.schedulePM(at: newValue)
                                    }
                                )
                            )
                        }
                        .cuteCard(tint: Theme.lavender.opacity(0.5))
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            try? profile.modelContext?.save()
        }
    }

    private func timeRow(label: String, icon: String, time: Binding<Date>) -> some View {
        HStack {
            Label(label, systemImage: icon).font(.cuteBody()).foregroundStyle(Theme.textPrimary)
            Spacer()
            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    private func toggle(_ isOn: Bool) {
        profile.remindersEnabled = isOn
        if isOn {
            NotificationScheduler.requestAuthorization { granted in
                authorizationDenied = !granted
                guard granted else { return }
                let am = profile.amReminderTime ?? Self.defaultAM
                let pm = profile.pmReminderTime ?? Self.defaultPM
                profile.amReminderTime = am
                profile.pmReminderTime = pm
                NotificationScheduler.scheduleAM(at: am)
                NotificationScheduler.schedulePM(at: pm)
                try? profile.modelContext?.save()
            }
        } else {
            NotificationScheduler.cancelAll()
        }
    }

    private static var defaultAM: Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    }

    private static var defaultPM: Date {
        Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: .now) ?? .now
    }
}

#Preview {
    NavigationStack {
        RemindersSettingsView(profile: UserProfile())
    }
}
