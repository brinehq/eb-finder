import SwiftUI

let extensionBundleIdentifier = "com.brine.ebfinder.extension"

@main
struct EBFinderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 520, height: 760)
        #endif
    }
}
