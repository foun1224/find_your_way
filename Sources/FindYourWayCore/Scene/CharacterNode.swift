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

    /// 走路 frame 節奏（每格秒數）。臨時版放慢到 ~5fps 的悠閒踏步。
    private static let stepInterval: TimeInterval = 1.0 / 5.0

    /// 臨時走路幀順序（`right_*` 的索引）：現有 5 幀中 0/3/4 都是「同一隻腳跨步」、1/2 是併攏，
    /// 缺「另一隻腳往前」的幀 → 全部連播會像一直踏同一步（抖動）。此處挑「跨步(3)→併攏(2)」
    /// 做乾淨 2 拍循環，消除抖動。真正的左右交替需重生素材。空/越界時退回全部幀。
    private static let walkFrameOrder: [Int] = [3, 2]

    /// 暖心回應動作 key（Phase 4d，`12` §5 / ADR-006 嚴格零功利：純情感、不影響任何邏輯狀態）。
    private static let warmResponseKey = "warmResponse"

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
        // 臨時：依 walkFrameOrder 挑幀，避免同姿勢連播抖動；越界索引丟棄，若挑不到則退回全部幀。
        let ordered = Self.walkFrameOrder.filter { $0 >= 0 && $0 < textures.count }.map { textures[$0] }
        let frames = ordered.count >= 2 ? ordered : textures
        let animate = SKAction.animate(with: frames, timePerFrame: Self.stepInterval, resize: false, restore: false)
        run(SKAction.repeatForever(animate), withKey: "walkCycle")
    }

    /// 點角色 → 暖心回應（Phase 4d，`12` §5 / ADR-006 嚴格零功利）：一次溫和、慢、無 jolt 的
    /// 「注意到你了」小動作（輕輕一跳 + 放大再收）+ 一圈極淡暖光，數幀內就散。
    ///
    /// **絕對不**碰 `GameState`、不給任何資源/加速/解鎖——純表達，呼叫端（`GameScene`）
    /// 負責防連點節流；本方法本身也會擋掉「動作還在播放中」的重疊觸發，避免洗版式抖動。
    public func playWarmResponse() {
        guard action(forKey: Self.warmResponseKey) == nil else { return }

        let hopUp = SKAction.moveBy(x: 0, y: 5, duration: 0.3)
        hopUp.timingMode = .easeOut
        let hopDown = SKAction.moveBy(x: 0, y: -5, duration: 0.4)
        hopDown.timingMode = .easeInEaseOut
        let hop = SKAction.sequence([hopUp, hopDown])

        let growUp = SKAction.scale(to: 1.05, duration: 0.3)
        growUp.timingMode = .easeOut
        let shrink = SKAction.scale(to: 1.0, duration: 0.4)
        shrink.timingMode = .easeInEaseOut
        let pulse = SKAction.sequence([growUp, shrink])

        run(SKAction.group([hop, pulse]), withKey: Self.warmResponseKey)
        playWarmGlow()
    }

    /// 極淡暖光（可選 polish，`12` §5）：短暫、克制，不搶過角色本體的辨識度（`03` §2.4 原則）。
    private func playWarmGlow() {
        let glow = SKShapeNode(circleOfRadius: Double(size.height) * 0.55)
        glow.position = CGPoint(x: 0, y: Double(size.height) * 0.5)
        glow.zPosition = -1
        glow.fillColor = Palette.warmSunGold.skColor
        glow.strokeColor = .clear
        glow.alpha = 0
        addChild(glow)

        let fadeIn = SKAction.fadeAlpha(to: 0.22, duration: 0.35)
        fadeIn.timingMode = .easeOut
        let hold = SKAction.wait(forDuration: 0.25)
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        let remove = SKAction.removeFromParent()
        glow.run(SKAction.sequence([fadeIn, hold, fadeOut, remove]))
    }
}
