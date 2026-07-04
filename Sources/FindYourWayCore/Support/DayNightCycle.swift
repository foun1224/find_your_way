import Foundation

/// 晝夜色調映射（`03_DESIGN_SYSTEM.md` §1.4、`12_PHASE4_SPEC.md` §3）：純函式，
/// 「一天中的時間」→ 全域 tint overlay 顏色。**不 import SpriteKit**——`GameScene` 只是
/// 把回傳的 `Palette.RGBA` 套到 overlay 節點的 color/alpha，維持本檔可離線單元測試。
///
/// 原則（`03` §1.4）：
/// - 黎明暖、白日近乎無 tint（基準）、黃金時刻暖峰、黃昏轉冷、夜月光藍**但不純黑**。
/// - 兩兩關鍵時刻之間**線性插值**，任一瞬間都不跳變（分鐘級平滑漸變）。
/// - 24 小時**環狀 wrap**：最後一個影格（24h）與第一個影格（0h）顏色相同，銜接處連續無跳變。
public enum DayNightCycle {

    /// 一天秒數，供呼叫端把「現在」換算成「當日秒數」（0..<86400）。
    public static let secondsPerDay: Double = 24 * 60 * 60

    /// 色溫關鍵影格：(當日秒數, 顏色, overlay alpha)。
    private struct Keyframe {
        let secondsIntoDay: Double
        let color: Palette.RGBA
        let alpha: Double
    }

    // 夜：深藍紫、不純黑（`03` §1.4「夜間關鍵」）。
    private static let night = Palette.RGBA(red: 0.12, green: 0.16, blue: 0.34)
    // 黎明：淡粉橘薄霧。
    private static let dawnColor = Palette.RGBA(red: 0.98, green: 0.80, blue: 0.72)
    // 白日：近乎無 tint 的基準（白色 + 極低 alpha，見下方 alpha 設定）。
    private static let dayColor = Palette.RGBA(red: 1.0, green: 1.0, blue: 1.0)
    // 黃金時刻：濃暖金橘，療癒峰值。
    private static let goldenColor = Palette.RGBA(red: 1.0, green: 0.64, blue: 0.30)
    // 黃昏：藍紫漸濃，收束沉靜。
    private static let duskColor = Palette.RGBA(red: 0.32, green: 0.26, blue: 0.50)

    /// 依時間排序的關鍵影格。首尾（0h / 24h）色彩相同以確保環狀 wrap 無跳變。
    // alpha 值經真機截圖校準：太低（<0.2）在明亮像素美術上讀不出時段；
    // 以下值可清楚表現時段又不遮蔽角色辨識度（`02` §6 低喚醒、仍可見）。
    private static let keyframes: [Keyframe] = [
        Keyframe(secondsIntoDay: 0 * 3600, color: night, alpha: 0.46),
        Keyframe(secondsIntoDay: 4 * 3600, color: night, alpha: 0.46),
        Keyframe(secondsIntoDay: 6 * 3600, color: dawnColor, alpha: 0.30),
        Keyframe(secondsIntoDay: 8 * 3600, color: dayColor, alpha: 0.04),
        Keyframe(secondsIntoDay: 16 * 3600, color: dayColor, alpha: 0.04),
        Keyframe(secondsIntoDay: 18 * 3600, color: goldenColor, alpha: 0.34),
        Keyframe(secondsIntoDay: 19.5 * 3600, color: duskColor, alpha: 0.44),
        Keyframe(secondsIntoDay: 21 * 3600, color: night, alpha: 0.46),
        Keyframe(secondsIntoDay: 24 * 3600, color: night, alpha: 0.46)
    ]

    /// 依「當日秒數」算出全域 tint。超出 `[0, 86400)` 的輸入會自動環狀 wrap（`mod` 24h）。
    public static func tint(forSecondsIntoDay rawSeconds: Double) -> Palette.RGBA {
        let wrapped = rawSeconds.truncatingRemainder(dividingBy: secondsPerDay)
        let normalized = wrapped < 0 ? wrapped + secondsPerDay : wrapped

        for i in 0..<(keyframes.count - 1) {
            let a = keyframes[i]
            let b = keyframes[i + 1]
            if normalized >= a.secondsIntoDay && normalized <= b.secondsIntoDay {
                let span = b.secondsIntoDay - a.secondsIntoDay
                let u = span > 0 ? (normalized - a.secondsIntoDay) / span : 0
                return interpolate(a, b, u)
            }
        }
        // 理論不可達：keyframes 首尾覆蓋 [0, 24h]。回傳夜色屬保守 fallback。
        return night.withAlpha(keyframes[0].alpha)
    }

    private static func interpolate(_ a: Keyframe, _ b: Keyframe, _ u: Double) -> Palette.RGBA {
        Palette.RGBA(
            red: a.color.red + (b.color.red - a.color.red) * u,
            green: a.color.green + (b.color.green - a.color.green) * u,
            blue: a.color.blue + (b.color.blue - a.color.blue) * u,
            alpha: a.alpha + (b.alpha - a.alpha) * u
        )
    }
}

extension Palette.RGBA {
    /// 回傳同色但替換 alpha 的複本（供純函式組裝用，避免逐欄位重寫）。
    func withAlpha(_ alpha: Double) -> Palette.RGBA {
        Palette.RGBA(red: red, green: green, blue: blue, alpha: alpha)
    }
}
