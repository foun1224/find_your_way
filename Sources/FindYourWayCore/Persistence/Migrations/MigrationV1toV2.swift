import Foundation

/// **示範用遷移骨架**：Phase 2 只有 v1，v2 尚不存在。
/// 本檔驗證遷移機制本身可運作（讀 `schemaVersion` → 依序跑遷移器 → 升級），
/// 供 Phase 3+ 真正加欄位時有樣板可循。**不進入實際讀寫路徑**（`SaveStore` 只認識 v1）。
///
/// 假想情境：v2 把 `growth: Double` 拆為 `growthStages: [String]`。
/// 遷移器示範「給預設、不丟資料」——保留舊的 `growth` 數值欄位，
/// 同時補上新欄位 `growthStages` 的合理預設值（空陣列）。
public struct MigrationV1toV2: Migration {
    public let fromVersion = 1
    public let toVersion = 2

    public init() {}

    public func migrate(_ json: [String: Any]) -> [String: Any] {
        var result = json
        result["schemaVersion"] = toVersion

        // 新欄位給預設值，不覆蓋已存在的值（向後相容原則）。
        if result["growthStages"] == nil {
            result["growthStages"] = [String]()
        }

        // 舊欄位 `growth` 保留不丟失，示範遷移器只「增補」不「刪除」。
        return result
    }
}
