import Foundation

/// 純邏輯：依「是否在歇息」選擇呼吸週期/振幅參數（`docs/22_COMPANIONSHIP_DESIGN.md`
/// §Stage P3 rest-breath co-regulation）。不 import SpriteKit——`CharacterNode` 實際跑的
/// `SKAction.scale` 動作本身無法在 headless 測試中斷言，但「resting 狀態 → 該用哪種呼吸
/// 參數」這段選擇邏輯可以抽成純函式獨立驗證，也讓兩處（走路呼吸／休息呼吸）的數值
/// 只有一份 source of truth，不會因為分散在多個常數定義而不小心漂移。
public enum BreathingProfile {

    /// 走路呼吸週期（吸+吐秒數）：3.6s，悠閒但有機（`13_PSYCH_AUDIT.md` P1）。
    public static let walkPeriodSeconds: TimeInterval = 3.6

    /// 走路呼吸振幅：克制到幾乎不可察覺，只傳達「活著」，不能是卡通式彈跳（`02` §6 低喚醒）。
    public static let walkScaleAmplitude: Double = 0.012

    /// 休息呼吸週期：~10 秒 ≈ 6 次/分，coherent breathing / HRV 共振研究常見範圍，
    /// 比走路呼吸慢得多，才有「靜下來」的感覺（`22` §Stage P3）。
    public static let restPeriodSeconds: TimeInterval = 10.0

    /// 休息呼吸振幅：比走路呼吸（0.012）略增，讓 10 秒的慢週期下仍可察覺「活著」，
    /// 但仍克制、不能變成明顯脈動（`22` §6 低喚醒）。落在文件建議的 0.018–0.022 區間。
    public static let restScaleAmplitude: Double = 0.02

    /// 依是否在歇息（對應 `isCharacterResting`/`isAwayResting` 的視覺呈現）選擇這一刻
    /// 該用的呼吸週期。
    public static func periodSeconds(isResting: Bool) -> TimeInterval {
        isResting ? restPeriodSeconds : walkPeriodSeconds
    }

    /// 依是否在歇息選擇這一刻該用的呼吸振幅。
    public static func scaleAmplitude(isResting: Bool) -> Double {
        isResting ? restScaleAmplitude : walkScaleAmplitude
    }
}
