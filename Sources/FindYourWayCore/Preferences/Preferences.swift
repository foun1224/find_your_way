import Foundation

/// 偏好純值模型（`10` §4.3）：與遊戲主存檔（`save.json`）分離，走 UserDefaults。
/// **不含**登入自啟狀態——那是 `SMAppService` 的系統真相，非我方資料（`10` §2.2）。
public struct Preferences: Equatable {
    /// 使用者對 reduce motion 的覆寫；`nil` 表示「未設定，跟隨系統」（`10` §4.2）。
    public var reduceMotionOverride: Bool?

    /// 音量預留欄位（`10` §10 待決 6：Phase 5 UI 先不放，但資料模型先留位）。
    public var volume: Double

    /// 桌寵視窗記憶位置（ADR-011）：使用者拖曳後記住的視窗 origin；`nil` 表示「未拖曳過，
    /// 用預設右下角」（`PetWindowConfig.bottomRightFrame`）。與遊戲主存檔分離，屬偏好同層。
    public var windowOrigin: CGPoint?

    public init(reduceMotionOverride: Bool? = nil, volume: Double = 1.0, windowOrigin: CGPoint? = nil) {
        self.reduceMotionOverride = reduceMotionOverride
        self.volume = volume
        self.windowOrigin = windowOrigin
    }
}

/// UserDefaults 鍵常數，單一真相來源，避免字串散落各處。
public enum PreferencesKey {
    public static let reduceMotionOverride = "com.findyourway.preferences.reduceMotionOverride"
    public static let volume = "com.findyourway.preferences.volume"
    public static let windowOriginX = "com.findyourway.preferences.windowOriginX"
    public static let windowOriginY = "com.findyourway.preferences.windowOriginY"
}
