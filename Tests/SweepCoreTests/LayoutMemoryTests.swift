import CoreGraphics
import Testing
@testable import SweepCore

/// After a display change, windows go back to where they were the last time
/// the same set of displays was connected.
@Suite struct LayoutMemoryTests {
    private let laptop = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let external = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    private var both: DisplaySignature { DisplaySignature(screens: [laptop, external]) }
    private var alone: DisplaySignature { DisplaySignature(screens: [laptop]) }

    @Test func signatureIgnoresScreenOrder() {
        #expect(DisplaySignature(screens: [external, laptop]) == both)
        #expect(alone != both)
    }

    @Test func restoresMovedWindowsForAKnownSignature() {
        var m = LayoutMemory<String>()
        let a = CGRect(x: 1500, y: 40, width: 800, height: 600)
        let b = CGRect(x: 10, y: 40, width: 600, height: 400)
        m.record(signature: both, frames: ["a": a, "b": b])
        // The external display comes back; macOS left "a" on the laptop.
        let current = ["a": CGRect(x: 100, y: 40, width: 800, height: 600), "b": b]
        #expect(m.restorePlan(signature: both, current: current, timeoutSeconds: 4) == ["a": a])
    }

    @Test func nothingForAnUnknownSignature() {
        var m = LayoutMemory<String>()
        m.record(signature: alone, frames: ["a": laptop])
        #expect(m.restorePlan(signature: both, current: ["a": .zero], timeoutSeconds: 4).isEmpty)
    }

    @Test func zeroTimeoutTurnsItOff() {
        var m = LayoutMemory<String>()
        m.record(signature: both, frames: ["a": external])
        #expect(m.restorePlan(signature: both, current: ["a": laptop], timeoutSeconds: 0).isEmpty)
    }

    @Test func closedWindowsAreSkipped() {
        var m = LayoutMemory<String>()
        m.record(signature: both, frames: ["a": external, "gone": laptop])
        #expect(m.restorePlan(signature: both, current: ["a": laptop], timeoutSeconds: 4) == ["a": external])
    }

    @Test func recordReplacesTheLayoutOfThatSignatureOnly() {
        var m = LayoutMemory<String>()
        m.record(signature: both, frames: ["a": external])
        m.record(signature: alone, frames: ["a": laptop])
        m.record(signature: both, frames: ["a": external.insetBy(dx: 10, dy: 10)])
        #expect(m.saved(for: both) == ["a": external.insetBy(dx: 10, dy: 10)])
        #expect(m.saved(for: alone) == ["a": laptop])
    }

    @Test func restoreDelayFollowsTheSetting() {
        var s = SweepSettings()
        #expect(LayoutMemory<String>.restoreDelay(settings: s) == 4)
        s.externalDisplayTimeout = 0
        #expect(LayoutMemory<String>.restoreDelay(settings: s) == nil)
    }
}
