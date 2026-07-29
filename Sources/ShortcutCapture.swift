import AppKit
import ApplicationServices
import Foundation

final class ShortcutCapture {
    var onShortcut: ((ShortcutBinding) -> Void)?
    var onCancel: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var raycastHyperHeld = false

    var isActive: Bool { eventTap != nil }

    @discardableResult
    func start() -> Bool {
        stop()
        raycastHyperHeld = false
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let capture = Unmanaged<ShortcutCapture>.fromOpaque(context).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let eventTap = capture.eventTap {
                        CGEvent.tapEnable(tap: eventTap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                guard capture.isActive else { return Unmanaged.passUnretained(event) }

                if type == .keyDown {
                    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                    if keyCode == 53 {
                        DispatchQueue.main.async { capture.cancel() }
                    } else if keyCode == 90 {
                        // Raycast's Hyper Key exposes Caps Lock as synthetic
                        // F20. Wait for the following key instead of saving
                        // F20 as the shortcut.
                        capture.raycastHyperHeld = true
                    } else {
                        let hyperModifiers: UInt64 =
                            (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20)
                        let shortcut = ShortcutBinding(
                            keyCode: keyCode,
                            modifiers: capture.raycastHyperHeld
                                ? hyperModifiers
                                : event.flags.rawValue
                        )
                        DispatchQueue.main.async {
                            capture.onShortcut?(shortcut)
                            capture.stop()
                        }
                    }
                }

                // While recording, swallow both halves of the shortcut so
                // Raycast and other global-hotkey apps never receive it.
                return nil
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func cancel() {
        stop()
        onCancel?()
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        raycastHyperHeld = false
    }

    deinit {
        stop()
    }
}
