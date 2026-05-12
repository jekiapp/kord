import Foundation

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published var timingWindowMs: Int {
        didSet { defaults.set(timingWindowMs, forKey: Keys.timingWindowMs) }
    }

    @Published var dictionaryPath: String {
        didSet { defaults.set(dictionaryPath, forKey: Keys.dictionaryPath) }
    }

    /// Incremented from the preferences UI so `KordCoordinator` can reload the on-disk dictionary into the engine without changing `dictionaryPath`.
    @Published private(set) var dictionaryReloadToken: UInt64 = 0

    func requestEngineDictionaryReloadFromDisk() {
        dictionaryReloadToken &+= 1
    }

    private init() {
        let defaultPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/kord/dictionary.json")
            .path

        defaults.register(defaults: [
            Keys.isEnabled: true,
            Keys.timingWindowMs: 70,
            Keys.dictionaryPath: defaultPath,
        ])

        isEnabled = defaults.bool(forKey: Keys.isEnabled)
        timingWindowMs = defaults.integer(forKey: Keys.timingWindowMs)
        dictionaryPath = defaults.string(forKey: Keys.dictionaryPath) ?? defaultPath
    }

    private enum Keys {
        static let isEnabled = "kord.enabled"
        static let timingWindowMs = "kord.timingWindowMs"
        static let dictionaryPath = "kord.dictionaryPath"
    }
}
