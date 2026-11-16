import Testing
@testable import SweepCore

/// Combine with the macOS window tiling.
@Suite struct NativeTilingTests {
    @Test(arguments: [(SnapTarget.leftHalf, UInt16(123)), (.rightHalf, 124), (.topHalf, 126), (.bottomHalf, 125),
                      (.maximize, 3)])
    func chordsForSystemTiles(target: SnapTarget, keyCode: UInt16) {
        #expect(NativeTiling.chord(for: target) == KeyChord(keyCode: keyCode, modifiers: [.control, .function]))
    }

    @Test func noChordForOtherTargets() {
        #expect(NativeTiling.chord(for: .topLeft) == nil)
        #expect(NativeTiling.chord(for: .leftThird) == nil)
        #expect(NativeTiling.chord(for: .almostMaximize) == nil)
        #expect(NativeTiling.chord(for: .grid(GridSpan(columns: 3, rows: 3, x: 0..<1, y: 0..<1))) == nil)
    }

    @Test func onlyWhenTheSettingIsOn() {
        var s = SweepSettings()
        #expect(!NativeTiling.useNative(target: .leftHalf, settings: s))
        s.nativeTiling = true
        #expect(NativeTiling.useNative(target: .leftHalf, settings: s))
        #expect(!NativeTiling.useNative(target: .leftThird, settings: s))
    }

    @Test func gridSpacingKeepsOurOwnFrames() {
        // The system tiles use their own margins, so a custom gap means we place the window ourselves.
        var s = SweepSettings()
        s.nativeTiling = true
        s.gridSpacing = 8
        #expect(!NativeTiling.useNative(target: .leftHalf, settings: s))
    }

    @Test func functionKeySymbol() {
        #expect(ModifierKeys([.control, .function]).symbols == "⌃fn")
    }
}
