import Foundation

/// reduce-motion 解析純函式（`10` §4.3）：使用者未設 → 跟隨系統；已設 → 使用者勝出。
public enum MotionSettings {
    public static func effectiveReduceMotion(userOverride: Bool?, systemPref: Bool) -> Bool {
        userOverride ?? systemPref
    }
}
