import CoreGraphics
import Foundation

protocol ChordEngineDelegate: AnyObject {
    func chordEngine(_ engine: ChordEngine, didRecognizeChord expansion: String, replacingKeyCount: Int)
}

struct BufferedKey {
    let keyCode: Int64
    let character: String?
    let flags: CGEventFlags
}

final class ChordEngine {
    enum State {
        case idle
        case collecting
    }

    weak var delegate: ChordEngineDelegate?
    var isCaretAtTextBoundary: (() -> Bool?)?

    private(set) var state: State = .idle
    private var timingWindowMs: Int = 70
    private var heldKeys: Set<String> = []
    private var bufferedKeys: [BufferedKey] = []
    private var dictionary: ChordDictionary
    private var windowTimer: DispatchWorkItem?
    private var chordableChars: Set<Character> = []
    private let debugChordMatching = true

    /// Rolling buffer of characters observed before the caret (oldest first).
    private static let precedingContextCapacity = 32
    private var precedingContext: [Character] = []
    /// Snapshot of `precedingContext` when the current gesture started.
    private var gesturePrecedingContext: [Character] = []

    init(dictionary: ChordDictionary) {
        self.dictionary = dictionary
        updateTimingWindow(ms: dictionary.timingWindowMs)
        rebuildChordableChars()
    }

    func updateDictionary(_ dictionary: ChordDictionary) {
        self.dictionary = dictionary
        updateTimingWindow(ms: dictionary.timingWindowMs)
        rebuildChordableChars()
    }

    func updateTimingWindow(ms: Int) {
        timingWindowMs = max(30, min(150, ms))
    }

    /// Returns true if the key event was consumed (suppressed).
    func handleKeyEvent(_ event: KeyEvent) -> Bool {
        if event.isModifierOnly || event.hasActiveModifiers {
            if state != .idle {
                cancelGesture()
            }
            // Modifier shortcuts (paste, undo, navigation, etc.) can change
            // the surrounding text in ways we can't track, so we forget the
            // preceding-character context to avoid wrong suffix merges.
            if event.hasActiveModifiers {
                precedingContext.removeAll()
            }
            return false
        }

        guard event.type == .keyDown else {
            return false
        }

        return handleKeyDown(event)
    }

    func reset() {
        windowTimer?.cancel()
        windowTimer = nil
        state = .idle
        heldKeys.removeAll()
        bufferedKeys.removeAll()
        gesturePrecedingContext.removeAll()
    }

    // MARK: - Private

    private func handleKeyDown(_ event: KeyEvent) -> Bool {
        let char = normalizedCharacter(from: event)

        if event.keyCode == backspaceKeyCode {
            // Backspace is never part of chord detection.
            if state != .idle {
                debugLog("backspace pressed while collecting; reset gesture")
                reset()
            }
            if !precedingContext.isEmpty {
                precedingContext.removeLast()
            }
            return false
        }

        switch state {
        case .idle:
            guard isValidGestureStarter(event: event, character: char) else {
                if let c = char { appendToPrecedingContext(c) }
                debugLog("ignore keyDown; invalid starter keyCode=\(event.keyCode) char=\(char.map(String.init) ?? "nil") raw=\(event.character ?? "nil")")
                return false
            }
            gesturePrecedingContext = precedingContext
            state = .collecting
            addKey(event)
            startWindow()
            debugLog("start gesture; keyCode=\(event.keyCode) char=\(char.map(String.init) ?? "nil") preceding=\(String(gesturePrecedingContext)) buffer=\(bufferDebugDescription())")
            return false

        case .collecting:
            addKey(event)
            debugLog("collect key; keyCode=\(event.keyCode) char=\(char.map(String.init) ?? "nil") buffer=\(bufferDebugDescription())")
            return false
        }
    }

    private func addKey(_ event: KeyEvent) {
        if let char = event.character {
            heldKeys.insert(char.lowercased())
        }
        bufferedKeys.append(BufferedKey(
            keyCode: event.keyCode,
            character: event.character,
            flags: event.flags
        ))
    }

