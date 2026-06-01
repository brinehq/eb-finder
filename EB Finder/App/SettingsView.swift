import SwiftUI
import UIKit

// Post-onboarding home — a standard iOS inset-grouped settings list. Native
// surfaces and tint; plain SF Symbol leading icons (no colored tiles). Row
// titles are primary (only the footer link and the system back/links take the
// blue tint). Root → Om (About) → Licens (License). A warning marker appears on
// Extension Settings when the extension is off or lacks all-sites access.

struct SettingsView: View {
    let state: ExtensionState
    @Environment(\.openURL) private var openURL
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await state.openSafariExtensionPreferences() }
                    } label: {
                        SettingsRow(symbol: "puzzlepiece.extension.fill", title: "settings.extension",
                                    detail: extensionStatusText.map { Text($0) },
                                    warning: extensionNeedsAttention, trailing: .chevron)
                    }
                    .buttonStyle(.plain)

                    Button {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    } label: {
                        SettingsRow(symbol: "globe", title: "settings.language",
                                    detail: Text(verbatim: currentLanguage), trailing: .chevron)
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    Button {
                        openURL(URL(string: "mailto:support@brine.co")!)
                    } label: {
                        SettingsRow(symbol: "envelope.fill", title: "settings.contact",
                                    detail: Text(verbatim: "support@brine.co"), trailing: .external)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AboutView()
                    } label: {
                        SettingsRow(symbol: "info.circle.fill", title: "settings.about")
                    }
                }

                // Reset onboarding — broken out into its own card.
                Section {
                    Button {
                        withAnimation(.snappy) { hasCompletedOnboarding = false }
                    } label: {
                        SettingsRow(symbol: "arrow.counterclockwise", title: "settings.resetOnboarding")
                    }
                    .buttonStyle(.plain)
                } footer: {
                    BrineCredit()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(.blue)
    }

    /// The extension is installed but not fully usable: switched off, errored,
    /// or enabled without all-websites access. `.unknown` (still loading) stays
    /// quiet so we never flash a false warning on launch.
    private var extensionNeedsAttention: Bool {
        switch state.status {
        case .disabled, .error: return true
        case .enabled: return state.hostPermission == .someWebsites
        case .unknown: return false
        }
    }

    /// On / Off value shown on the Extension row (nil while still loading).
    private var extensionStatusText: LocalizedStringKey? {
        switch state.status {
        case .enabled: return "settings.extension.on"
        case .disabled, .error: return "settings.extension.off"
        case .unknown: return nil
        }
    }

    /// The app's active display language, shown on the Language row.
    private var currentLanguage: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        let name = Locale.current.localizedString(forLanguageCode: code) ?? code
        return name.capitalized(with: .current)
    }
}

// MARK: - About

private struct AboutView: View {
    @Environment(\.openURL) private var openURL

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                SettingsRow(title: "about.version", detail: Text(verbatim: appVersion))
            }

            Section {
                Button {
                    openURL(URL(string: "https://github.com/brinehq/eb-finder")!)
                } label: {
                    SettingsRow(title: "about.source", trailing: .external)
                }
                .buttonStyle(.plain)
                NavigationLink {
                    LicenseView()
                } label: {
                    SettingsRow(title: "about.license", detail: Text(verbatim: "MIT"))
                }
            }

            Section {
                Text("about.disclaimer.body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                Text("about.disclaimer.header")
            } footer: {
                BrineCredit()
            }
        }
        .navigationTitle("about.title")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - License

private struct LicenseView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section("license.header") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("license.body.copyright")
                    Text("license.body.grant")
                    Text("license.body.warranty")
                        .foregroundStyle(.tertiary)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 2)
            }

            Section {
                Button {
                    openURL(URL(string: "https://github.com/brinehq/eb-finder/blob/main/LICENSE")!)
                } label: {
                    SettingsRow(title: "license.full", trailing: .external)
                }
                .buttonStyle(.plain)
            } footer: {
                BrineCredit()
            }
        }
        .navigationTitle("license.title")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Building blocks

private struct SettingsRow: View {
    var symbol: String? = nil
    let title: LocalizedStringKey
    var detail: Text? = nil
    var warning: Bool = false
    var trailing: Trailing = .none

    enum Trailing { case none, chevron, external }

    var body: some View {
        HStack(spacing: 12) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .center)
            }
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let detail {
                detail.foregroundStyle(.secondary)
            }
            if warning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .accessibilityLabel(Text("settings.extension.warning"))
            }
            trailingIcon
        }
    }

    @ViewBuilder
    private var trailingIcon: some View {
        switch trailing {
        case .none:
            EmptyView()
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        case .external:
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

/// "Skapat av Brine AB" — centered at the foot of every settings page. The
/// localized value carries a markdown link, so "Brine AB" picks up the blue tint.
private struct BrineCredit: View {
    var body: some View {
        Text("settings.credit")
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 10)
    }
}
