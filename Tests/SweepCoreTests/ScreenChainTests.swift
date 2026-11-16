import Testing
@testable import SweepCore

@Suite struct ScreenChainTests {
    private func settings(chain: Bool) -> SweepSettings {
        var s = SweepSettings()
        s.screensChainGesture = chain
        return s
    }

    @Test func firstSwipeMovesTheWindow() {
        #expect(TitlebarActions.action(for: [.swipe(.right)], roles: [.screen], settings: settings(chain: true))
                == .moveToScreen(.right))
    }

    @Test func chainAppliesTitlebarRulesAfterTheMove() {
        let s = settings(chain: true)
        #expect(TitlebarActions.action(for: [.swipe(.right), .pause, .swipe(.left)], roles: [.screen], settings: s)
                == .snap(.leftHalf))
        #expect(TitlebarActions.action(for: [.swipe(.right), .swipe(.up)], roles: [.screen], settings: s)
                == .snap(.maximize))
        #expect(TitlebarActions.finalAction(for: [.swipe(.right), .pause, .swipe(.down)], roles: [.screen], settings: s)
                == .minimize)
    }

    @Test func withoutChainLaterStepsDoNothing() {
        #expect(TitlebarActions.action(for: [.swipe(.right), .pause, .swipe(.left)], roles: [.screen],
                                       settings: settings(chain: false)) == nil)
    }

    @Test func pauseAloneKeepsTheMove() {
        #expect(TitlebarActions.action(for: [.swipe(.right), .pause], roles: [.screen], settings: settings(chain: true))
                == .moveToScreen(.right))
    }
}
