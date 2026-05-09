import CoreGraphics
import Foundation

protocol ChordEngineDelegate: AnyObject {
    func chordEngine(_ engine: ChordEngine, didRecognizeChord expansion: String)
    func chordEngineDidRequestDeleteWordBackward(_ engine: ChordEngine)
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
    var isCaretAtTextBoundary: (() -> Bool?)?

    private(set) var state: State = .idle
    private var timingWindowMs: Int = 70
    private var heldKeys: Set<String> = []
    private var bufferedKeys: [BufferedKey] = []
    private var dictionary: ChordDictionary
    private var windowTimer: DispatchWorkItem?
    private var chordableChars: Set<Character> = []

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
        let char = normalizedCharacter(from: event)

        switch state {
        case .idle:
            guard isValidGestureStarter(event: event, character: char) else {
                return false
            }
            state = .collecting
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

        if isDeleteWordBackwardChord() {
            state = .idle
            heldKeys.removeAll()
            bufferedKeys.removeAll()
            delegate?.chordEngineDidRequestDeleteWordBackward(self)
            return
        }

        let lookupKeys = heldKeys.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard heldKeys.count >= 3, lookupKeys.count >= 2, let expansion = dictionary.lookup(lookupKeys) else {
            cancelGesture()
            return
        }

        state = .idle
        heldKeys.removeAll()
        bufferedKeys.removeAll()
        // Expansions are injected with trailing space by the coordinator.
        delegate?.chordEngine(self, didRecognizeChord: expansion)
    }

    private func cancelGesture() {
        let keys = bufferedKeys
        reset()
        if !keys.isEmpty {
            delegate?.chordEngine(self, didFailWithKeys: keys)
        }
    }

    private func rebuildChordableChars() {
        chordableChars = dictionary.allChordCharacters()
    }

    private func isDeleteWordBackwardChord() -> Bool {
        let hasEqual = heldKeys.contains("=")
        let hasBackspace = bufferedKeys.contains(where: { $0.keyCode == backspaceKeyCode })
        return hasEqual && hasBackspace
    }

    private func isValidGestureStarter(event: KeyEvent, character: Character?) -> Bool {
        if event.keyCode == backspaceKeyCode {
            return true
        }

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
