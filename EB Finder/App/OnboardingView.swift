import SwiftUI

// Guided onboarding — the "EB Finder Onboarding — Guided" design.
//
//   welcome → Aktivera tillägget → Tillåt på alla webbplatser → Allt klart!
//
// The treatment is the host app's branded brand moment: a deep-indigo (or, in
// light mode, soft-lavender) "Liquid Glass" atmosphere built from the EB brand
// primitives, centered content, 96pt marks, progress dots and the sand CTA
// pill. The flow is forward-only (no back button). Unlike the design prototype
// — which *simulated* the extension checks — each step here reflects the real
// `ExtensionState`: checking → blocked (CTA opens Safari settings) → done.

private enum OnboardingStep: CaseIterable { case enableExtension, grantPermissions }
private enum OnboardingStepStatus { case checking, blocked, done }

struct OnboardingView: View {
    let state: ExtensionState
    let onComplete: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var screen: Screen = .welcome
    /// The steps that still need action, snapshotted when the user taps Get
    /// Started. Steps already satisfied at that point are never presented; this
    /// list drives both the screen sequence and the progress dots.
    @State private var flow: [OnboardingStep] = []

    private enum Screen: Hashable { case welcome, enableExtension, grantPermissions, done }

    var body: some View {
        let palette = OnboardingPalette(theme: theme, colorScheme: colorScheme)
        ZStack {
            OnboardingAtmosphere(palette: palette)

            VStack(spacing: 0) {
                topBar(palette)

                Spacer(minLength: 0)

                content(palette)
                    .id(screen)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                Spacer(minLength: 0)

                cta(palette)
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
            }
        }
        .animation(.snappy, value: screen)
        .animation(.snappy, value: state.status)
        .animation(.snappy, value: state.hostPermission)
        .animation(.snappy, value: state.isChecking)
    }

    // MARK: Top bar (progress dots — forward-only, no back button)

    @ViewBuilder
    private func topBar(_ palette: OnboardingPalette) -> some View {
        ZStack {
            if flow.count >= 1, let index = dotIndex {
                ProgressDots(index: index, total: flow.count + 1, active: palette.dotActive, inactive: palette.dotInactive)
            }
        }
        .frame(height: 40)
        .padding(.top, 12)
    }

    // One dot per presented step, plus a final dot for the "all set" screen.
    private var dotIndex: Int? {
        switch screen {
        case .welcome: return nil
        case .done: return flow.count
        case .enableExtension, .grantPermissions:
            return stepFor(screen).flatMap { flow.firstIndex(of: $0) }
        }
    }

    // MARK: Centered content per screen

    @ViewBuilder
    private func content(_ palette: OnboardingPalette) -> some View {
        switch screen {
        case .welcome:
            welcome(palette)
        case .enableExtension:
            step(palette, step: .enableExtension)
        case .grantPermissions:
            step(palette, step: .grantPermissions)
        case .done:
            done(palette)
        }
    }

    private func welcome(_ palette: OnboardingPalette) -> some View {
        VStack(spacing: 0) {
            EBAppIcon(size: 96, float: true)
            Text("onboarding.welcome.title")
                .onboardingTitle(28, palette.ink)
                .padding(.top, 30)
            Text("onboarding.welcome.detail")
                .onboardingBody(palette.sub)
                .frame(maxWidth: 300)
                .padding(.top, 16)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 26)
    }

