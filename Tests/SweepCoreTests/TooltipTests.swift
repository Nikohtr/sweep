import CoreGraphics
import Testing
@testable import SweepCore

/// Tooltips show what a gesture will do, with a live preview of the snap (General tab).
@Suite struct TooltipTests {
    private let window = CGRect(x: 100, y: 100, width: 600, height: 400)
    private let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)

    @Test func offMeansNoTooltip() {
        var s = SweepSettings()
        s.tooltipsEnabled = false
        #expect(TooltipPlan.make(action: .snap(.leftHalf), windowFrame: window, visible: visible, settings: s) == nil)
    }

    @Test func noActionNoTooltip() {
        #expect(TooltipPlan.make(action: nil, windowFrame: window, visible: visible, settings: SweepSettings()) == nil)
    }

    @Test func snapPreviewIsTheTargetFrame() {
        let s = SweepSettings()
        let t = TooltipPlan.make(action: .snap(.leftHalf), windowFrame: window, visible: visible, settings: s)
        #expect(t?.preview == SnapLayout.frame(for: .leftHalf, in: visible, settings: s))
        #expect(t?.label == "Left half")
    }

    @Test func otherActionsPreviewTheWindow() {
        let t = TooltipPlan.make(action: .minimize, windowFrame: window, visible: visible, settings: SweepSettings())
        #expect(t?.preview == window)
        #expect(t?.label == "Minimize")
    }

    @Test func liveOffShowsOnlyTheLabel() {
        var s = SweepSettings()
        s.liveTooltips = false
        let t = TooltipPlan.make(action: .snap(.maximize), windowFrame: window, visible: visible, settings: s)
        #expect(t?.preview == nil)
        #expect(t?.label == "Fill the screen")
    }

    @Test func fontSizeFollowsTheSlider() {
        var s = SweepSettings()
        s.tooltipSize = 7
        #expect(TooltipPlan.make(action: .close, windowFrame: window, visible: visible, settings: s)?.fontSize == 21)
        s.tooltipSize = 3
        #expect(TooltipPlan.make(action: .close, windowFrame: window, visible: visible, settings: s)?.fontSize == 9)
    }

    @Test func everyActionHasALabel() {
        let actions: [WindowAction] = [.snap(.topLeft), .snap(.leftThird), .snap(.grid(GridSpan(columns: 3, rows: 3, x: 0..<1, y: 0..<1))),
                                       .close, .toggleFullscreen, .center, .hideApp, .hideOtherApps,
                                       .moveToScreen(.left), .fullscreenOnOtherScreen, .moveToOtherScreen, .moveToSpace(.right)]
        #expect(actions.allSatisfy { !TooltipPlan.label(for: $0).isEmpty })
    }
}
