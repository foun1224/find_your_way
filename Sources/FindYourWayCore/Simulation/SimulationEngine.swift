import Foundation

/// 線上 tick：套用 `SimulationRules` 推進 `GameState`。
/// 不 import SpriteKit/AppKit，`GameScene` 以低頻 tick 呼叫本型別（`08` §3.3）。
public enum SimulationEngine {

    /// 推進 `dt` 秒。`dt <= 0` 時原樣返回（防負/零）。
    /// **不更新 `lastActiveTimestamp`**：時間戳由呼叫端在 tick 時以 `TimeProvider.now` 寫入，職責分離。
    ///
    /// - Returns: 推進後的新狀態、本次推進新通過的地標、新遇里程事件（含旅伴相遇，依里程排序）、
    ///   以及本次是否恰好觸發旅伴相遇（供呼叫端播放 peak 呈現/日誌，`09` §3）。
    public static func advance(
        _ state: GameState,
        bySeconds dt: Double,
        rules: SimulationRules = .default
    ) -> (state: GameState, crossedLandmarks: [Landmark], crossedEvents: [JourneyEvent], companionJustJoined: Bool) {
        guard dt > 0 else { return (state, [], [], false) }

        let oldDistance = state.distance
        let gained = rules.distanceGained(overSeconds: dt)
        let newDistance = oldDistance + gained

        var newState = state
        newState.distance = newDistance
        newState.growth += gained

        let crossedLandmarks = rules.landmarks(crossedFrom: oldDistance, to: newDistance)
        for landmark in crossedLandmarks where !newState.landmarksPassed.contains(landmark.id) {
            newState.landmarksPassed.append(landmark.id)
        }

        var crossedEvents = rules.events(crossedFrom: oldDistance, to: newDistance)

        // 旅伴相遇：特殊里程事件，單調 false → true，只觸發一次（紅線一，`09` §3）。
        var companionJustJoined = false
        if !newState.companionJoined, Companion.hasMet(crossedFrom: oldDistance, to: newDistance) {
            crossedEvents.append(Companion.meetEvent)
            newState.companionJoined = true
            companionJustJoined = true
        }
        crossedEvents.sort { $0.distance < $1.distance }

        for event in crossedEvents where !newState.eventsEncountered.contains(event.id) {
            newState.eventsEncountered.append(event.id)
        }

        return (newState, crossedLandmarks, crossedEvents, companionJustJoined)
    }
}
