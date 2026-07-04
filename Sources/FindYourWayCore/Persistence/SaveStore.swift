import Foundation

/// 讀寫 Application Support 存檔（ADR-007）：atomic 寫入 + `.bak` 備份 + 回退。
///
/// - **save**：若現存 `save.json` 有效，先複製為 `save.bak.json`（保住上一份好檔），
///   再以 `Data.write(options: .atomic)` 寫入新內容。
/// - **load**：讀 `save.json`；失敗（不存在/解碼失敗/未來版本）→ 回退 `save.bak.json`；
///   兩者皆失敗 → 回傳 `nil`（呼叫端以新 `GameState` 起步，不崩潰、不覆寫式毀損）。
public struct SaveStore {
    private let paths: SavePaths
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(paths: SavePaths) {
        self.paths = paths
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    /// 寫入存檔。回傳是否成功（呼叫端可視需要記錄失敗，但不應因此崩潰）。
    @discardableResult
    public func save(_ state: GameState) -> Bool {
        do {
            try paths.ensureDirectoryExists()
            backupExistingSaveIfValid()

            // 誠實標版：寫檔前把 schemaVersion 校正為當前版本，避免「資料已是 v2 結構、
            // 欄位卻仍寫成舊版號」的說謊。additive 欄位靠 `GameState` 的 decodeIfPresent 向後相容，
            // migration 尚未接進 load runtime（待未來破壞性改動才接線）。
            var stamped = state
            stamped.schemaVersion = SaveSchema.currentVersion

            let data = try encoder.encode(stamped)
            try data.write(to: paths.saveFileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// 讀取存檔：`save.json` → 失敗回退 `.bak` → 兩者皆壞回傳 `nil`。
    public func load() -> GameState? {
        if let state = decodeValidState(at: paths.saveFileURL) {
            return state
        }
        return decodeValidState(at: paths.backupFileURL)
    }

    // MARK: - Private

    private func backupExistingSaveIfValid() {
        let saveURL = paths.saveFileURL
        guard decodeValidState(at: saveURL) != nil else { return }
        let backupURL = paths.backupFileURL
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.copyItem(at: saveURL, to: backupURL)
    }

    private func decodeValidState(at url: URL) -> GameState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let state = try? decoder.decode(GameState.self, from: data) else { return nil }
        // 安全降級（`04` §5.2）：未來版本的存檔不強行讀取，視同壞檔以觸發回退/新起步。
        guard state.schemaVersion <= SaveSchema.currentVersion else { return nil }
        return state
    }
}
