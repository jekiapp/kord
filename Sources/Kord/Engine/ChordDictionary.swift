import Foundation
import Yams

final class ChordDictionary {
    private var entries: [String: String] = [:]
    private var shortcuts: [String: String] = [:]
    private(set) var timingWindowMs: Int = 70

    var isEmpty: Bool { entries.isEmpty }

    func lookup(_ chord: Set<String>) -> String? {
        let signature = normalizedSignature(chord)
        return entries[signature]
    }

    /// Finds the longest dictionary shortcut that matches the trailing typed characters (in order).
    func lookupTrailing(in characters: [Character]) -> (expansion: String, shortcutLength: Int)? {
        var best: (expansion: String, shortcutLength: Int)?

        for (signature, expansion) in entries {
            guard let shortcut = shortcuts[signature] else { continue }
            let shortcutChars = Array(shortcut)
            guard characters.count >= shortcutChars.count else { continue }
            let suffix = Array(characters.suffix(shortcutChars.count))
            guard String(suffix.sorted()) == signature else { continue }
            if shortcutChars.count > (best?.shortcutLength ?? 0) {
                best = (expansion, shortcutChars.count)
            }
        }

        return best
    }

    func normalizedSignature(_ chord: Set<String>) -> String {
        chord.sorted().joined()
    }

    /// Returns the set of all individual characters that appear in any chord entry.
    func allChordCharacters() -> Set<Character> {
        var chars = Set<Character>()
        for key in entries.keys {
            for c in key {
                chars.insert(c)
            }
        }
        return chars
    }

    func load(from url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        try loadFromString(content)
    }

    func loadFromString(_ dictionaryContent: String) throws {
        guard let yaml = try Yams.load(yaml: dictionaryContent) as? [String: Any] else {
            throw DictionaryError.invalidFormat
        }

        if let timing = yaml["timing_window_ms"] as? Int {
            timingWindowMs = max(30, min(150, timing))
        }

        guard let words = yaml["words"] else {
            throw DictionaryError.missingWords
        }

        var newEntries: [String: String] = [:]
        var newShortcuts: [String: String] = [:]
        if let mappedWords = words as? [String: String] {
            // JSON format maps expansion -> shortcut.
            for (word, rawShortcut) in mappedWords {
                guard rawShortcut != "-" else { continue }
                let shortcut = rawShortcut.lowercased()
                let normalized = String(shortcut.sorted())
                // Keep the first entry when signatures conflict.
                if newEntries[normalized] == nil {
                    newEntries[normalized] = word
                    newShortcuts[normalized] = shortcut
                }
            }
        } else if let listedWords = words as? [[String: Any]] {
            for item in listedWords {
                guard
                    let rawShortcut = item["shortcut"] as? String,
                    let word = item["word"] as? String
                else {
                    throw DictionaryError.invalidFormat
                }
                guard rawShortcut != "-" else { continue }
                let shortcut = rawShortcut.lowercased()
                let normalized = String(shortcut.sorted())
                // Preserve higher-order dictionary entries (earlier in file).
                if newEntries[normalized] == nil {
                    newEntries[normalized] = word
                    newShortcuts[normalized] = shortcut
                }
            }
        } else {
            throw DictionaryError.invalidFormat
        }
        entries = newEntries
        shortcuts = newShortcuts
    }

    enum DictionaryError: Error, LocalizedError {
        case invalidFormat
        case missingWords

        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "Dictionary file has invalid format"
            case .missingWords: return "Dictionary file missing 'words' section"
            }
        }
    }
}
