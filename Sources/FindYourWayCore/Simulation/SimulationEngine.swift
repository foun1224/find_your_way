import Foundation

/// 線上 tick：套用 `SimulationRules` 推進 `GameState`。
/// 不 import SpriteKit/AppKit，`GameScene` 以低頻 tick 呼叫本型別（`08` §3.3）。
public enum SimulationEngine {

    /// 推進 `dt` 秒。`dt <= 0` 時原樣返回（防負/零）。
    /// **不更新 `lastActiveTimestamp`**：時間戳由呼叫端在 tick 時以 `TimeProvider.now` 寫入，職責分離。
    ///
    /// - Returns: 推進後的新狀態，以及本次推進新通過的地標（供呼叫端播放呈現/日誌）。
    public static func advance(
        _ state: GameState,
        bySeconds dt: Double,
        rules: SimulationRules = .default
    ) -> (GameState, [Landmark]) {
        guard dt > 0 else { return (state, []) }

        let oldDistance = state.distance
        let gained = rules.distanceGained(overSeconds: dt)
        let newDistance = oldDistance + gained

        var newState = state
        newState.distance = newDistance
        newState.growth += gained

        let crossed = rules.landmarks(crossedFrom: oldDistance, to: newDistance)
        for landmark in crossed where !newState.landmarksPassed.contains(landmark.id) {
            newState.landmarksPassed.append(landmark.id)
        }

        return (newState, crossed)
    }
}
