import Foundation

/// 沿里程軸的靜態里程碑。Phase 2 為確定性推進（無隨機事件），故地標為固定表。
public struct Landmark: Codable, Equatable {
    /// 穩定識別碼，存進 `GameState.landmarksPassed`。
    public let id: String

    /// 顯示名稱：走留白可投射的意象，不把故事說死（`02` §5）。
    public let name: String

    /// 該地標所在的累積里程（旅程單位，`08` §7 P2：抽象單位，非螢幕點）。
    public let distance: Double

    public init(id: String, name: String, distance: Double) {
        self.id = id
        self.name = name
        self.distance = distance
    }

    /// Phase 2 佔位地標表（`08` §7 P3 / §4b）：間距與 `SimulationRules.defaultSpeed` 同步放大到 86400
    /// （12 單位/秒 × 86400 ≈ 每 ~2 小時一個地標，維持 §7 P3 的節奏；離線上限 12h 約可路過 3～5 個）。
    /// 依里程排序（遞增），供 `SimulationRules.landmarks(crossedFrom:to:)` 掃描。
    public static let all: [Landmark] = [
        Landmark(id: "windy_pass", name: "風起的埡口", distance: 86_400),
        Landmark(id: "nameless_bend", name: "無名的河灣", distance: 172_800),
        Landmark(id: "old_bridge", name: "老橋頭", distance: 259_200),
        Landmark(id: "misty_forest_edge", name: "霧林邊緣", distance: 345_600),
        Landmark(id: "distant_hill_corner", name: "遠山的轉角", distance: 432_000)
    ]
}
