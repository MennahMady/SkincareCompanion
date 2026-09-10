//
//  PregnancySafety.swift
//  SkincareCompanion
//
//  Flags ingredients with commonly-cited pregnancy/nursing caution —
//  same spirit as AgeRange's teen-retinoid caution: a heads-up on
//  products already in the bag, not a removal, and explicitly general
//  educational info rather than medical advice (this app has no way to
//  know someone's actual trimester, dose, or individual risk factors,
//  and guidance genuinely varies by source and provider).
//
//  Kept intentionally short and conservative rather than exhaustive:
//  - Retinoids (retinol/retinal/tretinoin/adapalene) are the most
//    consistently-cited "avoid during pregnancy" skincare active across
//    OB and dermatology sources — oral retinoids are a known teratogen,
//    and topical use is broadly advised against out of caution even
//    though systemic absorption is much lower.
//  - Salicylic acid (BHA) guidance is more nuanced — high-dose/oral use
//    is discouraged, but low-concentration topical/leave-on use is
//    considered lower-risk by many sources, so this is framed as
//    "worth checking with your OB about concentration," not a flat
//    avoid, to avoid overstating the consensus.
//

import Foundation

enum PregnancySafety {
    struct Flag {
        let active: Active
        let severity: Severity
        let detail: String

        enum Severity {
            case avoid
            case checkWithProvider
        }
    }

    static let flags: [Flag] = [
        Flag(
            active: .retinoid,
            severity: .avoid,
            detail: "Retinoids are the most consistently cited skincare ingredient to avoid during pregnancy — most OB and dermatology sources recommend stopping use."
        ),
        Flag(
            active: .salicylicAcid,
            severity: .checkWithProvider,
            detail: "Guidance on salicylic acid varies by concentration and use — many sources consider low-concentration topical use lower-risk, but it's worth confirming with your OB or midwife."
        ),
    ]

    static func flag(for active: Active) -> Flag? {
        flags.first { $0.active == active }
    }
}
