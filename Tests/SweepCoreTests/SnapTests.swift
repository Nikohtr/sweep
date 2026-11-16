import CoreGraphics
import Testing
@testable import SweepCore

private let visible = CGRect(x: 0, y: 25, width: 1440, height: 800)

@Suite struct SnapLayoutTests {
    @Test func leftHalf() {
        #expect(SnapLayout.frame(for: .leftHalf, in: visible) == CGRect(x: 0, y: 25, width: 720, height: 800))
    }

    @Test func rightHalf() {
        #expect(SnapLayout.frame(for: .rightHalf, in: visible) == CGRect(x: 720, y: 25, width: 720, height: 800))
    }

    @Test func oddWidthHasNoGapOrOverlap() {
        let v = CGRect(x: 1440, y: 0, width: 1001, height: 600)  // second screen to the right
        let l = SnapLayout.frame(for: .leftHalf, in: v)
        let r = SnapLayout.frame(for: .rightHalf, in: v)
        #expect(l.minX == 1440 && r.maxX == 2441)
        #expect(l.maxX == r.minX)
        #expect(l.width == l.width.rounded() && r.width == r.width.rounded())
    }

    @Test func screenWithLargestOverlapWins() {
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 1440, y: 0, width: 1920, height: 1080)]
        let w = CGRect(x: 1300, y: 100, width: 600, height: 400)   // 140 pt on screen 0, 460 pt on screen 1
        #expect(SnapLayout.screenIndex(for: w, screens: screens) == 1)
        #expect(SnapLayout.screenIndex(for: CGRect(x: 5000, y: 0, width: 10, height: 10), screens: screens) == nil)
    }
}

@Suite struct TitlebarActionTests {
    @Test func swipeLeftSnapsLeftHalf() {
        #expect(TitlebarActions.action(for: [.swipe(.left)]) == .snap(.leftHalf))
    }

    @Test func swipeRightSnapsRightHalf() {
        #expect(TitlebarActions.action(for: [.swipe(.right)]) == .snap(.rightHalf))
    }

    @Test func lastHorizontalSwipeWins() {
        #expect(TitlebarActions.action(for: [.swipe(.left), .swipe(.right)]) == .snap(.rightHalf))
        #expect(TitlebarActions.action(for: [.swipe(.right), .pause, .swipe(.left)]) == .snap(.leftHalf))
    }

    @Test func otherSequencesHaveNoActionYet() {
        #expect(TitlebarActions.action(for: []) == nil)
        #expect(TitlebarActions.action(for: [.tap, .tap]) == nil)
        #expect(TitlebarActions.action(for: [.pinchIn]) == nil)
        #expect(TitlebarActions.action(for: [.pinchOut, .swipe(.left)]) == nil)
    }
}

@Suite struct VerticalSnapTests {
    @Test func maximizeFillsVisibleFrame() {
        #expect(SnapLayout.frame(for: .maximize, in: visible) == visible)
    }

    @Test func topAndBottomHalves() {
        let v = CGRect(x: 0, y: 25, width: 1440, height: 801)
        let top = SnapLayout.frame(for: .topHalf, in: v)
        let bottom = SnapLayout.frame(for: .bottomHalf, in: v)
        #expect(top == CGRect(x: 0, y: 25, width: 1440, height: 400))
        #expect(bottom == CGRect(x: 0, y: 425, width: 1440, height: 401))
        #expect(top.maxY == bottom.minY)
    }

    @Test func swipeUpOnceMaximizes() {
        #expect(TitlebarActions.action(for: [.swipe(.up)]) == .snap(.maximize))
    }

    @Test func doubleSwipeUpIsTopHalf() {
        #expect(TitlebarActions.action(for: [.swipe(.up), .pause, .swipe(.up)]) == .snap(.topHalf))
    }

    @Test func doubleSwipeDownIsBottomHalf() {
        #expect(TitlebarActions.action(for: [.swipe(.down), .pause, .swipe(.down)]) == .snap(.bottomHalf))
    }

    @Test func singleSwipeDownIsLeftForMinimize() {
        #expect(TitlebarActions.action(for: [.swipe(.down)]) == nil)
    }

    @Test func mixedVerticalSequencesAreUnmapped() {
        #expect(TitlebarActions.action(for: [.swipe(.up), .swipe(.down)]) == nil)
        #expect(TitlebarActions.action(for: [.swipe(.up), .pause, .swipe(.up), .pause, .swipe(.up)]) == nil)
    }
}

@Suite struct QuarterSnapTests {
    @Test func quartersTileWithoutGaps() {
        let v = CGRect(x: 0, y: 25, width: 1441, height: 801)
        let tl = SnapLayout.frame(for: .topLeft, in: v)
        let tr = SnapLayout.frame(for: .topRight, in: v)
        let bl = SnapLayout.frame(for: .bottomLeft, in: v)
        let br = SnapLayout.frame(for: .bottomRight, in: v)
        #expect(tl == CGRect(x: 0, y: 25, width: 720, height: 400))
        #expect(br == CGRect(x: 720, y: 425, width: 721, height: 401))
        #expect(tl.maxX == tr.minX && bl.maxX == br.minX)
        #expect(tl.maxY == bl.minY && tr.maxY == br.minY)
        #expect(tr.maxX == v.maxX && br.maxY == v.maxY)
    }

