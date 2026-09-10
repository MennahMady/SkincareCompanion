//
//  PersonalAllergen.swift
//  SkincareCompanion
//
//  A free-text ingredient term the user has personally flagged as
//  something they react to — distinct from the built-in Active list,
//  which only covers common actives, not every possible allergen (a
//  specific fragrance compound, a plant extract, lanolin, etc.). Matched
//  as a case-insensitive substring against a product's ingredients text,
//  the same approach Active.detect already uses.
//

import Foundation
import SwiftData

// CloudKit-backed SwiftData requires every non-optional attribute to
// carry a default value at its declaration — see SkincareCompanionApp's
// CloudKit sync section.
@Model
final class PersonalAllergen {
    var id: String = ""
    var term: String = ""
    var dateAdded: Date = Date.now

    init(term: String, dateAdded: Date = .now) {
        self.id = UUID().uuidString
        self.term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dateAdded = dateAdded
    }
}
