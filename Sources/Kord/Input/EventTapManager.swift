import ApplicationServices
import CoreGraphics
import Foundation

protocol EventTapDelegate: AnyObject {
    /// Return true if the event was consumed (should be suppressed).
    func eventTapDidReceive(_ event: KeyEvent) -> Bool
}

final class EventTapManager {
    weak var delegate: EventTapDelegate?
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRunning = false

    static func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func start() -> Bool {
        guard eventTap == nil else { return true }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        return true
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        runLoopSource = nil
        eventTap = nil
        isRunning = false
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = manager.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown || type == .keyUp else {
        return Unmanaged.passUnretained(event)
    }

    if TextInjector.isOwnEvent(event) {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let character = characterForEvent(event)
    let eventType: KeyEvent.EventType = (type == .keyDown) ? .keyDown : .keyUp

    let keyEvent = KeyEvent(
        keyCode: keyCode,
        character: character,
        type: eventType,
        timestamp: mach_absolute_time(),
        flags: event.flags
    )

    if let delegate = manager.delegate, delegate.eventTapDidReceive(keyEvent) {
        return nil // suppress
    }

    return Unmanaged.passUnretained(event)
}

private func characterForEvent(_ event: CGEvent) -> String? {
    var length = 0
    var chars = [UniChar](repeating: 0, count: 4)
    event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
    guard length > 0 else { return nil }
    return String(utf16CodeUnits: chars, count: length)
}
