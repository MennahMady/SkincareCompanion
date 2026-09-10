//
//  ProgressLogView.swift
//  SkincareCompanion
//
//  Three ways of tracking "is this actually working" over time: a
//  consistency streak (did the routine actually happen, not just what
//  was scheduled), a 1-tap daily check-in (with a simple, honestly
//  caveated correlation check against actives in use), and a private
//  photo + note timeline. Deliberately does NOT claim to analyze or
//  score photos with any kind of "AI skin scanning" — that's a real
//  feature in some competitor apps, but not one grounded in anything
//  this app could actually verify, so photos stay a plain journal the
//  user judges with their own eyes; the check-in correlation is the one
//  place this app does draw a data-backed conclusion, and it's kept
//  deliberately conservative (a minimum sample size, raw counts shown
//  alongside the rate) about it.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ProgressLogView: View {
    @Query(sort: \ProgressPhoto.dateTaken, order: .reverse) private var photos: [ProgressPhoto]
    @Query private var routineCompletions: [RoutineCompletion]
    @Query(sort: \SkinCheckIn.date, order: .reverse) private var checkIns: [SkinCheckIn]
    @Query private var bagItems: [BagItem]
    @Environment(\.modelContext) private var modelContext

    @State private var pickerItem: PhotosPickerItem?
    @State private var pendingImageData: Data?
    @State private var noteDraft = ""
    @State private var showingAddSheet = false

    private var streak: Int {
        RoutineAdherence.currentStreak(completions: routineCompletions)
    }

    private var recentDays: [DayAdherence] {
        RoutineAdherence.recentDays(completions: routineCompletions, days: 21)
    }

    private var flareFlags: [ActiveFlareFlag] {
        let entries = checkIns.map { (date: $0.date, feeling: $0.feeling) }
        return SkinCheckInInsights.flareFlags(checkIns: entries, bag: bagItems.map { $0.asProduct })
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    ConsistencyCard(streak: streak, days: recentDays)
                    CheckInCard(checkIns: checkIns, flareFlags: flareFlags, onLog: logCheckIn)

                    if photos.isEmpty {
                        VStack(spacing: 12) {
                            Text("📸").font(.system(size: 44))
                            Text("No photos yet").font(.cuteHeadline())
                            Text("Add a dated photo now and then to see how things look over weeks — this stays on your device, and nothing here is analyzed automatically.")
                                .font(.cuteBody())
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                            Button("Add a Photo") { showingAddSheet = true }
                                .buttonStyle(CuteButtonStyle())
                        }
                        .cuteCard()
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(photos) { photo in
                                ProgressPhotoRow(photo: photo) {
                                    modelContext.delete(photo)
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            CuteGlassHeader("Progress") { } trailing: {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                }
                .background(
                    Circle()
                        .fill(Theme.accent)
                        .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                        .shadow(color: Theme.blushDeep.opacity(0.3), radius: 6, x: 0, y: 3)
                )
            }
        }
        .sheet(isPresented: $showingAddSheet, onDismiss: resetDraft) {
            addSheet
        }
    }

    private var addSheet: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if let pendingImageData, let uiImage = UIImage(data: pendingImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 260)
                                .background(RoundedRectangle(cornerRadius: Theme.cardCornerRadius).fill(Theme.surface))
                        }

                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Label(pendingImageData == nil ? "Choose a Photo" : "Choose a Different Photo", systemImage: "photo.badge.plus")
                        }
                        .buttonStyle(CuteSecondaryButtonStyle())
                        .onChange(of: pickerItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    pendingImageData = data
                                }
                            }
                        }

                        TextField("Optional note (e.g. \"week 2 of retinoid\")", text: $noteDraft, axis: .vertical)
                            .font(.cuteBody())
                            .foregroundStyle(Theme.onAccentText)
                            .tint(Theme.accent)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))

                        Button("Save to Timeline") {
                            save()
                        }
                        .buttonStyle(CuteButtonStyle())
                        .disabled(pendingImageData == nil)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Progress Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddSheet = false }
                        .buttonStyle(CuteGlassPillButtonStyle())
                }
            }
        }
    }

    private func save() {
        guard let pendingImageData else { return }
        modelContext.insert(ProgressPhoto(note: noteDraft.trimmingCharacters(in: .whitespacesAndNewlines), imageData: pendingImageData))
        try? modelContext.save()
        showingAddSheet = false
    }

    private func resetDraft() {
        pickerItem = nil
        pendingImageData = nil
        noteDraft = ""
    }

    private func logCheckIn(_ feeling: SkinFeeling) {
        let key = RoutineViewModel.dayKey(for: .now)
        if let existing = checkIns.first(where: { $0.dayKey == key }) {
            existing.feeling = feeling
        } else {
            modelContext.insert(SkinCheckIn(dayKey: key, feeling: feeling))
        }
        try? modelContext.save()
    }
}

