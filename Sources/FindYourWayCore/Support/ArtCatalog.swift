import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(SpriteKit)
import SpriteKit
#endif

/// 像素美術資源目錄（Phase 4a，`12_PHASE4_SPEC.md` §1/§2）：從 `Resources/art/` 載入貼圖。
///
/// 不透過 SwiftPM `resources:`/`Bundle.module`（`Resources/art` 位在 repo 根目錄，
/// 與 `Sources/FindYourWayCore` 平行，非 target 子目錄），改用兩段式尋找：
/// 1. **封裝後的 .app**：`Bundle.main.resourceURL/art`（由 `scripts/build_app.sh` 複製進去）。
/// 2. **開發模式**（`swift run` / `swift test`）：從本檔案原始碼路徑往上找到 repo 根目錄的 `Resources/art`。
/// 找不到時回傳 nil／空陣列，呼叫端需優雅降級（不 crash），避免美術缺檔讓遊戲整個打不開。
public enum ArtCatalog {

    public static func resourceDirectory() -> URL? {
        #if canImport(AppKit)
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("art", isDirectory: true),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        #endif
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent("Resources/art", isDirectory: true)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

#if canImport(SpriteKit) && canImport(AppKit)
    /// 載入單張貼圖（像素風強制 `filteringMode = .nearest`）。找不到檔案時回傳 nil。
    public static func texture(relativePath: String) -> SKTexture? {
        guard let dir = resourceDirectory() else { return nil }
        let url = dir.appendingPathComponent(relativePath)
        guard let image = NSImage(contentsOf: url) else { return nil }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    /// 依序載入 `directory/prefix0.png, prefix1.png, ...` 直到找不到為止（走路 frame 序列）。
    public static func sequentialTextures(directory: String, prefix: String) -> [SKTexture] {
        var textures: [SKTexture] = []
        var i = 0
        while let texture = texture(relativePath: "\(directory)/\(prefix)\(i).png") {
            textures.append(texture)
            i += 1
        }
        return textures
    }
#endif
}