    private func step(_ palette: OnboardingPalette, step: OnboardingStep) -> some View {
        let status = status(for: step)
        let copy = OnboardingCopy.copy(for: step)
        return VStack(spacing: 0) {
            ZStack {
                if status == .done {
                    CompletionCheck(size: 96)
                } else {
                    Image(systemName: copy.symbol)
                        .font(.system(size: 80, weight: .light))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(palette.glyph)
                }
            }
            .frame(height: 104)

            Text(status == .done ? copy.doneTitle : copy.title)
                .onboardingTitle(28, palette.ink)
                .padding(.top, 30)

            Text(status == .done ? copy.doneDetail : copy.detail)
                .onboardingBody(palette.sub)
                .frame(maxWidth: 320)
                .padding(.top, 14)

            if status != .done {
                SettingsPathChip(textKey: copy.path, palette: palette)
                    .padding(.top, 22)
            }

            if status != .done, let error = errorMessage {
                Text(verbatim: error)
                    .font(.footnote)
                    .foregroundStyle(palette.sub.opacity(0.8))
                    .padding(.top, 14)
                    .frame(maxWidth: 300)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 30)
    }

    private func done(_ palette: OnboardingPalette) -> some View {
        VStack(spacing: 0) {
            Text("onboarding.done.title")
                .onboardingTitle(30, palette.ink)
            Text("onboarding.done.detail")
                .onboardingBody(palette.sub)
                .frame(maxWidth: 290)
                .padding(.top, 12)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 26)
    }

    // MARK: Docked CTA per screen + status

    @ViewBuilder
    private func cta(_ palette: OnboardingPalette) -> some View {
        switch screen {
        case .welcome:
            OnboardingCTAButton("onboarding.welcome.button", variant: .primary, palette: palette,
                                showArrow: true, shimmer: true, action: goNext)
        case .enableExtension:
            stepCTA(palette, step: .enableExtension)
        case .grantPermissions:
            stepCTA(palette, step: .grantPermissions)
        case .done:
            OnboardingCTAButton("onboarding.done.button", variant: .primary, palette: palette,
                                showArrow: true, shimmer: true, action: onComplete)
        }
    }

    @ViewBuilder
    private func stepCTA(_ palette: OnboardingPalette, step: OnboardingStep) -> some View {
        let copy = OnboardingCopy.copy(for: step)
        switch status(for: step) {
        case .checking:
            OnboardingCTAButton("onboarding.checking", variant: .glass, palette: palette,
                                spinner: true, action: {})
                .disabled(true)
        case .blocked:
            VStack(spacing: 14) {
                OnboardingCTAButton(copy.button, variant: .primary, palette: palette, action: openSettings)
                if step == .grantPermissions {
                    // Live permission detection relies on the extension pinging the
                    // app group after the user next loads a page, which can lag — so
                    // never trap them here.
                    Button(action: goNext) {
                        HStack(spacing: 3) {
                            Text("onboarding.permissions.skip")
                            Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.sub)
                    }
                    .buttonStyle(.plain)
                }
            }
        case .done:
            OnboardingCTAButton("onboarding.continue", variant: .primary, palette: palette,
                                showArrow: true, shimmer: true, action: goNext)
        }
    }

    // MARK: State → step status (driven by the real ExtensionState)

    private func status(for step: OnboardingStep) -> OnboardingStepStatus {
        switch step {
        case .enableExtension:
            if state.status == .enabled { return .done }
            if state.isChecking { return .checking }
            return .blocked
        case .grantPermissions:
            if state.hostPermission == .allWebsites { return .done }
            if state.isChecking { return .checking }
            return .blocked
        }
    }

    private var errorMessage: String? {
        if case .error(let message) = state.status { return message }
        return nil
    }

    // MARK: Navigation (forward-only, skipping already-satisfied steps)

    private func goNext() {
        switch screen {
        case .welcome:
            // Snapshot only the steps that still need action — present nothing
            // the user has already taken care of.
            flow = OnboardingStep.allCases.filter { !isSatisfied($0) }
            screen = flow.first.map(screenFor) ?? .done
        case .enableExtension, .grantPermissions:
            if let step = stepFor(screen), let i = flow.firstIndex(of: step), i + 1 < flow.count {
                screen = screenFor(flow[i + 1])
            } else {
                screen = .done
            }
        case .done:
            onComplete()
        }
    }

    private func isSatisfied(_ step: OnboardingStep) -> Bool {
        switch step {
        case .enableExtension: return state.status == .enabled
        case .grantPermissions: return state.hostPermission == .allWebsites
        }
    }

    private func screenFor(_ step: OnboardingStep) -> Screen {
        switch step {
        case .enableExtension: return .enableExtension
        case .grantPermissions: return .grantPermissions
        }
    }

    private func stepFor(_ screen: Screen) -> OnboardingStep? {
        switch screen {
        case .enableExtension: return .enableExtension
        case .grantPermissions: return .grantPermissions
        case .welcome, .done: return nil
        }
    }

    private func openSettings() {
        Task { await state.openSafariExtensionPreferences() }
    }
}

// MARK: - Per-step copy

private struct OnboardingCopy {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let button: LocalizedStringKey
    let path: LocalizedStringKey
    let doneTitle: LocalizedStringKey
    let doneDetail: LocalizedStringKey

