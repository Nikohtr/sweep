import Testing
@testable import SweepCore

@Suite struct HapticPolicyTests {
    @Test func newLiveActionTaps() {
        #expect(HapticPolicy.shouldTap(output: .step(.swipe(.left)), previousAction: nil,
                                       newAction: .snap(.leftHalf), enabled: true))
        #expect(HapticPolicy.shouldTap(output: .step(.swipe(.up)), previousAction: .snap(.leftHalf),
                                       newAction: .snap(.topLeft), enabled: true))
    }

    @Test func sameActionDoesNotTapAgain() {
        #expect(!HapticPolicy.shouldTap(output: .step(.swipe(.left)), previousAction: .snap(.leftHalf),
                                        newAction: .snap(.leftHalf), enabled: true))
    }

    @Test func stepWithoutActionDoesNotTap() {
        #expect(!HapticPolicy.shouldTap(output: .step(.swipe(.down)), previousAction: nil,
                                        newAction: nil, enabled: true))
    }

    @Test(arguments: [Primitive.hold, .pause])
    func holdAndPauseConfirmTheChain(step: Primitive) {
        #expect(HapticPolicy.shouldTap(output: .step(step), previousAction: nil, newAction: nil, enabled: true))
    }

    @Test func endAndCancelNeverTap() {
        #expect(!HapticPolicy.shouldTap(output: .ended([.swipe(.down)]), previousAction: nil,
                                        newAction: .minimize, enabled: true))
        #expect(!HapticPolicy.shouldTap(output: .cancelled, previousAction: nil, newAction: nil, enabled: true))
    }

    @Test func disabledNeverTaps() {
        #expect(!HapticPolicy.shouldTap(output: .step(.hold), previousAction: nil, newAction: nil, enabled: false))
        #expect(!HapticPolicy.shouldTap(output: .step(.swipe(.left)), previousAction: nil,
                                        newAction: .snap(.leftHalf), enabled: false))
    }
}
