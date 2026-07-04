import SpriteKit

/// 主角像素美術走路動畫（Phase 4a，`12_PHASE4_SPEC.md` §1/§2，取代 Phase 1 陶紅色塊）：
/// 用 `scripts/slice_assets.py` 切出的 `Resources/art/char_hero/right_*.png` frame 做
/// `SKAction` texture 循環（~7fps，對應 `03` §2.2/2.3 悠閒節奏）。
///
/// **ADR-009**：角色固定在畫面左側、原地走路（walk-in-place），不再左右 roam。
/// 螢幕水平座標 `position.x` 在 `init` 後恆定不變；「前進」改由世界（背景/地標）向左捲動表現，
/// 由 `GameScene` 依 `WorldScroll` 對里程換算後套用到其他節點。本類只保留原地踏步的視覺表現。
///
/// 找不到美術檔案時優雅降級為 Phase 1 陶紅色塊（不 crash）。
public final class CharacterNode: SKSpriteNode {

    /// 角色顯示高度（點），與 `ParallaxBackground.groundDisplayHeight` 搭配：
    /// `anchorPoint = (0.5, 0)`，`screenY` 即角色腳邊落在地面平台頂線的位置。
    public static let displayHeight: CGFloat = 44

    /// 走路 frame 節奏（每格秒數），對應 6–8fps 的悠閒感（1/7 秒 ≈ 7fps）。
    private static let stepInterval: TimeInterval = 1.0 / 7.0

    /// 找不到美術時的佔位色塊邊長（沿用 Phase 1 尺寸）。
    private static let fallbackSize: CGFloat = 32

    /// - Parameters:
    ///   - screenX: 固定的螢幕水平位置（ADR-009：畫面左側約 20–25%，由 `WorldScroll.characterScreenX` 算出）。
    ///   - screenY: 固定的螢幕垂直位置（角色腳邊，通常對齊地面平台頂線）。
    public init(screenX: Double, screenY: Double) {
        let textures = ArtCatalog.sequentialTextures(directory: "char_hero", prefix: "right_")

        if let first = textures.first {
            let aspect = first.size().width / first.size().height
            let size = CGSize(width: Self.displayHeight * aspect, height: Self.displayHeight)
            super.init(texture: first, color: .clear, size: size)
            self.anchorPoint = CGPoint(x: 0.5, y: 0)
            self.position = CGPoint(x: screenX, y: screenY)
            runWalkAnimation(textures: textures)
        } else {
            // 優雅降級：找不到切好的美術（例如尚未執行 `scripts/slice_assets.py`）。
            super.init(
                texture: nil,
                color: Palette.travelerTerracotta.skColor,
                size: CGSize(width: Self.fallbackSize, height: Self.fallbackSize)
            )
            self.anchorPoint = CGPoint(x: 0.5, y: 0)
            self.position = CGPoint(x: screenX, y: screenY)
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("CharacterNode does not support NSCoding")
    }

    /// 走路 texture 循環：純粹「原地走路」的視覺表現，不驅動任何邏輯座標
    /// （里程由 `GameState.distance` 決定，`WorldScroll` 換算世界捲動）。
    private func runWalkAnimation(textures: [SKTexture]) {
        guard !textures.isEmpty else { return }
        for texture in textures {
            texture.filteringMode = .nearest
        }
        let animate = SKAction.animate(with: textures, timePerFrame: Self.stepInterval, resize: false, restore: false)
        run(SKAction.repeatForever(animate), withKey: "walkCycle")
    }
}
