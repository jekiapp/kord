import CoreGraphics
import Foundation

protocol ChordEngineDelegate: AnyObject {
    func chordEngine(_ engine: ChordEngine, didRecognizeChord expansion: String)
    func chordEngine(_ engine: ChordEngine, didFailWithKeys keys: [BufferedKey])
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

    private(set) var state: State = .idle
    private var timingWindowMs: Int = 70
    private var heldKeys: Set<String> = []
    private var bufferedKeys: [BufferedKey] = []
    private var dictionary: ChordDictionary
    private var windowTimer: DispatchWorkItem?
    private var chordableChars: Set<Character> = []
    private var isAtWordBoundary = true

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
    }

    // MARK: - Private

    private func handleKeyDown(_ event: KeyEvent) -> Bool {
        let char = event.character?.lowercased().first

        switch state {
        case .idle:
            guard isAtWordBoundary, let c = char, chordableChars.contains(c) else {
                updateWordBoundary(with: char)
                return false
            }
            state = .collecting
            isAtWordBoundary = false
            addKey(event)
            startWindow()
            return true

        case .collecting:
            addKey(event)
            return true
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

        guard heldKeys.count > 1, let expansion = dictionary.lookup(heldKeys) else {
            cancelGesture()
            return
        }

        state = .idle
        let keys = heldKeys
        heldKeys.removeAll()
        bufferedKeys.removeAll()
        // Expansions are injected with trailing space by the coordinator.
        isAtWordBoundary = true
        delegate?.chordEngine(self, didRecognizeChord: expansion)
    }

    private func cancelGesture() {
        let keys = bufferedKeys
        if let lastChar = keys.last?.character?.lowercased().first {
            updateWordBoundary(with: lastChar)
        }
        reset()
        if !keys.isEmpty {
            delegate?.chordEngine(self, didFailWithKeys: keys)
        }
    }

    private func rebuildChordableChars() {
        chordableChars = dictionary.allChordCharacters()
    }

    private func updateWordBoundary(with char: Character?) {
        guard let char else { return }
        isAtWordBoundary = char.unicodeScalars.allSatisfy { scalar in
            CharacterSet.whitespacesAndNewlines.contains(scalar)
        }
    }
}
