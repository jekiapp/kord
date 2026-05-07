import ApplicationServices
import Foundation

enum CaretContextReader {
    static func isAtTextBoundary() -> Bool? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success, let focusedValue else {
            return nil
        }

        let focusedElement = focusedValue as! AXUIElement
        guard let selectedRange = selectedTextRange(in: focusedElement) else {
            return nil
        }

        if selectedRange.location <= 0 {
            return true
        }

        guard let previousCharacter = characterBeforeCaret(
            in: focusedElement,
            caretLocation: selectedRange.location
        ) else {
            return nil
        }

        return previousCharacter.unicodeScalars.allSatisfy { scalar in
            CharacterSet.whitespacesAndNewlines.contains(scalar)
        }
    }

    private static func selectedTextRange(in element: AXUIElement) -> CFRange? {
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        ) == .success,
            let rangeValue,
            CFGetTypeID(rangeValue) == AXValueGetTypeID()
        else {
            return nil
        }

        let axValue = rangeValue as! AXValue
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            return nil
        }
        return range
    }

    private static func characterBeforeCaret(
        in element: AXUIElement,
        caretLocation: CFIndex
    ) -> String? {
        if let character = parameterizedCharacterBeforeCaret(
            in: element,
            caretLocation: caretLocation
        ) {
            return character
        }
        return valueCharacterBeforeCaret(in: element, caretLocation: caretLocation)
    }

    private static func parameterizedCharacterBeforeCaret(
        in element: AXUIElement,
        caretLocation: CFIndex
    ) -> String? {
        var previousRange = CFRange(location: caretLocation - 1, length: 1)
        guard let rangeValue = AXValueCreate(.cfRange, &previousRange) else {
            return nil
        }

        var characterValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &characterValue
        ) == .success else {
            return nil
        }

        return characterValue as? String
    }

    private static func valueCharacterBeforeCaret(
        in element: AXUIElement,
        caretLocation: CFIndex
    ) -> String? {
        var textValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &textValue
        ) == .success, let text = textValue as? String else {
            return nil
        }

        let previousOffset = caretLocation - 1
        guard previousOffset >= 0, previousOffset < text.utf16.count else {
            return nil
        }

        let start = String.Index(utf16Offset: previousOffset, in: text)
        let end = String.Index(utf16Offset: caretLocation, in: text)
        return String(text[start..<end])
    }
}
