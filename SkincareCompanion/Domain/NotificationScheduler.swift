//
//  NotificationScheduler.swift
//  SkincareCompanion
//
//  Thin wrapper around UNUserNotificationCenter for the two repeating
//  daily local reminders (AM routine / PM routine). No push/remote
//  notifications anywhere in this app — everything here is scheduled
//  entirely on-device from times the user picks themselves.
//

import Foundation
import UserNotifications

enum NotificationScheduler {
    private static let amIdentifier = "routine-reminder-am"
    private static let pmIdentifier = "routine-reminder-pm"

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Schedules (or re-schedules, replacing any existing one) a
    /// repeating daily reminder at the given time's hour/minute.
    static func scheduleAM(at time: Date) {
        schedule(identifier: amIdentifier, time: time, title: "Morning routine ☀️", body: "Time for your AM skincare steps.")
    }

    static func schedulePM(at time: Date) {
        schedule(identifier: pmIdentifier, time: time, title: "Evening routine 🌙", body: "Time to wind down with your PM skincare steps.")
    }

    static func cancelAM() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [amIdentifier])
    }

    static func cancelPM() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [pmIdentifier])
    }

    static func cancelAll() {
        cancelAM()
        cancelPM()
    }

    private static func schedule(identifier: String, time: Date, title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = Calendar.current.dateComponents([.hour, .minute], from: time)
        components.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }
}
