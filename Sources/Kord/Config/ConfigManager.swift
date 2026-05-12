import Foundation

final class ConfigManager {
    let dictionary: ChordDictionary
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var watchedFD: Int32 = -1
    private var debouncedReload: DispatchWorkItem?
    private var watchedDictionaryPath: String = ""

    var onDictionaryReloaded: (() -> Void)?

    init(dictionary: ChordDictionary) {
        self.dictionary = dictionary
    }

    func loadDictionary(from path: String) -> Bool {
        let resolved = Self.resolvedPath(path)
        let url: URL
        if FileManager.default.fileExists(atPath: resolved) {
            url = URL(fileURLWithPath: resolved)
        } else {
            ensureDefaultDictionary(at: resolved)
            url = URL(fileURLWithPath: resolved)
        }

        do {
            try dictionary.load(from: url)
            return true
        } catch {
            print("[Kord] Failed to load dictionary at '\(resolved)': \(error.localizedDescription)")
            return false
        }
    }

    func startWatching(path: String) {
        stopWatching()

        let resolved = Self.resolvedPath(path)
        watchedDictionaryPath = resolved

        let dir = (resolved as NSString).deletingLastPathComponent
        guard !dir.isEmpty else {
            print("[Kord] Cannot watch dictionary path (no parent directory): '\(path)'")
            return
        }

        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        watchedFD = open(dir, O_EVTONLY)
        guard watchedFD >= 0 else {
            print("[Kord] Failed to watch dictionary directory '\(dir)' (errno \(errno))")
            watchedDictionaryPath = ""
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: watchedFD,
            eventMask: [.write, .rename, .extend, .attrib],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.scheduleDebouncedDictionaryReload()
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
        debouncedReload?.cancel()
        debouncedReload = nil
        watchedDictionaryPath = ""
        fileWatcher?.cancel()
        fileWatcher = nil
    }

    private func scheduleDebouncedDictionaryReload() {
        debouncedReload?.cancel()
        let path = watchedDictionaryPath
        guard !path.isEmpty else { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            _ = self.loadDictionary(from: path)
            self.onDictionaryReloaded?()
        }
        debouncedReload = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(150), execute: work)
    }

    private func ensureDefaultDictionary(at path: String) {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let projectRootURL = sourceFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let defaultDictionaryURL = projectRootURL.appendingPathComponent("default-dictionary.json")

        guard FileManager.default.fileExists(atPath: defaultDictionaryURL.path) else {
            return
        }

        try? FileManager.default.copyItem(at: defaultDictionaryURL, to: URL(fileURLWithPath: path))
    }

    private static func resolvedPath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        return (expanded as NSString).standardizingPath
    }

    deinit {
        stopWatching()
    }
}
