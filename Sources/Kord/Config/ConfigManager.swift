import Foundation

final class ConfigManager {
    let dictionary: ChordDictionary
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var watchedFD: Int32 = -1

    var onDictionaryReloaded: (() -> Void)?

    init(dictionary: ChordDictionary) {
        self.dictionary = dictionary
    }

    func loadDictionary(from path: String) -> Bool {
        let url: URL
        if FileManager.default.fileExists(atPath: path) {
            url = URL(fileURLWithPath: path)
        } else {
            ensureDefaultDictionary(at: path)
            url = URL(fileURLWithPath: path)
        }

        do {
            try dictionary.load(from: url)
            return true
        } catch {
            print("[Kord] Failed to load dictionary: \(error.localizedDescription)")
            return false
        }
    }

    func startWatching(path: String) {
        stopWatching()

        watchedFD = open(path, O_EVTONLY)
        guard watchedFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: watchedFD,
            eventMask: [.write, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            _ = self.loadDictionary(from: path)
            self.onDictionaryReloaded?()
        }

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.watchedFD >= 0 {
                close(self.watchedFD)
                self.watchedFD = -1
            }
        }

        source.resume()
        fileWatcher = source
    }

    func stopWatching() {
        fileWatcher?.cancel()
        fileWatcher = nil
    }

    private func ensureDefaultDictionary(at path: String) {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        guard let bundledURL = Bundle.module.url(forResource: "default_dictionary", withExtension: "yaml") else {
            return
        }

        try? FileManager.default.copyItem(at: bundledURL, to: URL(fileURLWithPath: path))
    }

    deinit {
        stopWatching()
    }
}
