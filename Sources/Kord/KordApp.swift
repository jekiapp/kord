import SwiftUI

@main
struct KordApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Kord", systemImage: "keyboard") {
            MenuBarView()
                .environmentObject(appDelegate.appSettings)
                .environmentObject(appDelegate.appState)
        }
        .menuBarExtraStyle(.menu)

        SwiftUI.Settings {
            PreferencesView()
                .environmentObject(appDelegate.appSettings)
                .environmentObject(appDelegate.appState)
        }
    }
}
