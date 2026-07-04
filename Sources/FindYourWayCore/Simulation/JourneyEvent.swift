import Foundation

/// A 類里程事件（`09_PHASE3_SPEC.md` §2.2/§2.3）：沿里程軸的靜態、確定性事件表。
/// 與 `Landmark` 完全同構——只看里程、不擲骰、authored 固定表（§2.5 E5）。
/// **只給情感/敘事回饋，零功利**（ADR-006）：無任何資源/加速/解鎖欄位。
public enum JourneyEventKind: String, Codable, Equatable {
    /// 風景高光。
    case scenicHighlight
    /// 紮營/休息。
    case rest
    /// 小相遇。
    case encounter
    /// 旅伴相遇（peak event，`09` §3）。
    case companionMeet
}

public struct JourneyEvent: Equatable {
    /// 穩定識別碼，存進 `GameState.eventsEncountered`。
    public let id: String

    /// 事件類型（僅供呈現分類，不影響觸發邏輯）。
    public let kind: JourneyEventKind

    /// 該事件所在的累積里程（旅程單位）。
    public let distance: Double

    /// 旅程日誌文案：留白可投射語氣（`02` §5），純情感/敘事、零量化施壓。
    public let logText: String

    public init(id: String, kind: JourneyEventKind, distance: Double, logText: String) {
        self.id = id
        self.kind = kind
        self.distance = distance
        self.logText = logText
    }

    /// Phase 3 authored 固定事件表（`09` §10.2，定案）：稀疏（~每 1.5–2h 一個），
    /// 依里程排序（遞增），供 `SimulationRules.events(crossedFrom:to:)` 掃描。
    public static let all: [JourneyEvent] = [
        JourneyEvent(
            id: "wildflower_slope",
            kind: .scenicHighlight,
            distance: 43_200,
            logText: "路過一片開得正好的野花坡。"
        ),
        JourneyEvent(
            id: "streamside_rest",
            kind: .rest,
            distance: 129_600,
            logText: "在溪邊歇了歇腳，水很涼。"
        ),
        JourneyEvent(
            id: "bird_on_stone",
            kind: .encounter,
            distance: 216_000,
            logText: "一隻鳥停在石上，看了你一會兒，才飛走。"
        ),
        JourneyEvent(
            id: "cloud_shadows",
            kind: .scenicHighlight,
            distance: 302_400,
            logText: "雲影慢慢掠過整片草原。"
        ),
        JourneyEvent(
            id: "small_campfire",
            kind: .rest,
            distance: 388_800,
            logText: "夜裡生了一小堆火，聽了一會兒柴響。"
        )
    ]
}
