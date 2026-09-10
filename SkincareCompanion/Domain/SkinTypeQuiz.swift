//
//  SkinTypeQuiz.swift
//  SkincareCompanion
//
//  A tiny, pure heuristic for someone who genuinely doesn't know their
//  skin type yet — 3 plain-language yes/no questions map to one of the
//  5 SkinType cases. Not a dermatological assessment, just a common-
//  sense starting point (the same "heuristic, not verified" spirit as
//  SkinTypeSuitability).
//

import Foundation

enum SkinTypeQuiz {
    struct Answers {
        /// Does your T-zone (forehead/nose/chin) get visibly shiny or
        /// oily by midday?
        var shinyByMidday: Bool
        /// Do your cheeks feel tight, rough, or flaky, especially after
        /// washing?
        var tightOrFlakyCheeks: Bool
        /// Do new products often make your skin sting, turn red, or itch?
        var easilyIrritated: Bool
    }

    static func result(for answers: Answers) -> SkinType {
        if answers.easilyIrritated {
            return .sensitive
        }
        switch (answers.shinyByMidday, answers.tightOrFlakyCheeks) {
        case (true, true):
            return .combination
        case (true, false):
            return .oily
        case (false, true):
            return .dry
        case (false, false):
            return .normal
        }
    }
}
