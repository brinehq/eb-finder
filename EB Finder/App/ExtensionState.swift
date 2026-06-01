import SafariServices

private let appGroupID = "group.com.brine.ebfinder"

private enum SharedDefaultsKey {
    static let permissionPingTimestamp = "permission.lastPingTimestamp"
    static let permissionHasAllUrls = "permission.hasAllUrls"
    static let permissionLastOrigin = "permission.lastOrigin"
}

enum ExtensionStatus: Equatable {
    case unknown
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
    var status: ExtensionStatus = .unknown
    var hostPermission: HostPermission = .unknown

    /// True while a `refresh()` is in flight. Drives the onboarding's "checking…"
    /// state so each re-verification (notably on app reopen) reads as a live
    /// re-check rather than a silent state swap.
    private(set) var isChecking = false

    func refresh() async {
        isChecking = true
        // The permission ping is a cheap synchronous read — pick it up immediately.
        hostPermission = readHostPermission()

        // The state check bridges into Safari and can't be cancelled, so apply
        // its result when it lands rather than blocking the UI on it…
        Task { @MainActor in
            let result = await self.checkExtensionState()
            self.status = result
            self.hostPermission = self.readHostPermission()
            self.isChecking = false
        }
        // …and if it hasn't landed shortly, stop the spinner and fall back to the
        // actionable enable step instead of hanging. A late result still corrects it.
        try? await Task.sleep(for: .seconds(2.5))
        if isChecking {
            isChecking = false
            if status == .unknown { status = .disabled }
        }
    }

    private func checkExtensionState() async -> ExtensionStatus {
        do {
            let state = try await SFSafariExtensionManager.stateOfExtension(
                withIdentifier: extensionBundleIdentifier
            )
            return state.isEnabled ? .enabled : .disabled
        } catch {
            return Self.classify(error)
        }
    }

    /// Safari failing to resolve the extension surfaces as a thrown `SFError`
    /// rather than `isEnabled == false`. Codes 1–4 (no extension / no
    /// attachment / loading interrupted / internal error) mean "not ready
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
        do {
            try await SFSafariSettings.openExtensionsSettings(
                forIdentifiers: [extensionBundleIdentifier]
            )
        } catch {
            status = .error(error.localizedDescription)
        }
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
