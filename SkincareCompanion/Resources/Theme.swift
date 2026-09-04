//
//  Theme.swift
//  SkincareCompanion
//
//  A soft, pastel "cute" design system used across every screen: a
//  pink/lavender palette, rounded system fonts, pill-shaped chips, and
//  card styling with a gentle shadow. Centralizing it here means the
//  whole app's look can be retuned from one file.
//

import SwiftUI

enum Theme {
    // MARK: Palette
    static let blush        = Color(red: 1.00, green: 0.86, blue: 0.89)
    static let blushDeep    = Color(red: 0.95, green: 0.55, blue: 0.66)
    static let lavender     = Color(red: 0.90, green: 0.86, blue: 0.98)
    static let lavenderDeep = Color(red: 0.66, green: 0.55, blue: 0.90)
    static let peach        = Color(red: 1.00, green: 0.85, blue: 0.75)
    static let mint         = Color(red: 0.82, green: 0.95, blue: 0.89)
    static let butter       = Color(red: 1.00, green: 0.95, blue: 0.78)
    static let cream        = Color(red: 1.00, green: 0.98, blue: 0.95)

    static let textPrimary   = Color(red: 0.36, green: 0.22, blue: 0.32)
    static let textSecondary = Color(red: 0.58, green: 0.46, blue: 0.55)

    /// The app's accent — used for the tab bar, buttons, toggles.
    static let accent = blushDeep

    static let backgroundGradient = LinearGradient(
        colors: [cream, blush.opacity(0.55), lavender.opacity(0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// A rotating set of pastel tints so grouped content (concern chips,
    /// category headers) doesn't read as one flat block of pink.
    static let pastelCycle: [Color] = [blush, lavender, peach, mint, butter]

    static func pastel(for index: Int) -> Color {
        pastelCycle[abs(index) % pastelCycle.count]
    }

    static let cardCornerRadius: CGFloat = 22
    static let chipCornerRadius: CGFloat = 16
}

extension Font {
    static func cuteTitle(_ size: CGFloat = 28) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func cuteHeadline(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func cuteBody(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular, design: .rounded) }
    static func cuteCaption(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium, design: .rounded) }
}

/// Soft rounded card with a gentle shadow — the base "container" look
/// used for rows, sections, and empty states throughout the app.
struct CuteCardStyle: ViewModifier {
    var tint: Color = .white

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(tint)
                    .shadow(color: Theme.blushDeep.opacity(0.12), radius: 8, x: 0, y: 4)
            )
    }
}

extension View {
    func cuteCard(tint: Color = .white) -> some View {
        modifier(CuteCardStyle(tint: tint))
    }
}

/// Rounded, filled pastel button — the primary CTA style.
struct CuteButtonStyle: ButtonStyle {
    var background: Color = Theme.accent
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.cuteHeadline())
            .foregroundStyle(foreground)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(background)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Outlined, pastel-tinted secondary button.
struct CuteSecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.lavenderDeep

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.cuteHeadline())
            .foregroundStyle(tint)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(tint.opacity(0.15))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A small pastel pill used for tags — active ingredients, categories.
struct CutePill: View {
    let text: String
    var tint: Color = Theme.lavender
    var textColor: Color = Theme.textPrimary
    var icon: String?

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.caption2)
            }
            Text(text)
        }
        .font(.cuteCaption())
        .foregroundStyle(textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint))
    }
}

/// Applies the app's global chrome: pastel navigation bars, tinted tab
/// bar, and a soft gradient behind list content. Call once from the
/// root of the view hierarchy.
struct CuteAppearance {
    static func configure() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Theme.cream)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(Theme.textPrimary),
            .font: UIFont.systemFont(ofSize: 18, weight: .bold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Theme.textPrimary),
            .font: UIFont.systemFont(ofSize: 32, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(Theme.accent)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Theme.cream)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = UIColor(Theme.accent)
        UITabBar.appearance().unselectedItemTintColor = UIColor(Theme.textSecondary)

        UITableView.appearance().backgroundColor = .clear
    }
}
