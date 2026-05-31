import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var extensionState = ExtensionState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainView(state: extensionState)
            } else {
                OnboardingFlow(state: extensionState) {
                    withAnimation(.snappy) { hasCompletedOnboarding = true }
                }
            }
        }
        .task { await extensionState.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await extensionState.refresh() }
            }
        }
    }
}

private enum OnboardingStep: Hashable {
    case loading
    case safariMissing
    case enableExtension
    case grantPermissions
    case ready
}

private struct OnboardingFlow: View {
    let state: ExtensionState
    let onComplete: () -> Void
    @State private var permissionStepSkipped = false

    private var currentStep: OnboardingStep {
        switch state.status {
        case .unknown:
            return .loading
        case .safariUnavailable:
            return .safariMissing
        case .disabled, .error:
            return .enableExtension
        case .enabled:
            switch state.hostPermission {
            case .allWebsites:
                return .ready
            case .someWebsites, .unknown:
                return permissionStepSkipped ? .ready : .grantPermissions
            }
        }
    }

    private var errorMessage: String? {
        if case .error(let message) = state.status { return message }
        return nil
    }

    var body: some View {
        ZStack {
            Color.accentColor.ignoresSafeArea()

            stepView
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
        .foregroundStyle(.white)
        .animation(.snappy, value: currentStep)
    }

    @ViewBuilder
    private var stepView: some View {
        switch currentStep {
        case .loading:
            LoadingStep()
        case .safariMissing:
            OnboardingStepView(
                icon: "exclamationmark.triangle.fill",
                title: "onboarding.safariMissing.title",
                detail: "onboarding.safariMissing.detail"
            )
        case .enableExtension:
            OnboardingStepView(
                icon: "puzzlepiece.extension.fill",
                title: "onboarding.enable.title",
                detail: "onboarding.enable.detail",
                ctaLabel: "onboarding.enable.button",
                action: { Task { await state.openSafariExtensionPreferences() } },
                errorMessage: errorMessage
            )
        case .grantPermissions:
            OnboardingStepView(
                icon: "lock.shield.fill",
                title: "onboarding.permissions.title",
                detail: platformPermissionsDetail,
                ctaLabel: "onboarding.permissions.button",
                action: { Task { await state.openSafariExtensionPreferences() } },
                secondaryLabel: "onboarding.permissions.secondary",
                secondaryAction: { permissionStepSkipped = true }
            )
        case .ready:
            OnboardingStepView(
                icon: "checkmark.seal.fill",
                title: "onboarding.ready.title",
                detail: "onboarding.ready.detail",
                ctaLabel: "onboarding.ready.button",
                action: onComplete
            )
        }
    }

    private var platformPermissionsDetail: LocalizedStringKey {
        #if os(macOS)
        "onboarding.permissions.detail.macos"
        #else
        "onboarding.permissions.detail.ios"
        #endif
    }
}

private struct LoadingStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image("EB")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
            ProgressView()
                .tint(.white)
        }
    }
}

private struct OnboardingStepView: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var ctaLabel: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil
    var errorMessage: String? = nil
    var secondaryLabel: LocalizedStringKey? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 0)

            Image(systemName: icon)
                .font(.system(size: 72, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(detail)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .opacity(0.92)
            }
            .padding(.horizontal, 32)

            if let errorMessage {
                Text(verbatim: errorMessage)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer(minLength: 0)

            VStack(spacing: 14) {
                if let ctaLabel, let action {
                    Button(action: action) {
                        Text(ctaLabel)
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.white, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
                if let secondaryLabel, let secondaryAction {
                    Button(secondaryLabel, action: secondaryAction)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 540)
    }
}

private struct MainView: View {
    let state: ExtensionState
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                if let warning = warningKey {
                    Section {
                        Button {
                            Task { await state.openSafariExtensionPreferences() }
                        } label: {
                            Label(warning, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    Button {
                        state.openShopping { openURL($0) }
                    } label: {
                        Label("main.shop", systemImage: "bag.fill")
                    }
                }

                Section {
                    NavigationLink {
                        PlaceholderView(title: "main.about")
                    } label: {
                        Label("main.about", systemImage: "info.circle")
                    }
                    Button {
                        Task { await state.openSafariExtensionPreferences() }
                    } label: {
                        Label("main.extensionSettings", systemImage: "puzzlepiece.extension")
                    }
                    NavigationLink {
                        PlaceholderView(title: "main.language")
                    } label: {
                        Label("main.language", systemImage: "globe")
                    }
                }
            }
            .navigationTitle(Text(verbatim: "EB Finder"))
        }
    }

    private var warningKey: LocalizedStringKey? {
        switch state.status {
        case .disabled:
            return "main.warning.disabled"
        case .enabled where state.hostPermission == .someWebsites:
            return "main.warning.permissions"
        default:
            return nil
        }
    }
}

private struct PlaceholderView: View {
    let title: LocalizedStringKey

    var body: some View {
        ContentUnavailableView(
            "placeholder.title",
            systemImage: "hammer.fill",
            description: Text("placeholder.detail")
        )
        .navigationTitle(title)
    }
}

#Preview {
    ContentView()
}
