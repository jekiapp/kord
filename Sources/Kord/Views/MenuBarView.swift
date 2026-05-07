import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack {
            Toggle("Enabled", isOn: $settings.isEnabled)

            Divider()

            if !appState.isAccessibilityGranted {
                Button("Grant Accessibility Access...") {
                    _ = EventTapManager.checkAccessibility()
                }
            } else {
                Text(appState.isEngineRunning ? "Engine: Running" : "Engine: Stopped")
                    .font(.caption)
            }

            if !appState.lastExpansion.isEmpty {
                Text("Last: \(appState.lastExpansion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            SettingsLink {
                Text("Preferences...")
            }

            Divider()

            Button("Quit Kord") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
