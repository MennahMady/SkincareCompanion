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
    /// Builds a Color that resolves differently under Light vs Dark
    /// Mode — a thin wrapper around UIColor's trait-based dynamic
    /// provider. Because it returns a Color backed by a genuinely
    /// dynamic UIColor, it keeps adapting live even when captured once
    /// into a `static let` (SwiftUI/UIKit resolve it at draw/appearance
    /// time, not at the point this function runs), and it survives being
    /// round-tripped through `UIColor(someTheme Color)` in
    /// CuteAppearance below — which is what lets the nav bar and tab bar
    /// (set up once in `CuteAppearance.configure()`) adapt too.
    private static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    // MARK: Pastel accent palette — deliberately NOT dark-mode-adaptive.
    // These are used as small, self-contained chip/pill/badge fills
    // (concern chips, active pills, match-percent badges, the weekday
    // selector) that always pair with a fixed dark label — see
    // `onAccentText` below. Making the fills themselves swap color under
    // Dark Mode would break that pairing (the label wouldn't know to
    // follow), so both halves of every such pairing stay constant.
    static let blush        = Color(red: 1.00, green: 0.86, blue: 0.89)
    static let blushDeep    = Color(red: 0.95, green: 0.55, blue: 0.66)
    static let lavender     = Color(red: 0.90, green: 0.86, blue: 0.98)
    static let lavenderDeep = Color(red: 0.66, green: 0.55, blue: 0.90)
    static let peach        = Color(red: 1.00, green: 0.85, blue: 0.75)
    static let mint         = Color(red: 0.82, green: 0.95, blue: 0.89)
    static let butter       = Color(red: 1.00, green: 0.95, blue: 0.78)
    static let cream        = Color(red: 1.00, green: 0.98, blue: 0.95)

    // MARK: Adaptive content text — used for body copy, headlines, and
    // anything else sitting directly on the adaptive page background or
    // an adaptive `surface` card (defined below). Dark mode's values are
    // a soft warm off-white rather than pure white, to stay in the same
    // "cute pastel" family instead of looking stark.
    static let textPrimary = adaptive(
        light: Color(red: 0.36, green: 0.22, blue: 0.32),
        dark: Color(red: 0.95, green: 0.90, blue: 0.94)
    )
    static let textSecondary = adaptive(
        light: Color(red: 0.58, green: 0.46, blue: 0.55),
        dark: Color(red: 0.78, green: 0.70, blue: 0.76)
    )

    /// Fixed (never adaptive) — the same dark plum used for text-on-card
    /// in light mode, but used here specifically for labels that sit on
    /// one of the constant pastel accent fills above (chips, pills,
    /// badges). Those fills don't change under Dark Mode, so their
    /// labels can't either without breaking contrast.
    static let onAccentText = Color(red: 0.36, green: 0.22, blue: 0.32)
    static let onAccentTextSecondary = Color(red: 0.58, green: 0.46, blue: 0.55)

    /// The app's accent — used for the tab bar, buttons, toggles. Kept
    /// constant across modes; it's a saturated color that reads fine
    /// against both a light and a dark chrome background.
    static let accent = blushDeep

    /// Nav bar / tab bar chrome background — adaptive. Everything else
    /// (cards, chips) floats on top of this or on `surface`.
    static let chromeBackground = adaptive(
        light: cream,
        dark: Color(red: 0.13, green: 0.10, blue: 0.13)
    )

    /// Card / list-row / text-field surface — adaptive. Dark mode's
    /// value is deliberately a dark plum-gray rather than near-black, so
    /// it reads as "elevated" above the page background the way a light
    /// mode white card does above its cream/blush gradient.
    static let surface = adaptive(light: .white, dark: Color(red: 0.20, green: 0.16, blue: 0.19))

    static let backgroundGradient = LinearGradient(
        colors: [chromeBackground, blush.opacity(0.55), lavender.opacity(0.35)],
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

/// A frosted "liquid glass" look for this app's pill/bubble chrome — the
/// floating tab bar, the search/scan/manual mode switcher, and similar
/// floating controls. Layers a system blur `Material` (which genuinely
/// blurs whatever's behind it, unlike a flat translucent color) under an
/// optional color tint, then a faint white edge stroke to catch the light
/// the way real glass/plastic does. Deliberately kept separate from
/// `cuteCard()` — cards hold body text and need a fully opaque background
/// for reliable contrast, while this is for floating chrome sitting over
/// the pastel gradient background.
struct GlassShape: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color
    var tintOpacity: Double
    var material: Material

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(material)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(tintOpacity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.55), lineWidth: 1)
                )
        )
    }
}

