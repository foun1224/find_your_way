import Foundation

/// 純邏輯：主角「偶爾停下看你」的排程判斷（`docs/13_PSYCH_AUDIT.md` P1 / `02` §2 社會臨場感、
/// §6 低喚醒）。不 import SpriteKit，不含任何 runtime 狀態，供 `GameScene`/`CharacterNode`
/// 消費，也方便獨立單元測試。
///
/// 設計：每次觸發後，下一次觸發前要等待的秒數、以及這次要「看你」多久，都是由呼叫端傳入
/// 一個 `[0,1)` 的均勻亂數（例如 `Double.random(in: 0..<1)`）換算而成——把「亂數 → 秒數」
/// 這段換算抽成純函式，而不把 `Double.random` 直接埋進 `GameScene`，這樣換算規則本身
/// （範圍、線性插值）就可以脫離 SpriteKit runtime 單獨驗證。
public enum HeroRestSchedule {

    /// 下一次「偶爾看你」觸發前的等待秒數下界／上界：平均每 40–70 秒一次，均勻分布，
    /// 刻意不用固定週期以免顯得機械（`02` §2「自主微行為」）。
    public static let minIntervalSeconds: TimeInterval = 40
    public static let maxIntervalSeconds: TimeInterval = 70

    /// 每次「看你」持續多久（秒）：2–3 秒，短到不打擾、長到能被使用者注意到。
    public static let minRestDurationSeconds: TimeInterval = 2.0
    public static let maxRestDurationSeconds: TimeInterval = 3.0

    /// 轉身淡入淡出的過場時間（秒）：慢、無跳動（`02` §6），走路 ↔ 看你之間的過渡。
    public static let transitionDurationSeconds: TimeInterval = 0.5

    /// 世界視覺捲動（`displayedDistance`）在「看你」結束後追趕回真實里程的補間時間（秒）。
    /// 落在 0.4–0.6 秒的柔和 ease-in-out 範圍（休息時間短、頻率低，追趕量本身很小）。
    public static let catchUpDurationSeconds: TimeInterval = 0.5

    /// 依 `[0,1)` 均勻亂數 `unit` 線性換算成下一次觸發前的等待秒數。
    /// `unit` 超出 `[0,1)` 時會被夾住（clamp），確保結果恆落在
    /// `[minIntervalSeconds, maxIntervalSeconds]`。
    public static func nextIntervalSeconds(unit: Double) -> TimeInterval {
        let clamped = min(max(unit, 0), 1)
        return minIntervalSeconds + (maxIntervalSeconds - minIntervalSeconds) * clamped
    }

    /// 依 `[0,1)` 均勻亂數 `unit` 線性換算成這次「看你」要停留多久。
    public static func restDurationSeconds(unit: Double) -> TimeInterval {
        let clamped = min(max(unit, 0), 1)
        return minRestDurationSeconds + (maxRestDurationSeconds - minRestDurationSeconds) * clamped
    }
}
