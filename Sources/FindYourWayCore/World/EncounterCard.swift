import Foundation

/// 相遇卡類別（`16_STAGE_A_SPEC.md` §2.1）：僅供呈現分類，不影響選卡邏輯。
public enum EncounterCategory: String, Equatable, CaseIterable {
    case flora
    case fauna
    case food
    case scenery
    case culture
    case companion
}

/// 相遇卡（`16` §2）：純資料，B 類氛圍（`15_WORLD_STRUCTURE.md`）——**不入 `GameState`、
/// 不持久化、不收集**（守紅線：無圖鑑/無完成度）。只給情感/敘事，不給任何進度/資源（ADR-006）。
public struct EncounterCard: Equatable {
    public let id: String
    public let category: EncounterCategory
    /// 可出現的季節；空陣列 = 任何季節皆可出現。
    public let seasons: [Season]
    /// 旅程日誌一句（Fable authored voice，`16` §3，文案不得更動）。
    public let logText: String

    public init(id: String, category: EncounterCategory, seasons: [Season] = [], logText: String) {
        self.id = id
        self.category = category
        self.seasons = seasons
        self.logText = logText
    }

    /// 該卡是否可在指定季節出現：`seasons` 為空 = 任何季節皆可。
    public func isAvailable(in season: Season) -> Bool {
        seasons.isEmpty || seasons.contains(season)
    }
}
