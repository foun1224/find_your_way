import Foundation

/// 推進「公式」的單一真相：速率、里程→地標對應。
/// `SimulationEngine`（線上）與 `OfflineProgress`（離線）都呼叫本型別的函式，
/// 保證兩路同一套數值 —— 這是 ADR-005「在線與離線同速」的工程保證（紅線六）。
///
/// **禁止**在別處另開一條「前景加速 / 前景額外獎勵」的計算路徑。
public struct SimulationRules: Equatable {

    /// 預設推進速率（旅程單位/秒，1 單位≈1pt）。集中於此，方便依 §7 P1 手感調整。
    /// `08` §4b provisional：由 1 調到 12 —— 現場看是「悠閒但清楚可見」的散步（緩慢平移、不焦躁、非靜止）。
    /// **線上=離線同速**仍由本單一來源保證（ADR-005 / 紅線六）。使用者反應後再調。
    public static let defaultSpeed: Double = 12.0

    public let speed: Double

    public init(speed: Double = SimulationRules.defaultSpeed) {
        self.speed = max(0, speed)
    }

    /// 單一真相：線上/離線共用的速率常數集合。
    public static let `default` = SimulationRules()

    /// `seconds` 期間累積的里程增量。`seconds` 已由呼叫端夾為非負（此處再次防呆）。
    public func distanceGained(overSeconds seconds: Double) -> Double {
        max(0, seconds) * speed
    }

    /// 回傳 `(old, new]` 區間內新通過的地標（確定性、只看里程軸，不擲骰）。
    public func landmarks(crossedFrom old: Double, to new: Double) -> [Landmark] {
        guard new > old else { return [] }
        return Landmark.all.filter { $0.distance > old && $0.distance <= new }
    }
}
