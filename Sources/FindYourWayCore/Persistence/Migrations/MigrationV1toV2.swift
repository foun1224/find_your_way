import Foundation

/// **真實遷移**（`09_PHASE3_SPEC.md` §2.5，取代 Phase 2 的假想示範）：
/// v1 → v2，新增 `GameState.eventsEncountered` / `companionJoined`。
///
/// 原則（`04` §5.2 / `02` §4 存檔即依附載體）：只增欄位、給預設值，優先向後相容；
/// 舊資料（`distance` / `landmarksPassed` / `growth` 等）原樣保留、不丟失。
public struct MigrationV1toV2: Migration {
    public let fromVersion = 1
    public let toVersion = 2

    public init() {}

    public func migrate(_ json: [String: Any]) -> [String: Any] {
        var result = json
        result["schemaVersion"] = toVersion

        // 新欄位給預設值，不覆蓋已存在的值（向後相容原則）。
        if result["eventsEncountered"] == nil {
            result["eventsEncountered"] = [String]()
        }
        if result["companionJoined"] == nil {
            result["companionJoined"] = false
        }

        // 舊欄位（distance / landmarksPassed / lastActiveTimestamp / growth）保留不丟失，
        // 本遷移器只「增補」不「刪除」。
        return result
    }
}
