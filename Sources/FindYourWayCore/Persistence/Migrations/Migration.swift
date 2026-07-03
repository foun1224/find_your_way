import Foundation

/// 遷移器協定：作用於解碼後的 JSON 中介表示（`[String: Any]`），
/// 把 `fromVersion` 的結構升級到 `toVersion`。
/// 原則（`04` §5.2）：只增欄位、給預設值，優先向後相容；不丟失舊資料。
public protocol Migration {
    var fromVersion: Int { get }
    var toVersion: Int { get }

    /// 對輸入 JSON 物件做欄位轉換，回傳升級後的 JSON 物件。
    func migrate(_ json: [String: Any]) -> [String: Any]
}