extension View {
    /// `cornerRadius: .infinity`-ish usage isn't valid for a fixed radius,
    /// so pass a large radius (e.g. `Theme.cardCornerRadius` or the
    /// view's own half-height) for a capsule-like glass pill.
    func glass(cornerRadius: CGFloat, tint: Color = .clear, tintOpacity: Double = 0.3, material: Material = .ultraThinMaterial) -> some View {
        modifier(GlassShape(cornerRadius: cornerRadius, tint: tint, tintOpacity: tintOpacity, material: material))
    }
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
    var tint: Color = Theme.surface

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
    func cuteCard(tint: Color = Theme.surface) -> some View {
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

/// A small pill-shaped "glass" button style for nav-bar-adjacent actions
/// (Close/Done/Select) — matches the floating glass tab bar and mode
/// switcher elsewhere in the app, instead of a plain text toolbar link,
/// with the same press-down bounce every other button in this app has.
struct CuteGlassPillButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glass(cornerRadius: 100, tint: .white, tintOpacity: 0.4)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Outlined, pastel-tinted secondary button. The label text is always
/// Theme.onAccentText (a fixed, never-adaptive dark plum) rather than
/// the tint color itself — text-colored-same-as-a-15%-opacity-wash-of-
/// itself reads as nearly invisible (a real contrast bug caught during
/// on-device testing), so the tint only colors the background wash
/// while a fixed dark color keeps the label readable. It's `onAccentText`
/// rather than the adaptive `textPrimary` specifically because this
/// button's background tint is one of the constant pastel accent colors
/// — it doesn't get darker under Dark Mode, so its label can't turn
/// light without breaking contrast.
struct CuteSecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.lavenderDeep

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.cuteHeadline())
            .foregroundStyle(Theme.onAccentText)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(tint.opacity(0.28))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A small pastel pill used for tags — active ingredients, categories.
struct CutePill: View {
    let text: String
    var tint: Color = Theme.lavender
    // Fixed, not the adaptive Theme.textPrimary — this pill's `tint`
    // background is a constant pastel color, so its label has to stay a
    // constant dark color too (see CuteSecondaryButtonStyle above for
    // the same reasoning).
    var textColor: Color = Theme.onAccentText
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

/// A custom, glass-styled replacement for the native navigation bar.
///
/// SwiftUI's `.toolbar` API bridges button content through
/// `UIBarButtonItem` under the hood, which drops custom backgrounds and
/// padding on iOS versions before the OS itself started drawing bar
/// buttons as glass pills natively (iOS 26+) — so a
/// `.buttonStyle(CuteGlassPillButtonStyle())` inside a `ToolbarItem`
/// silently renders as a plain text link on anything earlier, even
/// though the exact same button style works fine outside a toolbar.
/// Drawing the whole bar directly in SwiftUI (paired with
/// `.toolbar(.hidden, for: .navigationBar)` on the screen using it)
/// sidesteps that, the same way `CuteFloatingTabBar` (in RootView.swift)
/// sidesteps the equivalent issue for the tab bar.
struct CuteGlassHeader<Leading: View, Trailing: View>: View {
    let title: String
    let leading: Leading
    let trailing: Trailing

    init(_ title: String, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            leading.frame(minWidth: 44, alignment: .leading)
            Spacer(minLength: 8)
            Text(title)
                .font(.cuteHeadline(17))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 8)
            trailing.frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Theme.chromeBackground.ignoresSafeArea(edges: .top))
    }
}

extension CuteGlassHeader where Leading == EmptyView {
    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.init(title, leading: { EmptyView() }, trailing: trailing)
    }
}

extension CuteGlassHeader where Trailing == EmptyView {
    init(_ title: String, @ViewBuilder leading: () -> Leading) {
        self.init(title, leading: leading, trailing: { EmptyView() })
    }
}

extension CuteGlassHeader where Leading == EmptyView, Trailing == EmptyView {
    init(_ title: String) {
        self.init(title, leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

/// Applies the app's global chrome: pastel navigation bars and a soft
/// gradient behind list content. Call once from the root of the view
/// hierarchy.
///
/// This intentionally no longer touches `UITabBarAppearance` at all. The
/// native `UITabBar` can't reliably be styled into the floating, fully
/// rounded "bubble" pill this app's design calls for on every iOS version
/// it might run on — that shape is only the system default on iOS 26's
/// Liquid Glass tab bar, and customizing the appearance proxy (even just
/// tinting it) risks flattening that back into the old edge-to-edge bar
/// on versions that do have it. Instead `MainTabView` (see RootView.swift)
/// hides the native tab bar entirely and draws its own floating capsule
/// tab bar in SwiftUI, so the "bubble" look is guaranteed everywhere
/// rather than depending on OS version and appearance-proxy quirks.
struct CuteAppearance {
    static func configure() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Theme.chromeBackground)
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

        UITableView.appearance().backgroundColor = .clear
    }
}
