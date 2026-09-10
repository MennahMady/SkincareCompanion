//
//  ProductScannerView.swift
//  SkincareCompanion
//
//  Two honest ways to "scan" a product, both live-camera, on-device
//  (VisionKit's DataScannerViewController — no photo is saved or sent
//  anywhere):
//
//  1. A real barcode → looked up against Open Beauty Facts, same as
//     typing the barcode in by hand would (see OpenBeautyFactsService).
//  2. No barcode, or one OBF doesn't recognize → tap the product name
//     as printed on the label instead. This is plain on-device text
//     recognition (OCR), NOT product identification — the scanner has
//     no idea what a "cleanser" looks like versus a "serum," it's just
//     reading text off a package. The recognized text prefills the
//     manual-entry form, which the user still reviews and confirms
//     before it's saved. Framing it any more confidently than that
//     would be the same kind of overclaim the disclaimer/progress-photo
//     work elsewhere in this app deliberately avoids.
//
//  Requires a `NSCameraUsageDescription` entry in Info.plist (add one
//  in Xcode's target settings — something like "Used to scan a
//  product's barcode or label to add it to your bag.") and only works
//  on a physical device; DataScannerViewController isn't available in
//  the simulator.
//
//  A barcode that resolves also gets scored against the user's own
//  profile — skin type, concerns, personal allergens, pregnancy/nursing
//  status, and what's already in the bag — via ProductFitScorer, so
//  scanning something in a store aisle answers "is this actually good
//  for ME" rather than just "what is this."
//

import SwiftUI
import SwiftData
import VisionKit

struct ProductScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [UserProfile]
    @Query private var bagItems: [BagItem]
    @Query private var personalAllergens: [PersonalAllergen]

    private let service: ProductSearching

    @State private var isScanning = true
    @State private var isLookingUp = false
    @State private var statusMessage: String?
    @State private var prefillName: String?
    @State private var showingManualEntry = false
    @State private var scannedFit: FitResultItem?

    init(service: ProductSearching? = nil) {
        self.service = service ?? OpenBeautyFactsService()
    }

    private var fitContext: ProductFitContext {
        let profile = profiles.first
        return ProductFitContext(
            skinType: profile?.skinType,
            concerns: profile?.selectedConcerns ?? [],
            personalAllergens: personalAllergens.map { $0.term },
            isPregnantOrNursing: profile?.isPregnantOrNursing ?? false,
            ageRange: profile?.ageRange,
            currentBagActives: bagItems.reduce(into: Set<Active>()) { $0.formUnion($1.detectedActives) }
        )
    }

    private var scannerSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    // Deliberately no NavigationStack of its own here — this view is
    // presented as one tab of AddProductSheet's mode picker (alongside
    // Search/Manual, neither of which wraps its own nav chrome either),
    // so it shares that sheet's own title bar and Close/Done buttons
    // rather than stacking a second nav bar underneath them.
    var body: some View {
        ZStack {
            if scannerSupported {
                ScannerRepresentable(isScanning: $isScanning, onBarcode: handleBarcode, onText: handleText)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        if isLookingUp {
                            ProgressView().tint(.white)
                        }
                        if let statusMessage {
                            Text(statusMessage)
                                .font(.cuteCaption(13))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                        }
                        Text("Point at a barcode, or tap the product name printed on the label.")
                            .font(.cuteCaption(12))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(10)
                            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            } else {
                unsupportedState
            }
        }
        .sheet(isPresented: $showingManualEntry, onDismiss: { prefillName = nil; isScanning = true }) {
            NavigationStack {
                ManualProductEntryView(onAdd: {
                    showingManualEntry = false
                    dismiss()
                }, prefillName: prefillName)
                .navigationTitle("Confirm Product")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(item: $scannedFit, onDismiss: { isScanning = true }) { item in
            NavigationStack {
                FitResultView(
                    product: item.product,
                    fit: item.fit,
                    onAdd: {
                        modelContext.insert(BagItem(product: item.product))
                        try? modelContext.save()
                        scannedFit = nil
                        dismiss()
                    },
                    onSkip: { scannedFit = nil }
                )
            }
        }
    }

    private var unsupportedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 44))
                .foregroundStyle(Theme.textSecondary)
            Text("Scanning isn't available here")
                .font(.cuteHeadline())
                .foregroundStyle(Theme.textPrimary)
            Text("Live camera scanning needs a physical device — it doesn't run in the iOS Simulator. Search or enter the product manually instead.")
                .font(.cuteBody())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.backgroundGradient)
    }

    private func handleBarcode(_ code: String) {
        guard !isLookingUp else { return }
        isScanning = false
        isLookingUp = true
        statusMessage = "Looking up \(code)…"

        Task {
            do {
                let product = try await service.fetchProduct(barcode: code)
                let fit = ProductFitScorer.score(product: product, context: fitContext)
                await MainActor.run {
                    isLookingUp = false
                    statusMessage = nil
                    scannedFit = FitResultItem(product: product, fit: fit)
                }
            } catch {
                await MainActor.run {
                    isLookingUp = false
                    statusMessage = "No listing found for that barcode — try tapping the product name on the label instead."
                    isScanning = true
                }
            }
        }
    }

    private func handleText(_ text: String) {
        guard !isLookingUp else { return }
        isScanning = false
        prefillName = text
        showingManualEntry = true
    }
}

