import Foundation

/// 旅伴相遇（ADR-004）：相遇是一個特殊的里程事件，掛在 `meetDistance`（`09` §3/§10.3，定案）。
/// 純函式判定，同 `Landmark`/`JourneyEvent` 範式——只看里程、不擲骰。
/// **peak event**：相遇後 `GameState.companionJoined` 單調 false → true，永不回退（紅線一）。
public enum Companion {
    /// 相遇里程（`09` §10.3 定案：第二章開端，約第 2–3 個地標之間）。
    public static let meetDistance: Double = 237_600

    /// 相遇事件的旅程日誌文案（留白可投射語氣，`02` §5）。
    public static let logText = "在岔路口，有個人也正要往同一個方向。你們沒說話，卻自然地一起走了。"

    /// 相遇事件本身（`kind: .companionMeet`），供併入 `eventsEncountered`/日誌。
    public static let meetEvent = JourneyEvent(
        id: "companion_meet",
        kind: .companionMeet,
        distance: meetDistance,
        logText: logText
    )

    /// 純函式：`(old, new]` 區間是否跨越相遇里程（確定性、不擲骰，同地標/事件範式）。
    public static func hasMet(crossedFrom old: Double, to new: Double) -> Bool {
        guard new > old else { return false }
        return meetDistance > old && meetDistance <= new
    }
}
