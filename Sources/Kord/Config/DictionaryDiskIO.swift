import Foundation
import Yams

enum DictionaryDiskIO {
    struct Loaded {
        var timingWindowMs: Int
        var entries: [(word: String, shortcut: String)]
    }

    enum DiskError: Error, LocalizedError {
        case unreadable
        case missingWords
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .unreadable: return "Could not read dictionary file"
            case .missingWords: return "Dictionary file is missing a \"words\" section"
            case .writeFailed(let message): return message
            }
        }
    }

    static func load(path: String) throws -> Loaded {
        let resolved = ((path as NSString).expandingTildeInPath as NSString).standardizingPath
        guard FileManager.default.fileExists(atPath: resolved) else {
            return Loaded(timingWindowMs: 70, entries: [])
        }

        let content = try String(contentsOfFile: resolved, encoding: .utf8)
        guard let root = try Yams.load(yaml: content) as? [String: Any] else {
            throw DiskError.unreadable
        }

        let rawTiming = root["timing_window_ms"] as? Int ?? 70
        let timingWindowMs = max(30, min(150, rawTiming))

        guard let words = root["words"] else {
            throw DiskError.missingWords
        }

        var pairs: [(String, String)] = []
        if let mapped = words as? [String: String] {
            pairs = mapped.compactMap { word, shortcut in
                shortcut == "-" ? nil : (word, shortcut)
            }
        } else if let listed = words as? [[String: Any]] {
            for item in listed {
                guard
                    let rawShortcut = item["shortcut"] as? String,
                    let word = item["word"] as? String,
                    rawShortcut != "-"
                else {
                    continue
                }
                pairs.append((word, rawShortcut))
            }
        } else {
            throw DiskError.unreadable
        }

        pairs.sort { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
        return Loaded(timingWindowMs: timingWindowMs, entries: pairs)
    }

    static func save(path: String, timingWindowMs: Int, rows: [(word: String, shortcut: String)]) throws {
        let resolved = ((path as NSString).expandingTildeInPath as NSString).standardizingPath
        var words: [String: String] = [:]
        for row in rows {
            let word = row.word.trimmingCharacters(in: .whitespacesAndNewlines)
            let shortcut = row.shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty, !shortcut.isEmpty else { continue }
            words[word] = shortcut
        }

        let timing = max(30, min(150, timingWindowMs))
        let payload: [String: Any] = [
            "timing_window_ms": timing,
            "words": words,
        ]

        guard JSONSerialization.isValidJSONObject(payload) else {
            throw DiskError.writeFailed("Invalid dictionary data")
        }

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        let url = URL(fileURLWithPath: resolved)

        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw DiskError.writeFailed(error.localizedDescription)
        }
    }
}
