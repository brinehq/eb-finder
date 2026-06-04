import SwiftUI

// Design-token namespace for the EB Finder app.
//
// COLORS live entirely in the asset catalog — PascalCase colorsets named after
// the CSS tokens, referenced directly as `Color("Primary")`,
// `Color("MutedForeground")`, `Color("Brand")`, etc. They adapt to light/dark
// via each colorset's appearances, so the catalog is the single source of truth
// and there is no Swift color layer to keep in sync. (We reference by string
// because names like `Primary`/`Secondary` collide with SwiftUI's built-in
// `Color.primary` / `.secondary`, so asset-symbol generation stays off.)
//
// `Theme` below only namespaces the non-color tokens: radius + typography.

enum Theme {}

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

// MARK: - Typography

extension Theme {
    /// The shadcn typography ramp (https://ui.shadcn.com/docs/components/base/typography)
    /// on the system (SF) face. Heading levels use Apple's title vocabulary —
    /// shadcn `h1…h4` → `largeTitle`/`title`/`title2`/`title3`; `lead`/`large`/
    /// `small` keep shadcn's names. `Font` can't carry letter-spacing or
    /// line-height, so apply `.tracking()`/`.lineSpacing()` at the call site when
    /// a heading needs to be pixel-faithful.
    enum Typography {
        /// h1 — text-4xl, extra-bold, tracking-tight.
        static let largeTitle = Font.system(size: 36, weight: .heavy)
        /// h2 — text-3xl, semibold, tracking-tight.
        static let title = Font.system(size: 30, weight: .semibold)
        /// h3 — text-2xl, semibold, tracking-tight.
        static let title2 = Font.system(size: 24, weight: .semibold)
        /// h4 — text-xl, semibold, tracking-tight.
        static let title3 = Font.system(size: 20, weight: .semibold)
        /// p — base body copy.
        static let body = Font.system(size: 16, weight: .regular)
        /// lead — larger intro copy (pair with `MutedForeground`).
        static let lead = Font.system(size: 20, weight: .regular)
        /// large — emphasized inline text.
        static let large = Font.system(size: 18, weight: .semibold)
        /// small — fine print / labels.
        static let small = Font.system(size: 14, weight: .medium)
    }
}
