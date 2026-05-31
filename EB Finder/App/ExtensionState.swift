import SafariServices
#if os(macOS)
import AppKit
#endif

enum ExtensionStatus: Equatable {
    case unknown
    case enabled
    case disabled
    case safariUnavailable
    case error(String)
}

@MainActor
@Observable
final class ExtensionState {
    var status: ExtensionStatus

    #if os(macOS)
    private let safariApplicationURL: URL?
    #endif

    init() {
        #if os(macOS)
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari")
        safariApplicationURL = url
        status = url == nil ? .safariUnavailable : .unknown
        #else
        status = .unknown
        #endif
    }

    func refresh() async {
        guard status != .safariUnavailable else { return }
        do {
            #if os(macOS)
            let state = try await SFSafariExtensionManager.stateOfSafariExtension(
                withIdentifier: extensionBundleIdentifier
            )
            #else
            let state = try await SFSafariExtensionManager.stateOfExtension(
                withIdentifier: extensionBundleIdentifier
            )
            #endif
            status = state.isEnabled ? .enabled : .disabled
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func openSafariExtensionPreferences() async {
        guard status != .safariUnavailable else { return }
        do {
            #if os(macOS)
            try await SFSafariApplication.showPreferencesForExtension(
                withIdentifier: extensionBundleIdentifier
            )
            #else
            try await SFSafariSettings.openExtensionsSettings(
                forIdentifiers: [extensionBundleIdentifier]
            )
            #endif
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func openDemoSearch(openURL: (URL) -> Void) {
        let query = "studio display"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://www.google.com/search?q=\(encoded)") else { return }
        #if os(macOS)
        guard let safari = safariApplicationURL else { return }
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: safari,
            configuration: NSWorkspace.OpenConfiguration()
        )
        #else
        openURL(url)
        #endif
    }
}
