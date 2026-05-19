import SwiftUI

let extensionBundleIdentifier = "com.brine.ebfinder.extension"

@main
struct EBFinderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            #if os(macOS)
                .frame(minWidth: 420, idealWidth: 480, minHeight: 520, idealHeight: 600)
            #endif
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}
