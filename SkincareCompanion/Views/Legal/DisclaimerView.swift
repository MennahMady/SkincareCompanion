//
//  DisclaimerView.swift
//  SkincareCompanion
//
//  A full-length medical/legal disclaimer, reachable from the Profile
//  tab at any time and required (as a short acknowledgment, not this
//  full read) once during onboarding. Having this as its own screen —
//  not just the one-line caption on the Routine screen — is what a
//  reviewer or a real user relying on the app publicly would expect to
//  be able to find. None of this is a substitute for actual legal
//  review before a real public release; it's written to be honest and
//  reasonably thorough, not to be legal advice itself.
//

import SwiftUI

struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Disclaimer 📋").font(.cuteTitle(24)).foregroundStyle(Theme.textPrimary)
                    Text("Please read before relying on this app for your skin.")
                        .font(.cuteCaption())
                        .foregroundStyle(Theme.textSecondary)
                }

                section(
                    icon: "cross.case.fill",
                    title: "Not medical advice",
                    body: "Glow Guide provides general, educational information about commonly-cited skincare practices — how products are conventionally layered, which ingredients are commonly paired or avoided, and typical usage frequency. It is not a substitute for professional medical or dermatological advice, diagnosis, or treatment. It is not reviewed or endorsed by a dermatologist or any medical professional. Always seek the advice of a qualified healthcare provider (such as a board-certified dermatologist) with any questions about a skin condition, before starting a new skincare routine, or before using any product on your skin — especially for persistent, painful, spreading, or severe symptoms."
                )

                section(
                    icon: "allergens",
                    title: "Allergies & patch testing",
                    body: "This app cannot know what you're personally allergic or sensitive to. Ingredient detection is based on scanning product text for common active-ingredient keywords — it is not a complete or verified allergen list, and it will miss ingredients it doesn't recognize. Before using any new product, check the full ingredient list yourself and consider a patch test (a small amount on your inner arm, checked after 24–48 hours) before applying it to your face. Stop use immediately and consult a doctor if you experience redness, burning, itching, swelling, or any other adverse reaction."
                )

                section(
                    icon: "checkmark.seal.fill",
                    title: "Data accuracy",
                    body: "Product and ingredient information comes from a mix of a community-maintained public database (Open Beauty Facts) and a hand-curated starter set built from publicly available product information. Neither is guaranteed to be complete, current, or free of errors — brands reformulate products, and crowd-sourced data can be outdated, mistagged, or missing fields. Always check the actual product packaging for the current, authoritative ingredient list before use."
                )

                section(
                    icon: "figure.child",
                    title: "Age-based guidance",
                    body: "This app is not available to users under 13. Guidance shown for other age ranges (such as flagging retinoids for teen profiles) reflects commonly-cited general practice, not an individualized medical recommendation, and does not account for your specific skin, health history, or any medication you may be using. Consult a dermatologist for guidance specific to your situation, particularly for anyone under 18."
                )

                section(
                    icon: "hand.raised.fill",
                    title: "No outcome guarantee",
                    body: "Skincare results vary significantly from person to person. This app makes no claims, guarantees, or warranties — express or implied — about results, effectiveness, or suitability of any routine, product, or recommendation it generates."
                )

                section(
                    icon: "doc.text.magnifyingglass",
                    title: "Use at your own risk",
                    body: "By using this app, you acknowledge that any skincare routine, product choice, or ingredient combination you adopt based on its suggestions is your own decision and responsibility. The developer is not liable for any adverse reaction, allergic response, skin irritation, or other harm resulting from products or routines used based on this app's content."
                )

                Text("Last reviewed: this app's initial release. If you're adapting this project, update this page to reflect your own product, data sources, and legal review.")
                    .font(.cuteCaption(11))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 8)
            }
            .padding()
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Disclaimer")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.cuteHeadline(15))
                .foregroundStyle(Theme.textPrimary)
            Text(body)
                .font(.cuteBody(13))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous).fill(Color.white.opacity(0.75)))
    }
}

#Preview {
    NavigationStack {
        DisclaimerView()
    }
}
