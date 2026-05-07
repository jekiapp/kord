import CoreGraphics
import Foundation

struct KeyEvent {
    enum EventType {
        case keyDown
        case keyUp
    }

    let keyCode: Int64
    let character: String?
    let type: EventType
    let timestamp: UInt64 // mach_absolute_time
    let flags: CGEventFlags
}

extension KeyEvent {
    var isModifierOnly: Bool {
        let modifierKeyCodes: Set<Int64> = [
            54, 55, // Cmd
            56, 60, // Shift
            58, 61, // Option
            59, 62, // Control
            63,     // Fn
        ]
        return modifierKeyCodes.contains(keyCode)
    }

    var hasCommandModifier: Bool {
        flags.contains(.maskCommand)
    }

    var hasControlModifier: Bool {
        flags.contains(.maskControl)
    }

    var hasOptionModifier: Bool {
        flags.contains(.maskAlternate)
    }

    var hasActiveModifiers: Bool {
        hasCommandModifier || hasControlModifier || hasOptionModifier
    }
}