/// A streak count plus a 21-day heatmap strip — each square is filled
/// in when at least one session (AM or PM) was marked done that day.
private struct ConsistencyCard: View {
    let streak: Int
    let days: [DayAdherence]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Consistency", systemImage: "flame.fill").font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(streak)").font(.cuteTitle(28)).foregroundStyle(Theme.blushDeep)
                Text(streak == 1 ? "day streak" : "day streak").font(.cuteCaption()).foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 4) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(day.followed ? Theme.mint : Theme.textSecondary.opacity(0.2))
                        .frame(height: 18)
                }
            }
            Text("Mark \"Done\" on your Morning or Evening routine to build this up — checking what's scheduled isn't the same as actually doing it.")
                .font(.cuteCaption(10))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cuteCard(tint: Theme.butter.opacity(0.5))
    }
}

/// 1-tap daily feeling log plus any flare-active flags that clear the
/// (deliberately conservative) sample-size bar in SkinCheckInInsights.
private struct CheckInCard: View {
    let checkIns: [SkinCheckIn]
    let flareFlags: [ActiveFlareFlag]
    let onLog: (SkinFeeling) -> Void

    private var todaysFeeling: SkinFeeling? {
        let key = RoutineViewModel.dayKey(for: .now)
        return checkIns.first { $0.dayKey == key }?.feeling
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How's your skin today?", systemImage: "face.smiling").font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
            HStack(spacing: 10) {
                ForEach(SkinFeeling.allCases) { feeling in
                    Button {
                        onLog(feeling)
                    } label: {
                        VStack(spacing: 4) {
                            Text(feeling.emoji).font(.system(size: 26))
                            Text(feeling.displayName).font(.cuteCaption(11)).foregroundStyle(Theme.onAccentText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(todaysFeeling == feeling ? Theme.accent.opacity(0.25) : Color.white.opacity(0.6)))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !flareFlags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Worth a closer look").font(.cuteCaption(12)).foregroundStyle(Theme.textSecondary)
                    ForEach(flareFlags) { flag in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(flag.active.displayName).font(.cuteHeadline(13)).foregroundStyle(Theme.blushDeep)
                            Text("Scheduled on \(flag.irritatedDayHits) of your \(flag.totalIrritatedDays) \"irritated\" check-ins, vs. \(flag.allDayHits) of \(flag.totalDays) check-ins overall.")
                                .font(.cuteCaption(11))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Text("A pattern worth noting, not a diagnosis — small sample size, and correlation isn't causation. See a dermatologist for anything persistent.")
                        .font(.cuteCaption(10))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cuteCard(tint: Theme.lavender.opacity(0.5))
    }
}

private struct ProgressPhotoRow: View {
    let photo: ProgressPhoto
    var onDelete: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: Theme.cardCornerRadius).fill(Theme.surface))
            }
            HStack {
                Text(Self.dateFormatter.string(from: photo.dateTaken))
                    .font(.cuteCaption())
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(Theme.blushDeep)
                }
                .buttonStyle(.plain)
            }
            if !photo.note.isEmpty {
                Text(photo.note).font(.cuteBody(13)).foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface.opacity(0.7)))
    }
}

#Preview {
    NavigationStack {
        ProgressLogView()
            .modelContainer(for: [ProgressPhoto.self, RoutineCompletion.self, SkinCheckIn.self, BagItem.self], inMemory: true)
    }
}
