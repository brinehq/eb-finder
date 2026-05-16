import SwiftUI

struct ContentView: View {
    @State private var extensionState = ExtensionState()

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            Image("LargeIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
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
        .background {
            #if os(macOS)
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            #else
            Color(uiColor: .systemBackground).ignoresSafeArea()
            #endif
        }
        .task { await extensionState.refresh() }
    }
}

private struct StatusCard: View {
    let state: ExtensionState

    var body: some View {
        VStack(spacing: 16) {
            instructionsView

            #if os(macOS)
            Button {
                state.openSafariExtensionPreferences()
            } label: {
                Label("status.openSettings.button", systemImage: "safari")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            #endif
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
            #if os(macOS)
            instructionRow(
                icon: "questionmark.circle",
                tint: .secondary,
                title: "status.checking.title",
                detail: "status.checking.detail"
            )
            #else
            VStack(alignment: .leading, spacing: 12) {
                instructionRow(
                    icon: "1.circle.fill",
                    tint: .accentColor,
                    title: "ios.step1.title",
                    detail: "ios.step1.detail"
                )
                instructionRow(
                    icon: "2.circle.fill",
                    tint: .accentColor,
                    title: "ios.step2.title",
                    detail: "ios.step2.detail"
                )
                instructionRow(
                    icon: "3.circle.fill",
                    tint: .accentColor,
                    title: "ios.step3.title",
                    detail: "ios.step3.detail"
                )
            }
            #endif
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
