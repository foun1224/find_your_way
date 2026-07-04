import Foundation

/// 天氣狀態（`03_DESIGN_SYSTEM.md` §1.4、`12_PHASE4_SPEC.md` §4）：純裝飾、**不入 `GameState`**、
/// 錯過無損（`09` §2.2 B 類氛圍）。一律「柔化」不「戲劇化」——不製造壓力。
public enum WeatherKind: Equatable, Sendable {
    case clear
    case overcast
    case rain
}

/// 天氣選擇與 overlay tint：全部純函式，不 import SpriteKit。
public enum Weather {

    /// 天氣切換的週期（秒）：低頻，避免頻繁跳動（`12` §4「低頻」）。20 分鐘一次「擲骰」。
    public static let periodSeconds: Double = 20 * 60

    /// 依「Unix 秒 / periodSeconds」向下取整的週期索引：同一週期內任何時間點結果一致。
    public static func epochIndex(unixSeconds: Double, periodSeconds: Double = Weather.periodSeconds) -> Int {
        Int(floor(unixSeconds / periodSeconds))
    }

    /// 純函式、確定性天氣選擇：**同一個 `epochIndex` 永遠得到同一結果**（可單元測試），
    /// 但週期索引本身隨真實時間流逝自然改變。這是「確定性」而非「以 now 為 seed 影響持久狀態
    /// 的隨機」——天氣不持久化、錯過無損，純粹是每 20 分鐘換一次的裝飾（`12` §4）。
    /// 分布權重：晴 60% / 陰 25% / 雨 15%（低喚醒基調：晴天為主，雨只是偶爾的點綴）。
    public static func kind(forEpochIndex index: Int) -> WeatherKind {
        // 簡單確定性整數混雜（splitmix64 風格），不需密碼學強度，只求分布均勻、對輸入敏感。
        var x = UInt64(bitPattern: Int64(index))
        x ^= x >> 33
        x = x &* 0xff51afd7ed558ccd
        x ^= x >> 33
        x = x &* 0xc4ceb9fe1a85ec53
        x ^= x >> 33
        let bucket = x % 100
        switch bucket {
        case 0..<60: return .clear
        case 60..<85: return .overcast
        default: return .rain
        }
    }

    /// 便利入口：直接由 Unix 秒算出目前天氣。
    public static func kind(forUnixSeconds unixSeconds: Double) -> WeatherKind {
        kind(forEpochIndex: epochIndex(unixSeconds: unixSeconds))
    }

    /// 天氣對應的全域 overlay tint（`03` §1.4）：
    /// 晴天無 overlay（`nil`）；陰天降飽和、抬暗部明度（淡灰，柔化對比）；雨天整體冷偏藍、對比再降。
    public static func overlayTint(for kind: WeatherKind) -> Palette.RGBA? {
        switch kind {
        case .clear:
            return nil
        case .overcast:
            return Palette.RGBA(red: 0.75, green: 0.75, blue: 0.78, alpha: 0.20)
        case .rain:
            return Palette.RGBA(red: 0.45, green: 0.55, blue: 0.68, alpha: 0.26)
        }
    }
}
