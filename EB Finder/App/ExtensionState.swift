import Foundation
import SafariServices
import os.log

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

    func openSafariExtensionPreferences() {
        #if os(macOS)
        SFSafariApplication.showPreferencesForExtension(
            withIdentifier: extensionBundleIdentifier
        ) { error in
            if let error {
                Task { @MainActor in
                    self.status = .error(error.localizedDescription)
                }
            }
        }
        #else
        extensionStateLogger.info("openExtensionsSettings forIdentifiers: \(extensionBundleIdentifier, privacy: .public)")
        SFSafariSettings.openExtensionsSettings(
            forIdentifiers: [extensionBundleIdentifier]
        ) { error in
            if let error {
                let ns = error as NSError
                extensionStateLogger.error("openExtensionsSettings FAILED: domain=\(ns.domain, privacy: .public) code=\(ns.code) message=\(error.localizedDescription, privacy: .public)")
                Task { @MainActor in
                    self.status = .error(error.localizedDescription)
                }
            } else {
                extensionStateLogger.info("openExtensionsSettings SUCCEEDED (completion fired, no error)")
            }
        }
        #endif
    }
}
