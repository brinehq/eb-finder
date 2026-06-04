import SwiftUI

// SwiftCN-style button, vendored locally. shadcn variants + size ramp mapped onto
// the design tokens. The visual engine is a `ButtonStyle` (the idiomatic SwiftUI
// way to style buttons — it gets press state and `isEnabled` for free); `SButton`
// is the ergonomic wrapper so call sites read like the rest of SwiftCN.
//
// Shape is a capsule to match the app's CTA language (onboarding + guided test).

struct SButton: View {
    enum Variant { case primary, secondary, outline, ghost, destructive }
    enum Size { case sm, md, lg }

    private let title: LocalizedStringKey
    private let systemImage: String?
    private let variant: Variant
    private let size: Size
    private let fullWidth: Bool
    private let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        variant: Variant = .primary,
        size: Size = .md,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.size = size
        self.fullWidth = fullWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(SButtonStyle(variant: variant, size: size, fullWidth: fullWidth))
    }
}

// MARK: - Style

private struct SButtonStyle: ButtonStyle {
    let variant: SButton.Variant
    let size: SButton.Size
    let fullWidth: Bool

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .semibold))
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: size.minHeight)
            .padding(.horizontal, size.horizontalPadding)
            .foregroundStyle(variant.foreground)
            .background(variant.background)
            .clipShape(.capsule)
            .overlay {
                if variant == .outline {
                    Capsule().strokeBorder(Theme.Colors.border, lineWidth: 1)
                }
            }
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Variant → tokens

private extension SButton.Variant {
    var foreground: Color {
        switch self {
        case .primary:     Theme.Colors.primaryForeground
        case .secondary:   Theme.Colors.secondaryForeground
        case .destructive: Theme.Colors.destructiveForeground
        case .outline, .ghost: Theme.Colors.foreground
        }
    }

    var background: Color {
        switch self {
        case .primary:     Theme.Colors.primary
        case .secondary:   Theme.Colors.secondary
        case .destructive: Theme.Colors.destructive
        case .outline, .ghost: .clear
        }
    }
}

// MARK: - Size → metrics

private extension SButton.Size {
    var fontSize: CGFloat {
        switch self {
        case .sm: 14
        case .md: 15
        case .lg: 16
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .sm: 36
        case .md: 44
        case .lg: 52
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .sm: Theme.Spacing.md
        case .md: Theme.Spacing.lg
        case .lg: Theme.Spacing.xl
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        SButton("Primary", systemImage: "magnifyingglass", action: {})
        SButton("Secondary", variant: .secondary, action: {})
        SButton("Outline", variant: .outline, action: {})
        SButton("Destructive", variant: .destructive, size: .sm, action: {})
        SButton("Full width", variant: .primary, size: .lg, fullWidth: true, action: {})
        SButton("Disabled", action: {}).disabled(true)
    }
    .padding()
}
