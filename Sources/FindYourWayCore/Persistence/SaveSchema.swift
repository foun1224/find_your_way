import Foundation

/// 當前存檔 schema 版本（ADR-007）。只增欄位、給預設值，優先向後相容；
/// 破壞性改動才升版本，並在 `Migrations/` 補對應遷移器。
public enum SaveSchema {
    /// v1 → v2（`09_PHASE3_SPEC.md` §2.5）：新增 `eventsEncountered` / `companionJoined`。
    public static let currentVersion: Int = 2
}