    static func copy(for step: OnboardingStep) -> OnboardingCopy {
        switch step {
        case .enableExtension:
            OnboardingCopy(
                symbol: "puzzlepiece.extension",
                title: "onboarding.enable.title",
                detail: "onboarding.enable.detail",
                button: "onboarding.enable.button",
                path: "onboarding.enable.path",
                doneTitle: "onboarding.enable.doneTitle",
                doneDetail: "onboarding.enable.doneDetail"
            )
        case .grantPermissions:
            OnboardingCopy(
                symbol: "lock.shield",
                title: "onboarding.permissions.title",
                detail: "onboarding.permissions.detail",
                button: "onboarding.permissions.button",
                path: "onboarding.permissions.path",
                doneTitle: "onboarding.permissions.doneTitle",
                doneDetail: "onboarding.permissions.doneDetail"
            )
        }
    }
}

// MARK: - Palette (brand-derived, light/dark)

/// The onboarding's Liquid-Glass atmosphere, sourced entirely from `Theme`
/// primitives — the atmosphere wash, ambient blobs and step glyph come from the
/// `theme.onboarding.*` colorsets (which carry their own light + dark values),
/// while ink/subtitle/chip reuse the shadcn tokens. Nothing here hardcodes a
/// color; only blob opacity and the active-dot accent vary by appearance.
struct OnboardingPalette {
    let isDark: Bool
    let pageGradient: LinearGradient
    let ink: Color
    let sub: Color
    let glyph: Color
    let chipBackground: Color
    let chipForeground: Color
    let dotActive: Color
    let dotInactive: Color
    let blobs: [Blob]

    struct Blob: Identifiable {
        let id: Int
        let color: Color
        let size: CGFloat
        let alignment: Alignment
        let offset: CGSize
        let opacity: Double
    }

    init(theme: Theme, colorScheme: ColorScheme) {
        let dark = colorScheme == .dark
        isDark = dark
        let atmo = theme.onboarding
        pageGradient = LinearGradient(
            colors: [atmo.atmosphereTop, atmo.atmosphereMid, atmo.atmosphereBottom],
            startPoint: .top, endPoint: .bottom
        )
        ink = theme.foreground
        sub = theme.mutedForeground
        glyph = atmo.glyph
        chipBackground = theme.muted
        chipForeground = theme.mutedForeground
        // Active dot follows each mode's hero accent: indigo on light, sand on dark.
        dotActive = dark ? theme.secondary : theme.primary
        dotInactive = theme.mutedForeground.opacity(0.5)
        // Pale light blobs need more presence; saturated dark blobs need less.
        let opacity = dark ? [0.55, 0.40, 0.45] : [0.85, 0.65, 0.55]
        blobs = [
            Blob(id: 0, color: atmo.blob1, size: 300, alignment: .topTrailing,    offset: CGSize(width: 70, height: -70),  opacity: opacity[0]),
            Blob(id: 1, color: atmo.blob2, size: 240, alignment: .leading,        offset: CGSize(width: -90, height: -40), opacity: opacity[1]),
            Blob(id: 2, color: atmo.blob3, size: 220, alignment: .bottomTrailing, offset: CGSize(width: 50, height: 50),   opacity: opacity[2]),
        ]
    }
}

// MARK: - Atmosphere

private struct OnboardingAtmosphere: View {
    let palette: OnboardingPalette

