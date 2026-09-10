//
//  ProductLifecycle.swift
//  SkincareCompanion
//
//  PAO (Period After Opening) math — the little "12M" jar icon printed
//  on most skincare packaging. Pure date arithmetic so it's testable
//  without touching SwiftData.
//

import Foundation

enum ProductLifecycle {
    /// `nil` when there isn't enough info to estimate (no opened date,
    /// or no PAO months on file).
    static func estimatedExpiryDate(openedDate: Date?, paoMonths: Int?, calendar: Calendar = .current) -> Date? {
        guard let openedDate, let paoMonths, paoMonths > 0 else { return nil }
        return calendar.date(byAdding: .month, value: paoMonths, to: openedDate)
    }

    static func isLikelyExpired(openedDate: Date?, paoMonths: Int?, asOf date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let expiry = estimatedExpiryDate(openedDate: openedDate, paoMonths: paoMonths, calendar: calendar) else { return false }
        return expiry <= date
    }

    /// Within this many days of expiring but not yet past it — worth a
    /// gentle heads-up rather than a hard "expired" flag.
    static func isExpiringSoon(openedDate: Date?, paoMonths: Int?, asOf date: Date = .now, withinDays: Int = 14, calendar: Calendar = .current) -> Bool {
        guard let expiry = estimatedExpiryDate(openedDate: openedDate, paoMonths: paoMonths, calendar: calendar), expiry > date else { return false }
        guard let cutoff = calendar.date(byAdding: .day, value: withinDays, to: date) else { return false }
        return expiry <= cutoff
    }
}
