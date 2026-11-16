import Foundation
import Testing
@testable import SweepCore

@Suite struct SettingsTests {
    @Test func defaultsMatchTheOriginalSliders() {
        let s = SweepSettings()
        #expect(s.sensitivity == 3)
        #expect(s.cancelTimeoutMs == 800)
        #expect(s.tooltipSize == 5)
        #expect(s.gridSpacing == 0)
        #expect(s.stageManagerOffset == 190)
        #expect(s.externalDisplayTimeout == 4)
    }

    @Test func clampedForcesEveryRange() {
        var s = SweepSettings()
        s.sensitivity = 9
        s.cancelTimeoutMs = 100
        s.tooltipSize = 1
        s.gridSpacing = 40
        s.stageManagerOffset = -5
        s.externalDisplayTimeout = 99
        let c = s.clamped()
        #expect(c.sensitivity == 4)
        #expect(c.cancelTimeoutMs == 400)
        #expect(c.tooltipSize == 3)
        #expect(c.gridSpacing == 12)
        #expect(c.stageManagerOffset == 0)
        #expect(c.externalDisplayTimeout == 20)
    }

    @Test func gridSpacingAllowsMinusOne() {
        var s = SweepSettings()
        s.gridSpacing = -1
        #expect(s.clamped().gridSpacing == -1)
        s.gridSpacing = -3
        #expect(s.clamped().gridSpacing == -1)
    }

    @Test func jsonRoundTrip() throws {
        var s = SweepSettings()
        s.sensitivity = 1
        s.hideCursor = true
        s.arrowKeys = .wasd
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(SweepSettings.self, from: data) == s)
    }

    @Test func missingKeysKeepDefaults() throws {
        let old = Data(#"{"sensitivity": 2}"#.utf8)
        let s = try JSONDecoder().decode(SweepSettings.self, from: old)
        #expect(s.sensitivity == 2)
        #expect(s.cancelTimeoutMs == 800)
        #expect(s.tapHold == SweepSettings().tapHold)
    }

    @Test func decodedValuesAreClamped() throws {
        let bad = Data(#"{"sensitivity": 12, "cancelTimeoutMs": 5}"#.utf8)
        let s = try JSONDecoder().decode(SweepSettings.self, from: bad)
        #expect(s.sensitivity == 4)
        #expect(s.cancelTimeoutMs == 400)
    }

    @Test func recognizerConfigFollowsSettings() {
        var s = SweepSettings()
        s.sensitivity = 4
        s.cancelTimeoutMs = 1200
        s.tapHold = false
        let c = s.recognizerConfig
        #expect(c == RecognizerConfig(sensitivity: 4, cancelTimeoutMs: 1200, tapHoldEnabled: false))
    }
}

@Suite struct CancelTimeoutSettingTests {
    @Test(arguments: [(800, "0.8 s"), (400, "0.4 s"), (2000, "2.0 s"), (1200, "1.2 s")])
    func secondsLabel(ms: Int, text: String) {
        #expect(SettingsFormat.seconds(ms: ms) == text)
    }

    @Test func timeoutChangesRecognizerConfig() {
        var s = SweepSettings()
        s.cancelTimeoutMs = 1600
        #expect(s.recognizerConfig.cancelTimeout == 1.6)
    }

    @Test func sliderStepsCoverTheRange() {
        #expect(SettingsFormat.cancelTimeoutStepMs == 200)
        let steps = stride(from: 400, through: 2000, by: SettingsFormat.cancelTimeoutStepMs).map { $0 }
        #expect(steps.count == 9)   // 9 tick marks on the slider
    }
}

@Suite struct TapHoldSettingTests {
    private func restAndSwipeUp(_ settings: SweepSettings) -> [Primitive] {
        var r = GestureRecognizer(config: settings.recognizerConfig)
        var out = r.handle(.scroll(dx: 0, dy: 0, phase: .mayBegin, time: 0))
        out += r.tick(now: settings.recognizerConfig.restDelay + 0.001)
        for i in 0..<6 {
            out += r.handle(.scroll(dx: 0, dy: 10, phase: i == 0 ? .began : .changed, time: 0.2 + Double(i) * 0.01))
        }
        return out.compactMap { if case .step(let p) = $0 { return p } else { return nil } }
    }

    @Test func tapHoldOnGivesHoldThenFullscreen() {
        let steps = restAndSwipeUp(SweepSettings())
        #expect(steps == [.hold, .swipe(.up)])
        #expect(TitlebarActions.finalAction(for: steps) == .toggleFullscreen)
    }

    @Test func tapHoldOffGivesPlainSwipeUp() {
        var s = SweepSettings()
        s.tapHold = false
        let steps = restAndSwipeUp(s)
        #expect(steps == [.swipe(.up)])
        #expect(TitlebarActions.finalAction(for: steps) == .snap(.maximize))
    }
}

@Suite struct ResetSettingsTests {
    private var changed: SweepSettings {
        var s = SweepSettings()
        s.sensitivity = 1
        s.gridSpacing = 9
        s.hapticFeedback = false
        s.setKeys([.option, .command], for: .general)
        s.ignoredApps = ["com.example.game"]
        return s
    }

    @Test func restoreAllKeepsTheIgnoreListByDefault() {
        let r = changed.restoredDefaults()
        var expected = SweepSettings.newInstall()   // A reset uses the safer new-install defaults
        expected.ignoredApps = ["com.example.game"]
        #expect(r == expected)
    }

    @Test func restoreAllCanAlsoClearTheIgnoreList() {
        #expect(changed.restoredDefaults(keepingIgnoredApps: false) == SweepSettings.newInstall())
    }

    @Test func restoreModifiersTouchesOnlyModifiers() {
        var s = changed
        s.resetModifiers()
        #expect(s.keys(for: .general) == [.control])
        #expect(s.sensitivity == 1 && s.gridSpacing == 9)
    }
}
