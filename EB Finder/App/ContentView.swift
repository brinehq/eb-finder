import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var extensionState = ExtensionState()

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            BrandIcon()
                .frame(width: 128, height: 128)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(verbatim: "EB Finder")
                    .font(.largeTitle.weight(.semibold))
                Text("app.tagline")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            StatusCard(state: extensionState)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await extensionState.refresh() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await extensionState.refresh() }
            }
        }
    }
}

private struct BrandIcon: View {
    private static let baseColor = Color(.displayP3, red: 0.00007, green: 0, blue: 0.57520)

    var body: some View {
        LinearGradient(
            colors: [Self.baseColor, Self.baseColor.opacity(0.85)],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay {
            Image("EB")
                .resizable()
                .scaledToFit()
                .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}

private struct StatusCard: View {
    let state: ExtensionState
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            instructionsView

            if case .enabled = state.status {
                tryItOutButton
            } else {
                openSettingsButton
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background.secondary)
        )
        .frame(maxWidth: 380)
    }

    @ViewBuilder
    private var instructionsView: some View {
        switch state.status {
        case .unknown:
            instructionRow(
                icon: "questionmark.circle",
                tint: .secondary,
                title: "status.checking.title",
                detail: "status.checking.detail"
            )
        case .enabled:
            instructionRow(
                icon: "checkmark.seal.fill",
                tint: .green,
                title: "status.enabled.title",
                detail: "status.enabled.detail"
            )
        case .disabled:
            instructionRow(
                icon: "exclamationmark.triangle.fill",
                tint: .orange,
                title: "status.disabled.title",
                detail: "status.disabled.detail"
            )
        case .error(let message):
            errorRow(message: message)
        }
    }

    private var openSettingsButton: some View {
        Button {
            Task { await state.openSafariExtensionPreferences() }
        } label: {
            Label("status.openSettings.button", systemImage: "safari")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
    }

    private var tryItOutButton: some View {
        Button {
            state.openDemoSearch { openURL($0) }
        } label: {
            Label("status.tryItOut.button", systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
    }

    private func instructionRow(
        icon: String,
        tint: Color,
        title: LocalizedStringKey,
        detail: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func errorRow(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "xmark.octagon.fill")
                .font(.title3)
                .foregroundStyle(.red)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("status.error.title").font(.headline)
                Text(verbatim: message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    ContentView()
}
