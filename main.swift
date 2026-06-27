import Foundation
import CoreGraphics
import ApplicationServices

let version: [String] = "0.1.7"

final class ClipSpinState {
    let items: [String]
    var index: Int = 0
    var lastTriggerAt: TimeInterval = 0
    var suppressNextVKeyUp: Bool = false
    let repeatGuardSeconds: TimeInterval = 0.25

    init(items: [String]) {
        self.items = items
    }

    var currentLabel: String {
        return "\(index + 1)/\(items.count)"
    }

    func nextText() -> String {
        let text = items[index]
        index = (index + 1) % items.count
        return text
    }

    func typeNext() {
        let now = Date().timeIntervalSince1970

        if now - lastTriggerAt < repeatGuardSeconds {
            return
        }

        lastTriggerAt = now

        let label = currentLabel
        let text = nextText()

        typeUnicode(text)

        print("Typed: \(label)")
        fflush(stdout)
    }

    private func typeUnicode(_ text: String) {
        if text.isEmpty {
            return
        }

        var utf16 = Array(text.utf16)

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            fputs("Could not create CGEventSource.\n", stderr)
            return
        }

        guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
            fputs("Could not create CGEvent.\n", stderr)
            return
        }

        event.keyboardSetUnicodeString(
            stringLength: utf16.count,
            unicodeString: &utf16
        )

        event.post(tap: .cghidEventTap)
    }
}

let virtualKeyV: Int64 = 9
var state: ClipSpinState?
var eventTap: CFMachPort?

func parseInput() -> [String] {
    let args = CommandLine.arguments.dropFirst()

    guard let raw = args.first else {
        fputs("Usage: clipspin '[\"Erster Text\", \"Zweiter Text\", \"Dritter Text\"]'\n", stderr)
        exit(1)
    }

    let input: String

    if raw.hasSuffix(".json") {
        do {
            input = try String(contentsOfFile: raw, encoding: .utf8)
        } catch {
            fputs("Could not read file: \(raw)\n", stderr)
            exit(1)
        }
    } else {
        input = raw
    }

    guard let data = input.data(using: .utf8) else {
        fputs("Invalid UTF-8 input.\n", stderr)
        exit(1)
    }

    do {
        let decoded = try JSONDecoder().decode([String].self, from: data)

        if decoded.isEmpty {
            fputs("JSON array must not be empty.\n", stderr)
            exit(1)
        }

        return decoded
    } catch {
        fputs("Invalid JSON. Expected: [\"Text 1\", \"Text 2\", \"Text 3\"]\n", stderr)
        exit(1)
    }
}

func requestAccessibilityIfNeeded() {
    let options = [
        kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
    ] as CFDictionary

    let trusted = AXIsProcessTrustedWithOptions(options)

    if !trusted {
        print("Accessibility permission is required.")
        print("Open System Settings -> Privacy & Security -> Accessibility.")
        print("Allow your terminal app or the clipspin binary, then restart ClipSpin.")
        print("")
    }
}

func isOptionV(_ event: CGEvent) -> Bool {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    let hasOption = flags.contains(.maskAlternate)
    let hasCommand = flags.contains(.maskCommand)
    let hasControl = flags.contains(.maskControl)

    return keyCode == virtualKeyV
        && hasOption
        && !hasCommand
        && !hasControl
}

let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }

        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown || type == .keyUp else {
        return Unmanaged.passUnretained(event)
    }

    guard let state = state else {
        return Unmanaged.passUnretained(event)
    }

    if type == .keyDown && isOptionV(event) {
        state.suppressNextVKeyUp = true

        DispatchQueue.main.async {
            state.typeNext()
        }

        // Block original Option+V, so macOS does not insert √.
        return nil
    }

    if type == .keyUp && state.suppressNextVKeyUp {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if keyCode == virtualKeyV {
            state.suppressNextVKeyUp = false

            // Block the matching keyUp as well.
            return nil
        }
    }

    return Unmanaged.passUnretained(event)
}

let items = parseInput()
state = ClipSpinState(items: items)

requestAccessibilityIfNeeded()

let eventMask =
    (1 << CGEventType.keyDown.rawValue) |
    (1 << CGEventType.keyUp.rawValue) |
    (1 << CGEventType.flagsChanged.rawValue)

eventTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: callback,
    userInfo: nil
)

guard let eventTap = eventTap else {
    fputs("Could not create CGEventTap.\n", stderr)
    fputs("Check Accessibility and Input Monitoring permissions.\n", stderr)
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(
    kCFAllocatorDefault,
    eventTap,
    0
)

CFRunLoopAddSource(
    CFRunLoopGetCurrent(),
    runLoopSource,
    .commonModes
)

CGEvent.tapEnable(tap: eventTap, enable: true)

print("ClipSpin v\(version) active.")
print("Loaded \(items.count) items.")
print("Press Option+V to type/cycle.")
print("Press Ctrl+C to stop.")
print("")

signal(SIGINT) { _ in
    print("\nClipSpin stopped.")
    exit(0)
}

CFRunLoopRun()