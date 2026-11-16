import CoreGraphics
import Foundation
import SweepCore

/// Posts key chords as normal keyboard input (the same as the user pressing the keys).
enum KeyPoster {
    static func post(_ chord: KeyChord) {
        let source = CGEventSource(stateID: .hidSystemState)
        var flags: CGEventFlags = []
        if chord.modifiers.contains(.command) { flags.insert(.maskCommand) }
        if chord.modifiers.contains(.shift) { flags.insert(.maskShift) }
        if chord.modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if chord.modifiers.contains(.control) { flags.insert(.maskControl) }
        if chord.modifiers.contains(.function) { flags.insert(.maskSecondaryFn) }
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: chord.keyCode, keyDown: down)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }
}

extension KeyPoster {
    /// Press or release ⌘ alone (the app switcher stays open while ⌘ is down).
    static func command(down: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: down)
        event?.flags = down ? .maskCommand : []
        event?.post(tap: .cghidEventTap)
    }
}

/// Runs a `SpaceMovePlan` with synthetic mouse and key events.
@MainActor
enum SpaceMover {
    /// Marks events we post, so our own input tap ignores them.
    nonisolated static let syntheticTag: Int64 = 0x5357_4550
    static func run(_ steps: ArraySlice<SpaceMovePlan.Step>) {
        guard let step = steps.first else { return }
        let rest = steps.dropFirst()
        let source = CGEventSource(stateID: .hidSystemState)
        func mouse(_ type: CGEventType, _ p: CGPoint) {
            let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: p, mouseButton: .left)
            event?.setIntegerValueField(.eventSourceUserData, value: syntheticTag)
            event?.post(tap: .cghidEventTap)
        }
        switch step {
        case .mouseDown(let p): mouse(.leftMouseDown, p)
        case .drag(let p): mouse(.leftMouseDragged, p)
        case .mouseUp(let p): mouse(.leftMouseUp, p)
        case .key(let chord): KeyPoster.post(chord)
        case .warp(let p): CGWarpMouseCursorPosition(p)
        case .wait(let seconds):
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                MainActor.assumeIsolated { run(rest) }
            }
            return
        }
        run(rest)
    }
}
