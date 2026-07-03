import Foundation

/// 純資料模型（Codable）：里程/地標/時間戳/成長量/schemaVersion。
/// **只增不減原則**（紅線一）：所有欄位的變更方向皆單調遞增或恆等，
/// 無任何遞減路徑；此不可變式由 `SimulationRules`/`SimulationEngine`/`OfflineProgress` 保證，並由測試守住。
public struct GameState: Codable, Equatable {
    /// 對映 `SaveSchema.currentVersion`（存檔時寫入，讀檔時用於版本判斷/遷移）。
    public var schemaVersion: Int

    /// 累積里程（抽象「旅程單位」，`08` §7 P2：非螢幕點，預設不對使用者顯示原始數字）。
    public var distance: Double

    /// 已通過地標 id，有序、去重、只增。
    public var landmarksPassed: [String]

    /// 上次活躍的真實時鐘（Unix 秒），由呼叫端以 `TimeProvider.now` 寫入。
    public var lastActiveTimestamp: Double

    /// 成長量（Phase 2 用連續量，顯性等級呈現留待 Phase 3，`08` §7 P5）。
    public var growth: Double

    public init(
        schemaVersion: Int = SaveSchema.currentVersion,
        distance: Double = 0,
        landmarksPassed: [String] = [],
        lastActiveTimestamp: Double = 0,
        growth: Double = 0
    ) {
        self.schemaVersion = schemaVersion
        self.distance = distance
        self.landmarksPassed = landmarksPassed
        self.lastActiveTimestamp = lastActiveTimestamp
        self.growth = growth
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case distance
        case landmarksPassed
        case lastActiveTimestamp
        case growth
    }

    /// 手動解碼：缺欄位（例如舊存檔/新增欄位前寫入的檔案）一律回退到合理預設值，
    /// 對映 `04` §5.2「只增欄位、給預設值，優先向後相容」原則（`08` §6 T5/T4）。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? SaveSchema.currentVersion
        distance = try container.decodeIfPresent(Double.self, forKey: .distance) ?? 0
        landmarksPassed = try container.decodeIfPresent([String].self, forKey: .landmarksPassed) ?? []
        lastActiveTimestamp = try container.decodeIfPresent(Double.self, forKey: .lastActiveTimestamp) ?? 0
        growth = try container.decodeIfPresent(Double.self, forKey: .growth) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(distance, forKey: .distance)
        try container.encode(landmarksPassed, forKey: .landmarksPassed)
        try container.encode(lastActiveTimestamp, forKey: .lastActiveTimestamp)
        try container.encode(growth, forKey: .growth)
    }
}
