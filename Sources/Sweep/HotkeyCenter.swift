import Carbon.HIToolbox
import SweepCore

/// Registers the keyboard hotkeys (super modifier + direction keys / center key) with Carbon, so the
/// key press goes to Sweep and not to the front app. Needs no Accessibility permission.
@MainActor
final class HotkeyCenter {
    /// Called with the key code of a pressed hotkey.
    var onKey: ((UInt16) -> Void)?
    private var refs: [EventHotKeyRef] = []
    private var handlerInstalled = false
    private static let signature: OSType = 0x5357_5045   // four-char code for Sweep
    nonisolated(unsafe) private static weak var current: HotkeyCenter?

    func update(settings: SweepSettings) {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs = []
        // Never register bare keys: without a super modifier the hotkeys would take plain arrows.
        let modifiers = Self.carbonModifiers(settings.superModifier)
        let codes = HotkeyMap.activeKeyCodes(settings: settings)   // keyboard snapping and/or undo
        guard !codes.isEmpty, settings.gesturesEnabled, modifiers != 0 else { return }
        installHandler()
        for code in codes {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(code))
            if RegisterEventHotKey(UInt32(code), modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr,
               let ref {
                refs.append(ref)
            }
        }
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        Self.current = self
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            let err = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                        nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard err == noErr, id.signature == HotkeyCenter.signature else { return OSStatus(eventNotHandledErr) }
            let code = UInt16(id.id)
            // Carbon delivers hotkey events on the main thread.
            MainActor.assumeIsolated { HotkeyCenter.current?.onKey?(code) }
            return noErr
        }, 1, &type, nil, nil)
        handlerInstalled = status == noErr
    }

    private static func carbonModifiers(_ keys: ModifierKeys) -> UInt32 {
        var m: UInt32 = 0
        if keys.contains(.command) { m |= UInt32(cmdKey) }
        if keys.contains(.option) { m |= UInt32(optionKey) }
        if keys.contains(.control) { m |= UInt32(controlKey) }
        if keys.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }
}
