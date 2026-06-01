import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var extensionState = ExtensionState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                SettingsView(state: extensionState)
            } else {
                OnboardingView(state: extensionState) {
                    withAnimation(.snappy) { hasCompletedOnboarding = true }
                }
            }
        }
        .task { await extensionState.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await extensionState.refresh() }
            }
        }
    }
}

#Preview {
    ContentView()
}