    private func startWindow() {
        let item = DispatchWorkItem { [weak self] in
            self?.commitGesture()
        }
        windowTimer = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(timingWindowMs),
            execute: item
        )
    }

    private func commitGesture() {
        windowTimer = nil

        let typedCharacters = bufferedKeys.compactMap { normalizedCharacter(from: $0) }
            .filter { !$0.isWhitespace }
        if typedCharacters.count < 3 {
            debugLog("reject gesture; typedCharacters.count=\(typedCharacters.count) (<3), typed=\(String(typedCharacters)), buffer=\(bufferDebugDescription())")
            cancelGesture()
            return
        }

        guard let match = dictionary.lookupTrailing(in: typedCharacters) else {
            debugLog("reject gesture; no trailing dictionary match, typed=\(String(typedCharacters)), buffer=\(bufferDebugDescription())")
            cancelGesture()
            return
        }

        guard match.shortcutLength >= 2 else {
            debugLog("reject gesture; matched shortcut too short (\(match.shortcutLength)), typed=\(String(typedCharacters))")
            cancelGesture()
            return
        }

        let baseKeyCount = trailingBufferedKeyCount(forCharacterCount: match.shortcutLength)
        var replacingKeyCount = baseKeyCount
        let isSuffixExpansion = match.expansion.hasPrefix("-")
        var expansion = match.expansion
        if isSuffixExpansion {
            replacingKeyCount += precedingWhitespaceDeleteCount(forChordKeyCount: baseKeyCount)
            let precedingWord = precedingWord(beforeChordKeyCount: baseKeyCount)
            let suffixRules = applySuffixRules(
                expansion: expansion,
                precedingWord: precedingWord
            )
            replacingKeyCount += suffixRules.extraDeleteCount
            if let overridden = suffixRules.expansion {
                expansion = "-" + overridden
            }
        }

        debugLog("match gesture; typed=\(String(typedCharacters)) shortcutLength=\(match.shortcutLength) replacingKeyCount=\(replacingKeyCount) expansion=\(expansion) preceding=\(String(gesturePrecedingContext))")
        let injectedText = isSuffixExpansion ? String(expansion.dropFirst()) : expansion + " "
        rebuildPrecedingContextAfterCommit(deletedCount: replacingKeyCount, injectedText: injectedText)

        state = .idle
        heldKeys.removeAll()
        bufferedKeys.removeAll()
        gesturePrecedingContext.removeAll()

        // Expansions are injected with trailing space by the coordinator.
        delegate?.chordEngine(self, didRecognizeChord: expansion, replacingKeyCount: replacingKeyCount)
    }

    private func cancelGesture() {
        let bufferChars = bufferedKeys.compactMap { normalizedCharacter(from: $0) }
        let snapshot = gesturePrecedingContext
        reset()
        precedingContext = Array(
            (snapshot + bufferChars).suffix(Self.precedingContextCapacity)
        )
    }

    /// Counts how many extra keys must be deleted before the chord characters
    /// in order to merge a suffix expansion onto the previous word. Looks at
    /// the buffer first (fast typing) and falls back to the pre-gesture
    /// snapshot (chord typed after a pause).
    private func precedingWhitespaceDeleteCount(forChordKeyCount chordKeyCount: Int) -> Int {
        var index = bufferedKeys.count - chordKeyCount - 1
        var count = 0
        while index >= 0 {
            guard
                let char = normalizedCharacter(from: bufferedKeys[index]),
                char.isWhitespace
            else {
                break
            }
            count += 1
            index -= 1
        }

        if index < 0,
           gesturePrecedingContext.last?.isWhitespace == true {
            count += 1
        }

        return count
    }

    private struct SuffixRuleResult {
        var extraDeleteCount: Int = 0
        var expansion: String?
    }

    /// Applies morphological rules for suffix chords (expansions prefixed with `-`).
    private func applySuffixRules(expansion: String, precedingWord: String) -> SuffixRuleResult {
        guard expansion.hasPrefix("-") else { return SuffixRuleResult() }
        let suffix = String(expansion.dropFirst())

        // Silent-e drop: make + ing -> making
        if suffix == "ing",
           shouldDropSilentE(from: precedingWord) {
            return SuffixRuleResult(extraDeleteCount: 1, expansion: nil)
        }

        return SuffixRuleResult()
    }

    private func shouldDropSilentE(from word: String) -> Bool {
        guard word.count >= 2, word.last == "e" else { return false }
        let stemIndex = word.index(word.endIndex, offsetBy: -2)
        let stemChar = word[stemIndex]
        return !isVowel(stemChar)
    }

    private func isVowel(_ character: Character) -> Bool {
        "aeiou".contains(character)
    }

    /// Characters of the word immediately before the matched chord shortcut.
    private func precedingWord(beforeChordKeyCount chordKeyCount: Int) -> String {
        var word: [Character] = []

        var index = bufferedKeys.count - chordKeyCount - 1
        while index >= 0 {
            guard let char = normalizedCharacter(from: bufferedKeys[index]) else {
                index -= 1
                continue
            }
            if char.isWhitespace { break }
            word.insert(char, at: 0)
            index -= 1
        }

        var snapshot = gesturePrecedingContext
        while snapshot.last?.isWhitespace == true {
            snapshot.removeLast()
        }
        var snapshotWord: [Character] = []
        for char in snapshot.reversed() {
            if char.isWhitespace { break }
            snapshotWord.insert(char, at: 0)
        }

        return String(snapshotWord + word)
    }

    private func appendToPrecedingContext(_ character: Character) {
        precedingContext.append(character)
        if precedingContext.count > Self.precedingContextCapacity {
            precedingContext.removeFirst(precedingContext.count - Self.precedingContextCapacity)
        }
    }

    private func rebuildPrecedingContextAfterCommit(deletedCount: Int, injectedText: String) {
        let bufferChars = bufferedKeys.compactMap { normalizedCharacter(from: $0) }
        var combined = gesturePrecedingContext + bufferChars
        if deletedCount > 0, deletedCount <= combined.count {
            combined.removeLast(deletedCount)
        }
        combined.append(contentsOf: injectedText)
        precedingContext = Array(combined.suffix(Self.precedingContextCapacity))
    }

    private func bufferDebugDescription() -> String {
        let parts = bufferedKeys.map { key -> String in
            let normalized = normalizedCharacter(from: key).map(String.init) ?? "nil"
            let raw = key.character ?? "nil"
            return "{k:\(key.keyCode),n:\(normalized),r:\(raw)}"
        }
        return "[" + parts.joined(separator: ",") + "]"
    }

    private func debugLog(_ message: String) {
        guard debugChordMatching else { return }
        print("[KordChord] \(message)")
    }

    private func trailingBufferedKeyCount(forCharacterCount characterCount: Int) -> Int {
        var remaining = characterCount
        var keyCount = 0
        for key in bufferedKeys.reversed() {
            if remaining == 0 { break }
            if let char = normalizedCharacter(from: key), !char.isWhitespace {
                remaining -= 1
            }
            keyCount += 1
        }
        return keyCount
    }

    private func rebuildChordableChars() {
        chordableChars = dictionary.allChordCharacters()
    }

    private func isValidGestureStarter(event: KeyEvent, character: Character?) -> Bool {
        guard let c = character else {
            return false
        }

        return chordableChars.contains(c) || c == " " || c == "="
    }

    private func normalizedCharacter(from event: KeyEvent) -> Character? {
        if let char = event.character?.lowercased().first {
            return char
        }
        if boundaryKeyCodes.contains(event.keyCode) {
            return " "
        }
        return nil
    }

    private func normalizedCharacter(from key: BufferedKey) -> Character? {
        if let char = key.character?.lowercased().first {
            return char
        }
        if boundaryKeyCodes.contains(key.keyCode) {
            return " "
        }
        return nil
    }

    private var boundaryKeyCodes: Set<Int64> {
        [36, 48, 49, 76] // Return, Tab, Space, Keypad Enter
    }

    private var backspaceKeyCode: Int64 {
        51
    }
}
