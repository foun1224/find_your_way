import SpriteKit

/// 旅伴像素美術走路動畫（Phase 4b，`12_PHASE4_SPEC.md` §1/§2/§6，取代 Phase 3 佔位色塊）：
/// 用 `scripts/slice_assets.py` 切出的 `Resources/art/char_companion/right_*.png` frame 做
/// `SKAction` texture 循環（節奏同 `CharacterNode`），相遇後常態同行、walk-in-place。
///
/// **構圖主從**（ADR-004 / `09` §3.3）：主角陶紅、最前、最亮；
/// 旅伴略小、略後（呼叫端設定較低 `zPosition`）、明度略降——在場但不搶焦點。
/// **沉默、僅肢體語言、不命名**（`09` §3.4 E3）：本節點不帶任何文字/對話，
/// 只有走路節奏與偶爾的「看向主角」微行為，意義留給使用者投射。
///
/// 找不到美術檔案時優雅降級為 Phase 3 佔位色塊（不 crash）。
public final class CompanionNode: SKSpriteNode {

    /// 旅伴顯示高度（點）：略小於主角（`CharacterNode.displayHeight == 44`），
    /// 呼應「略小/略後」的構圖主從（`09` §3.3）。
    public static let displayHeight: CGFloat = 36

    /// 相遇 peak 光暈半徑沿用本值（`GameScene.addCompanionNodeIfNeeded`）。
    public static let size: CGFloat = displayHeight * 0.7

    /// 走路 frame 節奏，與主角一致（`03` §2.2/2.3 悠閒節奏，同行步調一致）。
    private static let stepInterval: TimeInterval = 1.0 / 7.0

    /// 找不到美術時的佔位色塊邊長（沿用 Phase 3 尺寸）。
    private static let fallbackSize: CGFloat = 26

    /// Reduce-motion 開關（由 `GameScene.motionEnabled` 反向驅動，`03` §1.5 / WCAG 2.3.3）：
    /// `true` 時停用「偶爾看向主角」的縮放 loop（會無限期重複觸發，等同高頻率連續動態）。
    /// 走路 texture 循環本身不受影響（那是必要的狀態表現，不是裝飾性位移/縮放）。
    public var reducedMotion: Bool {
        didSet {
            guard reducedMotion != oldValue else { return }
            if reducedMotion {
                removeAction(forKey: "lookOver")
                setScale(1.0)
            } else if action(forKey: "lookOver") == nil {
                runOccasionalLookAtCompanion()
            }
        }
    }

    /// - Parameters:
    ///   - screenX: 固定的螢幕水平位置（略後於主角，由呼叫端依 `WorldScroll` 算出）。
    ///   - screenY: 固定的螢幕垂直位置（略低於主角，構圖主從）。
    ///   - reducedMotion: 建立當下的 reduce-motion 狀態（見上方屬性說明）。
    public init(screenX: Double, screenY: Double, reducedMotion: Bool = false) {
        self.reducedMotion = reducedMotion
        let textures = ArtCatalog.sequentialTextures(directory: "char_companion", prefix: "right_")

        if let first = textures.first {
            let aspect = first.size().width / first.size().height
            let size = CGSize(width: Self.displayHeight * aspect, height: Self.displayHeight)
            super.init(texture: first, color: .clear, size: size)
            self.anchorPoint = CGPoint(x: 0.5, y: 0)
            self.position = CGPoint(x: screenX, y: screenY)
            // 明度略降：在場但不搶主角焦點（ADR-004 Consequences）。
            self.alpha = 0.92
            runWalkAnimation(textures: textures)
        } else {
            // 優雅降級：找不到切好的美術（例如尚未執行 `scripts/slice_assets.py`）。
            super.init(
                texture: nil,
                color: Palette.travelerTerracotta.skColor.withAlphaComponent(0.7),
                size: CGSize(width: Self.fallbackSize, height: Self.fallbackSize)
            )
            self.anchorPoint = CGPoint(x: 0.5, y: 0)
            self.position = CGPoint(x: screenX, y: screenY)
            self.alpha = 0.7
        }

        if !reducedMotion {
            runOccasionalLookAtCompanion()
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("CompanionNode does not support NSCoding")
    }

    /// 走路 texture 循環：與 `CharacterNode` 同節奏的原地走路視覺表現。
    private func runWalkAnimation(textures: [SKTexture]) {
        guard !textures.isEmpty else { return }
        for texture in textures {
            texture.filteringMode = .nearest
        }
        let animate = SKAction.animate(with: textures, timePerFrame: Self.stepInterval, resize: false, restore: false)
        run(SKAction.repeatForever(animate), withKey: "walkCycle")
    }

    /// 回應性微行為（`02` §4 依附回應性）：偶爾停下片刻，像是看向主角，
    /// 不帶任何文字，只是節奏上的一次小停頓（輕微放大再回復）。
    private func runOccasionalLookAtCompanion() {
        let pause = SKAction.wait(forDuration: 8, withRange: 6)
        let hold = SKAction.run { [weak self] in
            let grow = SKAction.scale(to: 1.03, duration: 0.6)
            grow.timingMode = .easeInEaseOut
            self?.run(grow) {
                let shrink = SKAction.scale(to: 1.0, duration: 0.6)
                shrink.timingMode = .easeInEaseOut
                self?.run(shrink)
            }
        }
        run(SKAction.repeatForever(SKAction.sequence([pause, hold])), withKey: "lookOver")
    }
}
