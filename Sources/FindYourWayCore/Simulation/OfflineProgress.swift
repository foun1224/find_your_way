import Foundation

/// 離線結算（ADR-005 核心）：讀 `lastActiveTimestamp`、以 `now` 算 elapsed、
/// 套 ADR-005 規則、用與線上共用的 `SimulationRules` 一次結算。
///
/// **防弊定位**：純陪伴、無排行榜，只做「負→0、超上限截斷」兩道，
/// 不做時鐘連續性追蹤/反回撥偵測（`08` §3.5 防弊定位）。
public enum OfflineProgress {

    /// 離線結算上限：12 小時（ADR-005 / `08` §7 P4）。
    public static let capSeconds: Double = 12 * 60 * 60

    /// - Parameters:
    ///   - state: 結算前狀態。
    ///   - now: 目前時刻（Unix 秒），一律由 `TimeProvider.now` 取得。
    ///   - rules: 與線上 `SimulationEngine` 共用同一套規則，保證同速（ADR-005）。
    /// - Returns: 結算後的新狀態，與供呈現用的 `OfflineOutcome`。
    public static func settle(
        _ state: GameState,
        now: Double,
        rules: SimulationRules = .default
    ) -> (GameState, OfflineOutcome) {
        let rawElapsed = now - state.lastActiveTimestamp
        let elapsed = min(max(rawElapsed, 0), capSeconds)
        let wasCapped = rawElapsed > capSeconds

        let (advanced, crossed) = SimulationEngine.advance(state, bySeconds: elapsed, rules: rules)

        var newState = advanced
        newState.lastActiveTimestamp = now

        let outcome = OfflineOutcome(
            elapsedSecondsApplied: elapsed,
            distanceGained: newState.distance - state.distance,
            newLandmarks: crossed,
            wasCapped: wasCapped
        )

        return (newState, outcome)
    }
}