/// Identifiable wrapper so `.sheet(item:)` can present a (Product,
/// ProductFit) pair — neither type needs to conform to Identifiable on
/// its own account of this.
private struct FitResultItem: Identifiable {
    let product: Product
    let fit: ProductFit
    var id: String { product.id }
}

/// Shows the scored result for a scanned barcode: a percentage, a
/// verdict, and every reason that moved the score — so "63%" is never
/// just a number handed down with no explanation.
private struct FitResultView: View {
    let product: Product
    let fit: ProductFit
    let onAdd: () -> Void
    let onSkip: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var verdictColor: Color {
        switch fit.verdict {
        case .avoid: return Theme.blushDeep
        case .caution: return Theme.peach
        case .good: return Theme.lavenderDeep
        case .great: return Theme.mint
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text(product.name).font(.cuteTitle(20)).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.center)
                    if let brand = product.brand {
                        Text(brand).font(.cuteBody()).foregroundStyle(Theme.textSecondary)
                    }
                }

                ZStack {
                    Circle().stroke(verdictColor.opacity(0.25), lineWidth: 14).frame(width: 140, height: 140)
                    Circle()
                        .trim(from: 0, to: CGFloat(fit.percentage) / 100)
                        .stroke(verdictColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(fit.percentage)%").font(.cuteTitle(30)).foregroundStyle(Theme.textPrimary)
                        Text(fit.verdict.rawValue).font(.cuteCaption(12)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Why", systemImage: "text.magnifyingglass").font(.cuteHeadline()).foregroundStyle(Theme.textPrimary)
                    ForEach(Array(fit.reasons.enumerated()), id: \.offset) { _, reason in
                        Text("• \(reason)").font(.cuteBody(13)).foregroundStyle(Theme.textSecondary)
                    }
                    Text("A rule-based estimate from your profile and this product's listed ingredients — not medical advice, and it only catches what's in the app's ingredient list.")
                        .font(.cuteCaption(10))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cuteCard(tint: verdictColor.opacity(0.15))

                VStack(spacing: 10) {
                    Button("Add to Bag 🎀") { onAdd() }
                        .buttonStyle(CuteButtonStyle())
                    Button("Not This One") {
                        onSkip()
                        dismiss()
                    }
                    .buttonStyle(CuteSecondaryButtonStyle())
                }
            }
            .padding()
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) { header }
    }

    // Pulled out of `body` on purpose: inlining this closure directly
    // into `.safeAreaInset` made the whole `body` one giant expression,
    // and Swift's type-checker choked on it — reported (misleadingly) as
    // an "Ambiguous use of 'init'" pointing at the unrelated `ScrollView`
    // above rather than anything to do with this header. Giving it its
    // own explicitly-typed property splits the expression in two and
    // resolves the type-checker timeout.
    private var header: some View {
        CuteGlassHeader("Product Fit") {
            Button("Close") { onSkip(); dismiss() }
                .buttonStyle(CuteGlassPillButtonStyle())
        } trailing: {
            EmptyView()
        }
    }
}

/// UIViewControllerRepresentable wrapper around VisionKit's live-camera
/// scanner, recognizing both barcodes and on-screen text in one session
/// so a single scan sheet covers both entry paths.
private struct ScannerRepresentable: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    let onBarcode: (String) -> Void
    let onText: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(), .text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isScanning {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcode: onBarcode, onText: onText)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcode: (String) -> Void
        let onText: (String) -> Void

        init(onBarcode: @escaping (String) -> Void, onText: @escaping (String) -> Void) {
            self.onBarcode = onBarcode
            self.onText = onText
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .barcode(let barcode):
                guard let payload = barcode.payloadStringValue else { return }
                onBarcode(payload)
            case .text(let text):
                onText(text.transcript)
            @unknown default:
                break
            }
        }
    }
}
