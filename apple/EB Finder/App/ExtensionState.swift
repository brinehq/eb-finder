import Foundation
import SafariServices

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
        #if os(macOS)
        do {
            let state = try await SFSafariExtensionManager.stateOfSafariExtension(
                withIdentifier: extensionBundleIdentifier
            )
            status = state.isEnabled ? .enabled : .disabled
        } catch {
            status = .error(error.localizedDescription)
        }
        #else
        status = .unknown
        #endif
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
        #endif
    }
}
