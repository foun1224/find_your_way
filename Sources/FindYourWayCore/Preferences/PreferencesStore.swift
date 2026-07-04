import Foundation

/// 偏好讀寫（UserDefaults），**可注入 `UserDefaults` 實例**供測試隔離，
/// 避免污染 `.standard`（`10` §4.3 / §8.1）。不含 SMAppService（系統呼叫，非資料層）。
public final class PreferencesStore {

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 讀出目前偏好；`reduceMotionOverride` 未設定過時回傳 `nil`（跟隨系統，`MotionSettings`）。
    public func load() -> Preferences {
        let hasReduceMotion = defaults.object(forKey: PreferencesKey.reduceMotionOverride) != nil
        let reduceMotionOverride = hasReduceMotion
            ? defaults.bool(forKey: PreferencesKey.reduceMotionOverride)
            : nil

        let hasVolume = defaults.object(forKey: PreferencesKey.volume) != nil
        let volume = hasVolume ? defaults.double(forKey: PreferencesKey.volume) : 1.0

        return Preferences(reduceMotionOverride: reduceMotionOverride, volume: volume)
    }

    /// 寫入 reduce motion 覆寫值；傳 `nil` 表示清除覆寫、回到跟隨系統。
    public func setReduceMotionOverride(_ value: Bool?) {
        if let value {
            defaults.set(value, forKey: PreferencesKey.reduceMotionOverride)
        } else {
            defaults.removeObject(forKey: PreferencesKey.reduceMotionOverride)
        }
    }

    public func setVolume(_ value: Double) {
        defaults.set(value, forKey: PreferencesKey.volume)
    }
}
