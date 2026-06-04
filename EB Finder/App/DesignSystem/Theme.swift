import SwiftUI

// EB Finder design system — a SwiftUI port of the shadcn / SwiftCN token model.
//
// Tokens live where SwiftUI can best express them:
//   • Colors      → asset catalog (light/dark), surfaced as typed Theme.Colors.*
//   • Spacing     → a 4-pt CGFloat scale (shadcn spacing ramp)
//   • Radius      → a CGFloat scale (0.5rem base × shadcn multipliers)
//   • Typography  → a `.typography(_:)` view modifier (font + tracking + line
//                   height — the two things `Font` alone can't carry)
//
// Asset-symbol generation stays OFF: the generated `Primary` / `Secondary`
// symbols collide with SwiftUI's own `Color.primary` / `.secondary`. Theme.Colors
// is the hand-rolled, collision-free, type-safe accessor over the same colorsets,
// so the asset catalog stays the single source of truth for the values.

enum Theme {}

// MARK: - Colors

extension Theme {
    /// Typed accessors for the colorsets in Assets.xcassets. Names mirror the
    /// CSS/shadcn tokens; each colorset carries its own light/dark appearances.
    enum Colors {
        // Base
        static let background = Color("Background")
        static let foreground = Color("Foreground")
        static let border = Color("Border")
        static let input = Color("Input")
        static let ring = Color("Ring")
        // Surfaces
        static let card = Color("Card")
        static let cardForeground = Color("CardForeground")
        static let popover = Color("Popover")
        static let popoverForeground = Color("PopoverForeground")
        static let muted = Color("Muted")
        static let mutedForeground = Color("MutedForeground")
        // Brand & accents
        static let brand = Color("Brand")
        static let brandForeground = Color("BrandForeground")
        static let primary = Color("Primary")
        static let primaryForeground = Color("PrimaryForeground")
        static let secondary = Color("Secondary")
        static let secondaryForeground = Color("SecondaryForeground")
        static let accent = Color("Accent")
        static let accentForeground = Color("AccentForeground")
        // Status
        static let destructive = Color("Destructive")
        static let destructiveForeground = Color("DestructiveForeground")
        static let success = Color("Success")
        static let successForeground = Color("SuccessForeground")
        static let warning = Color("Warning")
        static let warningForeground = Color("WarningForeground")
        static let info = Color("Info")
        static let infoForeground = Color("InfoForeground")
    }
}

// MARK: - Spacing

extension Theme {
    /// shadcn 4-pt spacing scale. Use for padding / stack spacing instead of
    /// magic numbers.
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
}

// MARK: - Radius

extension Theme {
    /// Corner-radius ladder derived from a 0.5rem (8pt) base, using shadcn's
    /// multipliers. Pills use `Capsule()` — no token needed.
    enum Radius {
        /// 4.8pt — chips, locale badge.
        static let sm: CGFloat = lg * 0.6
        /// 6.4pt — match-list rows.
        static let md: CGFloat = lg * 0.8
        /// 8pt — popup status / CTA blocks. The base radius.
        static let lg: CGFloat = 8
        /// 11.2pt — slightly larger cards.
        static let xl: CGFloat = lg * 1.4
    }
}

// MARK: - Typography

extension Theme {
    /// The shadcn typography ramp on the system (SF) face. Heading levels use
    /// Apple's title vocabulary — shadcn `h1…h4` → `largeTitle`/`title`/`title2`/
    /// `title3`; `lead`/`large`/`small` keep shadcn's names. Apply with the
    /// `.typography(_:)` modifier, which also carries the tracking and line
    /// height that a bare `Font` can't.
    enum TextStyle {
        /// h1 — text-4xl, extra-bold, tracking-tight.
        case largeTitle
        /// h2 — text-3xl, semibold, tracking-tight.
        case title
        /// h3 — text-2xl, semibold, tracking-tight.
        case title2
        /// h4 — text-xl, semibold, tracking-tight.
        case title3
        /// p — base body copy.
        case body
        /// lead — larger intro copy (pair with `mutedForeground`).
        case lead
        /// large — emphasized inline text.
        case large
        /// small — fine print / labels.
        case small

        var font: Font {
            switch self {
            case .largeTitle: .system(size: 36, weight: .heavy)
            case .title:      .system(size: 30, weight: .semibold)
            case .title2:     .system(size: 24, weight: .semibold)
            case .title3:     .system(size: 20, weight: .semibold)
            case .body:       .system(size: 16, weight: .regular)
            case .lead:       .system(size: 20, weight: .regular)
            case .large:      .system(size: 18, weight: .semibold)
            case .small:      .system(size: 14, weight: .medium)
            }
        }

        /// shadcn `tracking-tight` (≈ −0.025em) on headings; 0 elsewhere.
        var tracking: CGFloat {
            switch self {
            case .largeTitle: -0.9
            case .title:      -0.75
            case .title2:     -0.6
            case .title3:     -0.5
            default:           0
            }
        }

        /// Extra leading for multi-line running copy.
        var lineSpacing: CGFloat {
            switch self {
            case .body, .lead: 2
            default:           0
            }
        }
    }
}

extension View {
    /// Apply a `Theme.TextStyle` — font, tracking and line height in one place.
    func typography(_ style: Theme.TextStyle) -> some View {
        modifier(TypographyModifier(style: style))
    }
}

private struct TypographyModifier: ViewModifier {
    let style: Theme.TextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
    }
}
