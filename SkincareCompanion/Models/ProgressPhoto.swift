//
//  ProgressPhoto.swift
//  SkincareCompanion
//
//  One entry in the private, on-device progress-photo timeline. No AI
//  analysis of these photos happens anywhere in the app — this is
//  intentionally just a dated, notable journal the user can scroll
//  through themselves, since "did this actually help" is something a
//  person judges by eye over weeks, not something this app claims to
//  score.
//

import Foundation
import SwiftData

// CloudKit-backed SwiftData requires every non-optional attribute to
// carry a default value at its declaration — see SkincareCompanionApp's
// CloudKit sync section. `.externalStorage` data still syncs fine; it's
// transferred as a CKAsset behind the scenes.
@Model
final class ProgressPhoto {
    var id: String = ""
    var dateTaken: Date = Date.now
    var note: String = ""
    @Attribute(.externalStorage) var imageData: Data = Data()

    init(dateTaken: Date = .now, note: String = "", imageData: Data) {
        self.id = UUID().uuidString
        self.dateTaken = dateTaken
        self.note = note
        self.imageData = imageData
    }
}