    var body: some View {
        ZStack {
            palette.pageGradient
            ForEach(palette.blobs) { blob in
                Circle()
                    .fill(blob.color)
                    .frame(width: blob.size, height: blob.size)
                    .blur(radius: 48)
                    .opacity(blob.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: blob.alignment)
                    .offset(blob.offset)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Marks

/// The EB app icon (the gradient mark) — rendered straight from the `EBIcon`
/// image asset, the same artwork as `AppIcon.icon`, rather than recomposing the
/// gradient + monogram in code. (iOS can't render an Icon Composer `.icon` as an
/// in-app `Image`, so the artwork is bundled as a vector imageset.)
struct EBAppIcon: View {
    var size: CGFloat = 96
    var float: Bool = false
    @State private var lifted = false

    var body: some View {
        Image("EBIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: 10)
            .offset(y: lifted ? -8 : 0)
            .onAppear {
                guard float else { return }
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    lifted = true
                }
            }
    }
}

/// Completion check — an iOS system-green disc with a white checkmark. Green is
/// the native "done" affordance (the design system's `--ok`), deliberately
/// distinct from the brand mint `success` (the "is a partner" card).
struct CompletionCheck: View {
    var size: CGFloat = 96
    @State private var shown = false

    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .green.opacity(0.33), radius: 12, x: 0, y: 4)
            .scaleEffect(shown ? 1 : 0.72)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { shown = true }
            }
    }
}

// MARK: - Controls

private struct ProgressDots: View {
    let index: Int
    let total: Int
    let active: Color
    let inactive: Color

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == index ? active : inactive)
                    .frame(width: i == index ? 22 : 7, height: 7)
            }
        }
        .animation(.snappy, value: index)
    }
}

private struct SettingsPathChip: View {
    let textKey: LocalizedStringKey
    let palette: OnboardingPalette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12))
            Text(textKey)
                .font(.system(size: 12.5, weight: .medium))
        }
        .foregroundStyle(palette.chipForeground)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(palette.chipBackground, in: .rect(cornerRadius: 14, style: .continuous))
    }
}

private struct OnboardingCTAButton: View {
    let titleKey: LocalizedStringKey
    var variant: Variant = .primary
    let palette: OnboardingPalette
    var showArrow: Bool = false
    var spinner: Bool = false
    var shimmer: Bool = false
    let action: () -> Void

    enum Variant { case primary, glass }

    @Environment(\.theme) private var theme
    @State private var shimmerX: CGFloat = -1.2

    init(_ titleKey: LocalizedStringKey, variant: Variant = .primary, palette: OnboardingPalette,
         showArrow: Bool = false, spinner: Bool = false, shimmer: Bool = false,
         action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.variant = variant
        self.palette = palette
        self.showArrow = showArrow
        self.spinner = spinner
        self.shimmer = shimmer
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if spinner {
                    ProgressView()
                        .controlSize(.small)
                        .tint(palette.isDark ? .white : theme.primary)
                }
                Text(titleKey)
                    .kerning(0.6)
                if showArrow {
                    Image(systemName: "arrow.right")
                }
            }
            .font(Theme.brandFont(15, .bold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .modifier(CTABackground(variant: variant, palette: palette, theme: theme, shimmerX: shimmerX, shimmer: shimmer))
        }
        .buttonStyle(.plain)
        .onAppear {
            guard shimmer else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: false)) {
                shimmerX = 1.4
            }
        }
    }
}

private struct CTABackground: ViewModifier {
    let variant: OnboardingCTAButton.Variant
    let palette: OnboardingPalette
    let theme: Theme
    let shimmerX: CGFloat
    let shimmer: Bool

    func body(content: Content) -> some View {
        switch variant {
        case .primary:
            content
                .foregroundStyle(theme.primaryForeground)
                .background(theme.primary)
                .overlay { if shimmer { shimmerSweep } }
                .clipShape(.capsule)
                .shadow(color: theme.primary.opacity(0.40), radius: 13, x: 0, y: 10)
        case .glass:
            content
                .foregroundStyle(palette.isDark ? .white : theme.primary)
                .glassEffect(.regular, in: .capsule)
        }
    }

    private var shimmerSweep: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(LinearGradient(colors: [.clear, .white.opacity(0.5), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: geo.size.width * 0.4)
                .offset(x: shimmerX * geo.size.width)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Helpers

private extension Text {
    func onboardingTitle(_ size: CGFloat, _ color: Color) -> some View {
        self.font(Theme.brandFont(size, .bold))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    func onboardingBody(_ color: Color) -> some View {
        self.font(Theme.brandFont(16))
            .foregroundStyle(color)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