    @Test(arguments: [
        ([Primitive.swipe(.left), .swipe(.up)], SnapTarget.topLeft),
        ([.swipe(.up), .swipe(.left)], .topLeft),
        ([.swipe(.right), .swipe(.up)], .topRight),
        ([.swipe(.up), .swipe(.right)], .topRight),
        ([.swipe(.left), .swipe(.down)], .bottomLeft),
        ([.swipe(.down), .swipe(.left)], .bottomLeft),
        ([.swipe(.right), .swipe(.down)], .bottomRight),
        ([.swipe(.down), .pause, .swipe(.right)], .bottomRight),
    ])
    func horizontalPlusVerticalInEitherOrder(steps: [Primitive], expected: SnapTarget) {
        #expect(TitlebarActions.action(for: steps) == .snap(expected))
    }

    @Test func latestDirectionOnEachAxisWins() {
        #expect(TitlebarActions.action(for: [.swipe(.left), .swipe(.up), .swipe(.right)]) == .snap(.topRight))
        #expect(TitlebarActions.action(for: [.swipe(.left), .swipe(.up), .swipe(.down)]) == .snap(.bottomLeft))
    }

    @Test func earlierRulesStillHold() {
        #expect(TitlebarActions.action(for: [.swipe(.left)]) == .snap(.leftHalf))
        #expect(TitlebarActions.action(for: [.swipe(.up)]) == .snap(.maximize))
        #expect(TitlebarActions.action(for: [.swipe(.up), .pause, .swipe(.up)]) == .snap(.topHalf))
    }
}

@Suite struct MinimizeTests {
    @Test func singleSwipeDownMinimizesOnEnd() {
        #expect(TitlebarActions.finalAction(for: [.swipe(.down)]) == .minimize)
    }

    @Test func minimizeIsNeverLive() {
        #expect(TitlebarActions.action(for: [.swipe(.down)]) == nil)
    }

    @Test func pauseAfterDownStillMinimizes() {
        #expect(TitlebarActions.finalAction(for: [.swipe(.down), .pause]) == .minimize)
    }

    @Test func doubleSwipeDownStaysBottomHalf() {
        #expect(TitlebarActions.finalAction(for: [.swipe(.down), .pause, .swipe(.down)]) == .snap(.bottomHalf))
    }

    @Test func finalActionFallsBackToLiveAction() {
        #expect(TitlebarActions.finalAction(for: [.swipe(.left)]) == .snap(.leftHalf))
        #expect(TitlebarActions.finalAction(for: [.swipe(.down), .swipe(.left)]) == .snap(.bottomLeft))
        #expect(TitlebarActions.finalAction(for: [.tap, .swipe(.left)]) == nil)
    }
}

@Suite struct CloseTests {
    @Test func pinchInClosesOnLift() {
        #expect(TitlebarActions.finalAction(for: [.pinchIn]) == .close)
        #expect(TitlebarActions.finalAction(for: [.pinchIn, .pause]) == .close)
    }

    @Test func closeIsNeverLive() {
        #expect(TitlebarActions.action(for: [.pinchIn]) == nil)
    }

    @Test func pinchInMixedWithOtherStepsDoesNotClose() {
        #expect(TitlebarActions.finalAction(for: [.pinchIn, .pinchOut]) != .close)
        #expect(TitlebarActions.finalAction(for: [.swipe(.left), .pinchIn]) != .close)
        #expect(TitlebarActions.finalAction(for: [.pinchIn, .pause, .pinchIn]) != .close)
    }
}

@Suite struct FullscreenToggleTests {
    @Test func pinchOutTogglesOnLift() {
        #expect(TitlebarActions.finalAction(for: [.pinchOut]) == .toggleFullscreen)
    }

    @Test func holdThenSwipeUpTogglesOnLift() {
        #expect(TitlebarActions.finalAction(for: [.hold, .swipe(.up)]) == .toggleFullscreen)
        #expect(TitlebarActions.finalAction(for: [.hold, .pause, .swipe(.up)]) == .toggleFullscreen)
    }

    @Test func holdSequencesNeverActLive() {
        #expect(TitlebarActions.action(for: [.hold, .swipe(.up)]) == nil)
        #expect(TitlebarActions.action(for: [.hold, .swipe(.left)]) == nil)
        #expect(TitlebarActions.action(for: [.pinchOut]) == nil)
    }

    @Test func swipeUpWithoutHoldStillMaximizes() {
        #expect(TitlebarActions.finalAction(for: [.swipe(.up)]) == .snap(.maximize))
    }
}

@Suite struct FullscreenMinimizeTests {
    @Test func holdThenSwipeDownMinimizes() {
        #expect(TitlebarActions.finalAction(for: [.hold, .swipe(.down)]) == .minimize)
        #expect(TitlebarActions.action(for: [.hold, .swipe(.down)]) == nil)
    }

    @Test func normalWindowMinimizesDirectly() {
        #expect(ActionPlan.steps(for: .minimize, isFullscreen: false) == [.perform(.minimize)])
    }

    @Test func fullscreenWindowLeavesFullscreenFirst() {
        #expect(ActionPlan.steps(for: .minimize, isFullscreen: true) ==
                [.perform(.toggleFullscreen), .wait(ActionPlan.fullscreenExitDelay), .perform(.minimize)])
    }

    @Test func otherActionsRunAsIs() {
        #expect(ActionPlan.steps(for: .close, isFullscreen: true) == [.perform(.close)])
        #expect(ActionPlan.steps(for: .toggleFullscreen, isFullscreen: true) == [.perform(.toggleFullscreen)])
    }
}
