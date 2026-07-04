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

        let windowOrigin = loadWindowOrigin()

        return Preferences(reduceMotionOverride: reduceMotionOverride, volume: volume, windowOrigin: windowOrigin)
    }

    /// 讀出記憶的視窗位置（ADR-011）；兩個座標軸必須都寫過才視為「有記憶位置」，
    /// 避免只寫了一半（例如寫入中途被中斷）造成座標其中一軸沿用舊值/預設值的錯位。
    private func loadWindowOrigin() -> CGPoint? {
        guard
            defaults.object(forKey: PreferencesKey.windowOriginX) != nil,
            defaults.object(forKey: PreferencesKey.windowOriginY) != nil
        else {
            return nil
        }
        let x = defaults.double(forKey: PreferencesKey.windowOriginX)
        let y = defaults.double(forKey: PreferencesKey.windowOriginY)
        return CGPoint(x: x, y: y)
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

    /// 寫入拖曳後的視窗位置（ADR-011）；傳 `nil` 表示清除記憶、回到預設右下角落點。
    public func setWindowOrigin(_ origin: CGPoint?) {
        if let origin {
            defaults.set(Double(origin.x), forKey: PreferencesKey.windowOriginX)
            defaults.set(Double(origin.y), forKey: PreferencesKey.windowOriginY)
        } else {
            defaults.removeObject(forKey: PreferencesKey.windowOriginX)
            defaults.removeObject(forKey: PreferencesKey.windowOriginY)
        }
    }
}
