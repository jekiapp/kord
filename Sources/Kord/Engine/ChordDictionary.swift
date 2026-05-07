import Foundation
import Yams

final class ChordDictionary {
    private var entries: [String: String] = [:]
    private(set) var timingWindowMs: Int = 70

    var isEmpty: Bool { entries.isEmpty }

    func lookup(_ chord: Set<String>) -> String? {
        let signature = normalizedSignature(chord)
        return entries[signature]
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

    func loadFromString(_ yamlString: String) throws {
        guard let yaml = try Yams.load(yaml: yamlString) as? [String: Any] else {
            throw DictionaryError.invalidFormat
        }

        if let timing = yaml["timing_window_ms"] as? Int {
            timingWindowMs = max(30, min(150, timing))
        }

        guard let words = yaml["words"] as? [String: String] else {
            throw DictionaryError.missingWords
        }

        var newEntries: [String: String] = [:]
        for (key, value) in words {
            let normalized = String(key.sorted())
            newEntries[normalized] = value
        }
        entries = newEntries
    }

    enum DictionaryError: Error, LocalizedError {
        case invalidFormat
        case missingWords

        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "Dictionary YAML has invalid format"
            case .missingWords: return "Dictionary YAML missing 'words' section"
            }
        }
    }
}
