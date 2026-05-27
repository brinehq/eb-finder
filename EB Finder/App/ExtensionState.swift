import Foundation
import SafariServices
import os
#if canImport(AppKit)
import AppKit
#endif

private let extensionStateLogger = Logger(subsystem: "com.brine.ebfinder", category: "ExtensionState")

enum ExtensionStatus: Equatable {
    case unknown
    case enabled
    case disabled
    case error(String)
}

@MainActor
@Observable
final class ExtensionState {
    var status: ExtensionStatus = .unknown

    func refresh() async {
        extensionStateLogger.info("refresh() identifier=\(extensionBundleIdentifier, privacy: .public)")
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
            extensionStateLogger.info("refresh() got isEnabled=\(state.isEnabled)")
            status = state.isEnabled ? .enabled : .disabled
        } catch {
            let ns = error as NSError
            extensionStateLogger.error("refresh() failed: domain=\(ns.domain, privacy: .public) code=\(ns.code) message=\(error.localizedDescription, privacy: .public)")
            status = .error(error.localizedDescription)
        }
    }

    func openSafariExtensionPreferences() async {
        do {
            #if os(macOS)
            try await SFSafariApplication.showPreferencesForExtension(
                withIdentifier: extensionBundleIdentifier
            )
            #else
            extensionStateLogger.info("openExtensionsSettings forIdentifiers: \(extensionBundleIdentifier, privacy: .public)")
            try await SFSafariSettings.openExtensionsSettings(
                forIdentifiers: [extensionBundleIdentifier]
            )
            extensionStateLogger.info("openExtensionsSettings succeeded")
            #endif
        } catch {
            let ns = error as NSError
            extensionStateLogger.error("openSafariExtensionPreferences failed: domain=\(ns.domain, privacy: .public) code=\(ns.code) message=\(error.localizedDescription, privacy: .public)")
            status = .error(error.localizedDescription)
        }
    }

    func openDemoSearch(openURL: (URL) -> Void) {
        let query = "studio display"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://www.google.com/search?q=\(encoded)") else { return }
        #if os(macOS)
        if let safari = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: safari,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else {
            openURL(url)
        }
        #else
        openURL(url)
        #endif
    }
}
