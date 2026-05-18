import CoreGraphics
import Foundation
import Carbon.HIToolbox

final class TextInjector {
    static let selfSourcedMarker: Int64 = 0x4B4F5244 // "KORD" in hex

    private let source: CGEventSource?

    init() {
        source = CGEventSource(stateID: .privateState)
    }

    static func isOwnEvent(_ event: CGEvent) -> Bool {
        return event.getIntegerValueField(.eventSourceUserData) == selfSourcedMarker
    }

    func inject(_ text: String) {
        for scalar in text.unicodeScalars {
            let char = UniChar(scalar.value)
            postCharacter(char)
        }
    }

    func deleteBackward(count: Int) {
        guard count > 0 else { return }
        for _ in 0 ..< count {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: false)
            markAsOwn(keyDown)
            markAsOwn(keyUp)
            keyDown?.post(tap: .cgSessionEventTap)
            keyUp?.post(tap: .cgSessionEventTap)
        }
    }

    private func postCharacter(_ char: UniChar) {
        var char = char
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

        keyDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
        keyUp?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)

        markAsOwn(keyDown)
        markAsOwn(keyUp)

        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }

    private func markAsOwn(_ event: CGEvent?) {
        event?.setIntegerValueField(.eventSourceUserData, value: Self.selfSourcedMarker)
    }
}
