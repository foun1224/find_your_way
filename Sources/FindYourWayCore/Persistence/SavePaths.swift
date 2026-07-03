import Foundation

/// 存檔路徑解析（ADR-007 / `04` §5.1）。
/// **可注入根目錄**：預設落在 `~/Library/Application Support/FindYourWay/`；
/// 測試傳入 tmp 目錄，讓 `SaveStore` 能對真實檔案系統跑 round-trip 而不污染使用者目錄。
public struct SavePaths {
    public let rootDirectory: URL

    /// - Parameter rootDirectory: 存檔根目錄。傳 `nil` 使用預設的 Application Support 子目錄。
    public init(rootDirectory: URL? = nil) {
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let base = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first ?? FileManager.default.temporaryDirectory
            self.rootDirectory = base.appendingPathComponent("FindYourWay", isDirectory: true)
        }
    }

    public var saveFileURL: URL {
        rootDirectory.appendingPathComponent("save.json")
    }

    public var backupFileURL: URL {
        rootDirectory.appendingPathComponent("save.bak.json")
    }

    /// 確保根目錄存在，寫檔前呼叫。
    public func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }
}
