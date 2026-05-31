import SafariServices
#if os(macOS)
import AppKit
#endif

private let appGroupID = "group.com.brine.ebfinder"
let shoppingURL = URL(string: "https://onlineshopping.flysas.com/")!

private enum SharedDefaultsKey {
    static let permissionPingTimestamp = "permission.lastPingTimestamp"
    static let permissionHasAllUrls = "permission.hasAllUrls"
    static let permissionLastOrigin = "permission.lastOrigin"
}

enum ExtensionStatus: Equatable {
    case unknown
    case safariUnavailable
    case enabled
    case disabled
    case error(String)
}

enum HostPermission: Equatable {
    case unknown
    case allWebsites
    case someWebsites
}

@MainActor
@Observable
final class ExtensionState {
    var status: ExtensionStatus
    var hostPermission: HostPermission = .unknown

    init() {
        #if os(macOS)
        let safariInstalled = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.Safari"
        ) != nil
        status = safariInstalled ? .unknown : .safariUnavailable
        #else
        status = .unknown
        #endif
    }

    func refresh() async {
        guard status != .safariUnavailable else { return }
        // The macOS state check can be slow on first run (Safari scans
        // extensions) and the bridged call can't be cancelled, so apply its
        // result when it lands rather than blocking the UI on it…
        Task { @MainActor in
            let result = await self.checkExtensionState()
            self.status = result
            self.hostPermission = self.readHostPermission()
        }
        // …and if it hasn't landed shortly, drop the spinner for the
        // actionable enable step instead of hanging. The check corrects it.
        try? await Task.sleep(for: .seconds(2.5))
        if status == .unknown {
            status = .disabled
        }
    }

    private func checkExtensionState() async -> ExtensionStatus {
        do {
            let state = try await fetchExtensionState()
            return state.isEnabled ? .enabled : .disabled
        } catch {
            return Self.classify(error)
        }
    }

    /// On macOS, Safari failing to resolve the extension surfaces as a thrown
    /// `SFError` rather than `isEnabled == false`. Codes 1–4 (no extension /
    /// no attachment / loading interrupted / internal error) mean "not ready
    /// yet", so route them to the friendly enable step. Codes 5+ (e.g. missing
    /// entitlement) signal a real build/config bug and stay visible.
    private static func classify(_ error: Error) -> ExtensionStatus {
        let ns = error as NSError
        if ns.domain == "SFErrorDomain", (1...4).contains(ns.code) {
            return .disabled
        }
        return .error(error.localizedDescription)
    }

    func openSafariExtensionPreferences() async {
        guard status != .safariUnavailable else { return }
        do {
            try await openExtensionPreferences()
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func openShopping(openURL: (URL) -> Void) {
        openInSafari(shoppingURL, fallback: openURL)
    }

    private func fetchExtensionState() async throws -> SFSafariExtensionState {
        #if os(macOS)
        try await SFSafariExtensionManager.stateOfSafariExtension(
            withIdentifier: extensionBundleIdentifier
        )
        #else
        try await SFSafariExtensionManager.stateOfExtension(
            withIdentifier: extensionBundleIdentifier
        )
        #endif
    }

    private func openExtensionPreferences() async throws {
        #if os(macOS)
        try await SFSafariApplication.showPreferencesForExtension(
            withIdentifier: extensionBundleIdentifier
        )
        #else
        try await SFSafariSettings.openExtensionsSettings(
            forIdentifiers: [extensionBundleIdentifier]
        )
        #endif
    }

    private func openInSafari(_ url: URL, fallback: (URL) -> Void) {
        #if os(macOS)
        if let safari = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: safari,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else {
            fallback(url)
        }
        #else
        fallback(url)
        #endif
    }

    private func readHostPermission() -> HostPermission {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            defaults.object(forKey: SharedDefaultsKey.permissionPingTimestamp) != nil
        else { return .unknown }
        return defaults.bool(forKey: SharedDefaultsKey.permissionHasAllUrls)
            ? .allWebsites
            : .someWebsites
    }
}
