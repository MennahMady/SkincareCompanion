//
//  SkinCheckInInsights.swift
//  SkincareCompanion
//
//  A simple, honest correlation check between "irritated" check-ins and
//  which actives were scheduled to be in use on those days — directly
//  aimed at the most-cited skincare-app complaint (no visibility into
//  what's actually causing a reaction). This is NOT a diagnosis and NOT
//  causation — it's "this active showed up disproportionately often on
//  your irritated days," presented with the raw counts so the small
//  sample size is obvious rather than hidden behind a confident-sounding
//  percentage.
//
//  Deliberately reuses StepSchedule.isDue rather than needing a separate
//  "what did I actually use each day" log: since a product's schedule is
//  a pure function of (frequency, id, date), we can recompute what was
//  due on any past date from the CURRENT bag. The one honest caveat: if
//  the bag's contents changed since that date (a product added or
//  removed), the recomputed due-set won't perfectly reflect what was
//  actually in use back then — fine for a lightweight pattern-spotter,
//  not for anything more.
//

import Foundation

struct ActiveFlareFlag: Identifiable {
    let active: Active
    /// How many "irritated" check-in days had this active due.
    let irritatedDayHits: Int
    let totalIrritatedDays: Int
    /// How many check-in days of ANY feeling had this active due —
    /// gives a baseline to compare the irritated rate against.
    let allDayHits: Int
    let totalDays: Int
    var id: String { active.rawValue }

    var irritatedRate: Double {
        totalIrritatedDays == 0 ? 0 : Double(irritatedDayHits) / Double(totalIrritatedDays)
    }

    var baselineRate: Double {
        totalDays == 0 ? 0 : Double(allDayHits) / Double(totalDays)
    }
}

enum SkinCheckInInsights {
    /// Flags actives that were due disproportionately often on
    /// "irritated" days compared to their overall rate — requires at
    /// least `minimumIrritatedDays` irritated check-ins before flagging
    /// anything, since a pattern from 1-2 data points isn't a pattern.
    static func flareFlags(
        checkIns: [(date: Date, feeling: SkinFeeling)],
        bag: [Product],
        minimumIrritatedDays: Int = 3,
        calendar: Calendar = .current
    ) -> [ActiveFlareFlag] {
        let irritatedDates = checkIns.filter { $0.feeling == .irritated }.map { $0.date }
        guard irritatedDates.count >= minimumIrritatedDays else { return [] }

        let allActives = Set(bag.flatMap { $0.detectedActives })
        guard !allActives.isEmpty else { return [] }

        func activesDue(on date: Date) -> Set<Active> {
            bag.reduce(into: Set<Active>()) { result, product in
                let frequency = StepSchedule.frequency(for: product)
                if StepSchedule.isDue(frequency: frequency, productID: product.id, on: date, calendar: calendar) {
                    result.formUnion(product.detectedActives)
                }
            }
        }

        var flags: [ActiveFlareFlag] = []
        for active in allActives {
            let irritatedHits = irritatedDates.filter { activesDue(on: $0).contains(active) }.count
            let allHits = checkIns.filter { activesDue(on: $0.date).contains(active) }.count

            let flag = ActiveFlareFlag(
                active: active,
                irritatedDayHits: irritatedHits,
                totalIrritatedDays: irritatedDates.count,
                allDayHits: allHits,
                totalDays: checkIns.count
            )
            // Worth surfacing only if it shows up meaningfully more on
            // irritated days than its overall baseline — a flat-out
            // daily-use product (rate ~1.0 everywhere) wouldn't clear
            // this since it can't be disproportionate.
            if flag.irritatedRate >= 0.6, flag.irritatedRate > flag.baselineRate + 0.2 {
                flags.append(flag)
            }
        }
        return flags.sorted { $0.irritatedRate > $1.irritatedRate }
    }
}
