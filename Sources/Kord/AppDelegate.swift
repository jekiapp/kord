import AppKit
import SwiftUI

final class AppState: ObservableObject {
    @Published var isAccessibilityGranted = false
    @Published var isEngineRunning = false
    @Published var lastChord: String = ""
    @Published var lastExpansion: String = ""
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appSettings = AppSettings.shared
    let appState = AppState()

    private var dictionary: ChordDictionary!
    private var engine: ChordEngine!
    private var eventTapManager: EventTapManager!
    private var textInjector: TextInjector!
    private var configManager: ConfigManager!
    private var coordinator: KordCoordinator!

    func applicationDidFinishLaunching(_ notification: Notification) {
        dictionary = ChordDictionary()
        engine = ChordEngine(dictionary: dictionary)
        eventTapManager = EventTapManager()
        textInjector = TextInjector()
        configManager = ConfigManager(dictionary: dictionary)

        coordinator = KordCoordinator(
            engine: engine,
            eventTapManager: eventTapManager,
            textInjector: textInjector,
            configManager: configManager,
            settings: appSettings,
            appState: appState
        )

        coordinator.setup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventTapManager.stop()
        configManager.stopWatching()
    }
}
