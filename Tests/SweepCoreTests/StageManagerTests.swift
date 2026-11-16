import CoreGraphics
import Testing
@testable import SweepCore

private let v = CGRect(x: 0, y: 25, width: 1440, height: 800)

@Suite struct StageManagerTests {
    @Test func offsetMovesLeftEdgeWhenOn() {
        #expect(SnapLayout.usableFrame(visible: v, stageManagerOn: true, offset: 190)
                == CGRect(x: 190, y: 25, width: 1250, height: 800))
    }

    @Test func offFrameIsUnchanged() {
        #expect(SnapLayout.usableFrame(visible: v, stageManagerOn: false, offset: 190) == v)
        #expect(SnapLayout.usableFrame(visible: v, stageManagerOn: true, offset: 0) == v)
    }

    @Test func offsetNeverEatsTheWholeScreen() {
        let small = CGRect(x: 0, y: 0, width: 200, height: 300)
        #expect(SnapLayout.usableFrame(visible: small, stageManagerOn: true, offset: 240).width >= 100)
    }

    @Test func snapTargetsUseTheUsableFrame() {
        var s = SweepSettings()
        s.stageManagerOffset = 190
        let left = SnapLayout.frame(for: .leftHalf, in: v, settings: s, stageManagerOn: true)
        #expect(left == CGRect(x: 190, y: 25, width: 625, height: 800))
        #expect(SnapLayout.frame(for: .maximize, in: v, settings: s, stageManagerOn: false) == v)
    }
}
