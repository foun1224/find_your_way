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

    // MARK: - 待機呼吸（`13_PSYCH_AUDIT.md` P1 / `02` §2 社會臨場感、§6 低喚醒）

    /// 呼吸 scale 振幅：1.0 ↔ 1.0+此值。刻意極小，克制到幾乎不可察覺，只傳達「活著」的訊息，
    /// 不能像卡通彈跳（§6 無 jolt）。
    private static let breathScaleAmplitude: CGFloat = 0.012

    /// 呼吸一個完整週期（吸+吐）的秒數，慢、有機。
    private static let breathPeriodSeconds: TimeInterval = 3.6

    private static let breathingKey = "breathing"

    // MARK: - 偶爾看你 / 靠近感應共用的「看向觀看者」動作（`13_PSYCH_AUDIT.md` P1/P2）

    /// 走路 ↔ 看你 的過場淡入淡出時，中途的最低 alpha（不是全透明，只是柔和地「暗一下」，
    /// 用 alpha 而非 scale 做過場，避免與 `breathing` 的 scale action 互相打架）。
    private static let restTransitionDimAlpha: CGFloat = 0.55

    private static let restKey = "restLookAtViewer"

    /// 向右走路 frame（保存供「看你」結束後轉回走路使用）。
    private var rightTextures: [SKTexture] = []

    /// 向前（面向觀看者）frame（`scripts/slice_assets.py` 的 `HERO_FRONT_ROW`）：供「偶爾看你」
    /// 與「靠近感應」共用。找不到時（素材尚未切出）優雅降級為「不做轉身，只停頓」。
    private var frontTextures: [SKTexture] = []

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
            self.rightTextures = textures
            self.frontTextures = ArtCatalog.sequentialTextures(directory: "char_hero", prefix: "front_")
            runWalkAnimation(textures: textures)
            runBreathing()
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

    /// 待機呼吸（`13_PSYCH_AUDIT.md` P1）：極緩的 scale 起伏，永遠疊在走路/看你之上，
    /// 傳達「活著」——刻意克制到幾乎不可察覺，不能是卡通式彈跳（`02` §6 低喚醒）。
    /// 走路用的 texture 循環（`walkCycle`）只改 texture、不動 scale，兩者互不衝突可同時跑。
    private func runBreathing() {
        let inhale = SKAction.scale(to: 1.0 + Self.breathScaleAmplitude, duration: Self.breathPeriodSeconds / 2)
        inhale.timingMode = .easeInEaseOut
        let exhale = SKAction.scale(to: 1.0, duration: Self.breathPeriodSeconds / 2)
        exhale.timingMode = .easeInEaseOut
        run(SKAction.repeatForever(SKAction.sequence([inhale, exhale])), withKey: Self.breathingKey)
    }

    /// 偶爾停下看你 / 靠近感應 共用的「轉為面向觀看者」動作（`13_PSYCH_AUDIT.md` P1/P2，
    /// `02` §2 社會臨場感、§6 無 jolt）：暫停走路 texture 循環 → 淡入淡出過場到 `front_` 幀
    /// → 停留 `duration` 秒（呼吸持續疊加）→ 淡回 `right_` 幀 → 恢復走路。
    ///
    /// 過場用 alpha 淡出/淡入而非 scale（`breathing` 已佔用 scale，兩個同時跑會互相打架），
    /// alpha 只下探到 `restTransitionDimAlpha`（不是全透明），觀感是「柔和地暗一下再亮回來」，
    /// 近似轉身、無瞬間跳動。找不到 `front_` 幀（素材未切出）時優雅降級為「純停頓，不轉身」，
    /// 仍會呼叫 `completion`，不影響排程。
    ///
    /// **零功利（ADR-006）**：本方法只碰 `SKNode` 的視覺屬性（texture/alpha），完全不碰
    /// `GameState`/存檔/任何邏輯狀態。
    public func playRestLookAtViewer(
        duration: TimeInterval,
        transitionDuration: TimeInterval,
        completion: @escaping () -> Void
    ) {
        guard action(forKey: Self.restKey) == nil else {
            // 已在看你/靠近感應中，避免重疊觸發；直接視為完成，讓呼叫端排程不卡住。
            completion()
            return
        }
        guard let frontTexture = frontTextures.first, !rightTextures.isEmpty else {
            // 素材未切出：優雅降級為純停頓（不轉身），仍走一樣的節奏。
            let wait = SKAction.wait(forDuration: duration)
            let finish = SKAction.run(completion)
            run(SKAction.sequence([wait, finish]), withKey: Self.restKey)
            return
        }

        removeAction(forKey: "walkCycle")

        let half = transitionDuration / 2
        let dimOut = SKAction.fadeAlpha(to: Self.restTransitionDimAlpha, duration: half)
        dimOut.timingMode = .easeInEaseOut
        let toFront = SKAction.run { [weak self] in self?.texture = frontTexture }
        let brightenToFront = SKAction.fadeAlpha(to: 1.0, duration: half)
        brightenToFront.timingMode = .easeInEaseOut
        let turnToFront = SKAction.sequence([dimOut, toFront, brightenToFront])

        let hold = SKAction.wait(forDuration: duration)

        let dimOutBack = SKAction.fadeAlpha(to: Self.restTransitionDimAlpha, duration: half)
        dimOutBack.timingMode = .easeInEaseOut
        let toRight = SKAction.run { [weak self] in self?.texture = self?.rightTextures.first }
        let brightenBack = SKAction.fadeAlpha(to: 1.0, duration: half)
        brightenBack.timingMode = .easeInEaseOut
        let turnBack = SKAction.sequence([dimOutBack, toRight, brightenBack])

        let resumeWalkAndComplete = SKAction.run { [weak self] in
            guard let self else { return }
            self.runWalkAnimation(textures: self.rightTextures)
            completion()
        }

        run(SKAction.sequence([turnToFront, hold, turnBack, resumeWalkAndComplete]), withKey: Self.restKey)
    }

    /// 靠近感應的短版「察覺你來了」（`13_PSYCH_AUDIT.md` P2 / ADR-006 嚴格零功利）：
    /// 重用 `playRestLookAtViewer`，只是時間短很多（`ProximityAwareness.acknowledgeDurationSeconds`）、
    /// 純情感表達，呼叫端（`GameScene`）已負責節流/冷卻，本方法不重複判斷。
    public func playProximityAcknowledgement() {
        guard action(forKey: Self.restKey) == nil else { return }
        playRestLookAtViewer(
            duration: ProximityAwareness.acknowledgeDurationSeconds,
            transitionDuration: HeroRestSchedule.transitionDurationSeconds,
            completion: {}
        )
    }

    /// 目前是否正在「看你」（偶爾休息或靠近感應皆算），供 `GameScene` 判斷是否該凍結
    /// 世界視覺捲動（`displayedDistance`）。
    public var isRestingLookAtViewer: Bool {
        action(forKey: Self.restKey) != nil
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
