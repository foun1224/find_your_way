import Foundation

/// 推進「公式」的單一真相：速率、里程→地標對應。
/// `SimulationEngine`（線上）與 `OfflineProgress`（離線）都呼叫本型別的函式，
/// 保證兩路同一套數值 —— 這是 ADR-005「在線與離線同速」的工程保證（紅線六）。
///
/// **禁止**在別處另開一條「前景加速 / 前景額外獎勵」的計算路徑。
public struct SimulationRules: Equatable {

    /// 預設推進速率（旅程單位/秒）。集中於此，方便依 §7 P1 手感調整。
    /// 數值本身無意義（抽象單位，`08` §7 P2），只有相對節奏（見 `Landmark.all` 間距）重要。
    public static let defaultSpeed: Double = 1.0

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
