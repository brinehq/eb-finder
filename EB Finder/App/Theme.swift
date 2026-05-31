import SwiftUI

// Design tokens for the EB Finder design system.
//
// Mirrors extension/styles.css and the upstream design-system spec
// (eb-finder-design-system/project/colors_and_type.css). Naming follows
// shadcn (https://ui.shadcn.com/docs/theming) — semantic
// foreground/background pairs, no brand prefix. Colors live in the
// asset catalog (theme-* colorsets) so designer tweaks in Xcode are
// picked up automatically, and dark variants are layered in via the
// `Dark Appearance` per colorset.
//
// Usage:
//
//     @Environment(\.theme) private var theme
//     Text("EB Finder")
//         .foregroundStyle(theme.primary)
//         .padding()
//         .background(theme.card, in: .rect(cornerRadius: Theme.Radius.lg))
//
// Swap themes at runtime by injecting a different instance:
//
//     ContentView().environment(\.theme, .default)

// MARK: - Theme

struct Theme {
    // Surfaces
    var background:             Color
    var foreground:             Color
    var card:                   Color
    var cardForeground:         Color
    var popover:                Color
    var popoverForeground:      Color

    // Primary — brand indigo workhorse
    var primary:                Color
    var primaryForeground:      Color

    // Secondary — the sand CTA (lower-emphasis filled action).
    // The one warm fill; indigo-ink text on sand, darkens on hover.
    var secondary:              Color
    var secondaryForeground:    Color
    var secondaryHover:         Color

    // Muted — subtle surfaces + lower-emphasis text. The passive SE
    // locale badge is a muted chip (muted + mutedForeground + a border
    // hairline) so metadata never reads as an EB affordance.
    var muted:                  Color
    var mutedForeground:        Color

    // Accent — interactive hover / selected surfaces (list-row hover).
    // Same value as `muted` in light mode (design-system intent: quiet
    // hover); diverges in dark mode so hover is visible.
    var accent:                 Color
    var accentForeground:       Color

    // Success — affirmative "this site IS a EuroBonus partner" state
    var success:                Color
    var successForeground:      Color

    // Destructive — NOT used in the shipped product (it has no
    // error/red state; "no match" is neutral gray). Provided for
    // shadcn completeness; reach for `muted` before introducing red.
    var destructive:            Color
    var destructiveForeground:  Color

    // Lines & focus
    var border:                 Color
    var input:                  Color
    var ring:                   Color

    /// The shipping EB Finder theme. Every color flows through the asset
    /// catalog (theme-* colorsets) so designer tweaks in Xcode are picked
    /// up automatically. Dark variants resolve via colorset appearances.
    static let `default` = Theme(
        background:            .themeBackground,
        foreground:            .themeForeground,
        card:                  .themeCard,
        cardForeground:        .themeCardForeground,
        popover:               .themePopover,
        popoverForeground:     .themePopoverForeground,
        primary:               .themePrimary,
        primaryForeground:     .themePrimaryForeground,
        secondary:             .themeSecondary,
        secondaryForeground:   .themeSecondaryForeground,
        secondaryHover:        .themeSecondaryHover,
        muted:                 .themeMuted,
        mutedForeground:       .themeMutedForeground,
        accent:                .themeAccent,
        accentForeground:      .themeAccentForeground,
        success:               .themeSuccess,
        successForeground:     .themeSuccessForeground,
        destructive:           .themeDestructive,
        destructiveForeground: .themeDestructiveForeground,
        border:                .themeBorder,
        input:                 .themeInput,
        ring:                  .themeRing
    )
}

// MARK: - Radius

extension Theme {
    /// Corner-radius ladder derived from a 0.5rem (8pt) base, using
    /// shadcn's multipliers. Pills use `Capsule()` or
    /// `RoundedRectangle(cornerRadius: .infinity)` — no token needed.
    enum Radius {
        /// 4.8pt — chip, locale badge.
        static let sm: CGFloat = lg * 0.6
        /// 6.4pt — match-list rows.
        static let md: CGFloat = lg * 0.8
        /// 8pt — popup status / CTA blocks. The base radius.
        static let lg: CGFloat = 8
        /// 11.2pt — slightly larger cards.
        static let xl: CGFloat = lg * 1.4
    }
}

// MARK: - Shadows

extension View {
    /// Soft drop shadow used on the injected partner banner.
    /// Matches `--shadow-banner` in styles.css.
    func bannerShadow() -> some View {
        shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    /// Tight drop shadow used on the injected "EB" chip.
    /// Matches `--shadow-chip` in styles.css.
    func chipShadow() -> some View {
        shadow(color: .black.opacity(0.20), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Font weight

extension Font.Weight {
    /// 900 — reserved for the points figure (the design's loudest element).
    static let points: Font.Weight = .black
}

// MARK: - Environment value

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .default
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
