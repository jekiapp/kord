import Foundation
import Combine

final class KordCoordinator: ChordEngineDelegate, EventTapDelegate {
    private let engine: ChordEngine
    private let eventTapManager: EventTapManager
    private let textInjector: TextInjector
    private let configManager: ConfigManager
    private let settings: AppSettings
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()

    init(
        engine: ChordEngine,
        eventTapManager: EventTapManager,
        textInjector: TextInjector,
        configManager: ConfigManager,
        settings: AppSettings,
        appState: AppState
    ) {
        self.engine = engine
        self.eventTapManager = eventTapManager
        self.textInjector = textInjector
        self.configManager = configManager
        self.settings = settings
        self.appState = appState
    }

    func setup() {
        engine.delegate = self
        engine.isCaretAtTextBoundary = {
            CaretContextReader.isAtTextBoundary()
        }
        eventTapManager.delegate = self

        _ = configManager.loadDictionary(from: settings.dictionaryPath)
        engine.updateDictionary(configManager.dictionary)
        configManager.startWatching(path: settings.dictionaryPath)

        configManager.onDictionaryReloaded = { [weak self] in
            guard let self = self else { return }
            self.engine.updateDictionary(self.configManager.dictionary)
        }

        appState.isAccessibilityGranted = EventTapManager.checkAccessibility()

        if settings.isEnabled && appState.isAccessibilityGranted {
            startEngine()
        }

        settings.$isEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if enabled {
                    self?.startEngine()
                } else {
                    self?.stopEngine()
                }
            }
            .store(in: &cancellables)

        settings.$timingWindowMs
            .dropFirst()
            .sink { [weak self] ms in
                self?.engine.updateTimingWindow(ms: ms)
            }
            .store(in: &cancellables)

        settings.$dictionaryPath
            .dropFirst()
            .sink { [weak self] path in
                guard let self = self else { return }
                self.configManager.stopWatching()
                _ = self.configManager.loadDictionary(from: path)
                self.engine.updateDictionary(self.configManager.dictionary)
                self.configManager.startWatching(path: path)
            }
            .store(in: &cancellables)

        settings.$dictionaryReloadToken
            .dropFirst()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let path = self.settings.dictionaryPath
                _ = self.configManager.loadDictionary(from: path)
                self.engine.updateDictionary(self.configManager.dictionary)
                self.configManager.startWatching(path: path)
            }
            .store(in: &cancellables)
    }

    private func startEngine() {
        guard appState.isAccessibilityGranted else {
            _ = EventTapManager.checkAccessibility()
            return
        }
        if eventTapManager.start() {
            appState.isEngineRunning = true
        }
    }

    private func stopEngine() {
        eventTapManager.stop()
        engine.reset()
        appState.isEngineRunning = false
    }

    // MARK: - EventTapDelegate

    func eventTapDidReceive(_ event: KeyEvent) -> Bool {
        guard settings.isEnabled else { return false }
        return engine.handleKeyEvent(event)
    }

    // MARK: - ChordEngineDelegate

    func chordEngine(_ engine: ChordEngine, didRecognizeChord expansion: String) {
        textInjector.inject(expansion + " ")
        DispatchQueue.main.async {
            self.appState.lastExpansion = expansion
        }
    }

    func chordEngineDidRequestDeleteWordBackward(_ engine: ChordEngine) {
        textInjector.deleteWordBackward()
    }

    func chordEngine(_ engine: ChordEngine, didFailWithKeys keys: [BufferedKey]) {
        textInjector.replayKeys(keys)
    }
}
