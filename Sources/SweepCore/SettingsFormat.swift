/// Text and steps for settings controls, kept here so they can be tested.
public enum SettingsFormat {
    /// Step of the cancel timeout slider. 400…2000 ms in 200 ms steps gives 9 ticks.
    public static let cancelTimeoutStepMs = 200

    /// "0.8 s" for 800 ms. Always one decimal.
    public static func seconds(ms: Int) -> String {
        let tenths = (ms + 50) / 100
        return "\(tenths / 10).\(tenths % 10) s"
    }
}
