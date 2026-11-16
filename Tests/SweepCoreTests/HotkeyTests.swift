import Testing
@testable import SweepCore

/// Super modifier + direction keys snap the focused window; a center key centers it.
@Suite struct HotkeyTests {
    @Test(arguments: [(UInt16(123), Direction.left), (124, .right), (125, .down), (126, .up)])
    func arrows(code: UInt16, direction: Direction) {
        #expect(HotkeyMap.direction(keyCode: code, keys: .arrows) == direction)
    }

    @Test(arguments: [(UInt16(13), Direction.up), (0, .left), (1, .down), (2, .right)])
    func wasd(code: UInt16, direction: Direction) {
        #expect(HotkeyMap.direction(keyCode: code, keys: .wasd) == direction)
    }

    @Test(arguments: [(UInt16(43), Direction.up), (0, .left), (41, .down), (4, .right)])
    func dvorak(code: UInt16, direction: Direction) {
        #expect(HotkeyMap.direction(keyCode: code, keys: .dvorak) == direction)
    }

    @Test func otherKeysAreNotDirections() {
        #expect(HotkeyMap.direction(keyCode: 13, keys: .arrows) == nil)
        #expect(HotkeyMap.direction(keyCode: 123, keys: .wasd) == nil)
        #expect(HotkeyMap.direction(keyCode: 37, keys: .wasd) == nil)
    }

    @Test(arguments: [(SweepSettings.CenterKey.escape, UInt16(53)), (.backspace, 51), (.returnKey, 36)])
    func centerKey(key: SweepSettings.CenterKey, code: UInt16) {
        #expect(HotkeyMap.keyCode(for: key) == code)
    }

    @Test func registeredKeysListsTheSetAndTheCenterKey() {
        var s = SweepSettings()
        s.arrowKeys = .wasd
        s.centerKey = .returnKey
        #expect(Set(HotkeyMap.registeredKeyCodes(settings: s)) == [13, 0, 1, 2, 36])
    }

    @Test func pressesWithinTheTimeoutCombine() {
        var seq = HotkeySequence(timeout: 0.8)
        #expect(seq.press(.left, at: 0) == .snap(.leftHalf))
        #expect(seq.press(.up, at: 0.5) == .snap(.topLeft))
    }

    @Test func pressAfterTheTimeoutStartsOver() {
        var seq = HotkeySequence(timeout: 0.8)
        _ = seq.press(.left, at: 0)
        #expect(seq.press(.up, at: 2) == .snap(.maximize))
    }

    @Test func upTwiceGivesTopHalf() {
        var seq = HotkeySequence(timeout: 0.8)
        _ = seq.press(.up, at: 0)
        #expect(seq.press(.up, at: 0.3) == .snap(.topHalf))
    }

    @Test func centerResetsTheSequence() {
        var seq = HotkeySequence(timeout: 0.8)
        _ = seq.press(.left, at: 0)
        #expect(seq.pressCenter() == .center)
        #expect(seq.press(.up, at: 0.2) == .snap(.maximize))
    }

    @Test func timeoutComesFromTheCancelTimeout() {
        var s = SweepSettings()
        s.cancelTimeoutMs = 1200
        #expect(HotkeySequence(settings: s).timeout == 1.2)
    }
}
