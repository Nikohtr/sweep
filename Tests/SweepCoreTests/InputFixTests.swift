import Testing
@testable import SweepCore

/// "Fix pinch & swipe" sleeps the displays briefly, which resets the trackpad gesture state.
@Suite struct InputFixTests {
    @Test func stepsSleepWakeThenRestart() {
        #expect(InputFix.steps == [.sleepDisplays, .wait(2), .wakeDisplays, .wait(1), .restartInput])
    }

    @Test func totalTimeIsShort() {
        let total = InputFix.steps.reduce(0.0) { sum, step in
            if case .wait(let s) = step { return sum + s } else { return sum }
        }
        #expect(total == 3)
    }

    @Test func confirmTextSaysWhatHappens() {
        #expect(InputFix.confirmText.contains("displays"))
        #expect(InputFix.confirmText.contains("No setting"))
    }
}
