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

    /// 一個完整走路循環的秒數（與幀數無關）。每格秒數 = 此值 ÷ 幀數，
    /// 這樣不論走路幀有幾張（舊 2~3 幀或新 8 幀完整循環）節奏都一致、不會因幀多變拖沓。
    /// 0.9s/循環 ≈ 悠閒但不月球漫步的散步節奏。
    private static let walkCycleDuration: TimeInterval = 0.9

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

    /// Reduce-motion 開關（由 `GameScene.motionEnabled` 反向驅動，`03` §1.5 / WCAG 2.3.3）：
    /// `true` 時停用**連續、無資訊內容的位移/縮放**裝飾動畫（呼吸 loop、暖心回應的跳動+縮放）——
    /// 這類動畫永遠在跑或可重複觸發，等同高頻率動態，對前庭敏感使用者是持續負擔。
    /// **不歸零**：`playRestLookAtViewer`／靠近感應的轉身用 alpha 淡入淡出（非位移/縮放），
    /// 暖心回應的暖光用 alpha 淡入淡出，兩者皆保留——符合「降低動態＝更少更柔，非全部拿掉，
    /// 保留有助理解的 opacity/color 過場、拿掉位移類動態」的準則。
    public var reducedMotion: Bool {
        didSet {
            guard reducedMotion != oldValue else { return }
            if reducedMotion {
                removeAction(forKey: Self.breathingKey)
                setScale(1.0)
            } else if action(forKey: Self.breathingKey) == nil {
                runBreathing()
            }
        }
    }

    /// - Parameters:
    ///   - screenX: 固定的螢幕水平位置（ADR-009：畫面左側約 20–25%，由 `WorldScroll.characterScreenX` 算出）。
    ///   - screenY: 固定的螢幕垂直位置（角色腳邊，通常對齊地面平台頂線）。
    ///   - reducedMotion: 建立當下的 reduce-motion 狀態（見上方屬性說明）。
    public init(screenX: Double, screenY: Double, reducedMotion: Bool = false) {
        self.reducedMotion = reducedMotion
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
            if !reducedMotion {
                runBreathing()
            }
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
    ///
    /// 美術大改版第 1 波（`21_ASSET_OVERHAUL_PLAN.md` §4）：`main_role.png` 「向右」欄的
    /// 3 排姿勢（站姿／跨步走／持物）本身就是三個不同姿勢，不像舊 `asset_sheet.png` 那樣
    /// 有重複/缺幀的問題，直接依序全部播放即可構成有交替感的循環，不需要再挑幀去重。
    private func runWalkAnimation(textures: [SKTexture]) {
        guard !textures.isEmpty else { return }
        for texture in textures {
            texture.filteringMode = .nearest
        }
        let timePerFrame = Self.walkCycleDuration / Double(textures.count)
        let animate = SKAction.animate(with: textures, timePerFrame: timePerFrame, resize: false, restore: false)
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

    // MARK: - P1c 陪你歇（`docs/22_COMPANIONSHIP_DESIGN.md` §4 Stage P1c）
    //
    // 與「偶爾看你」（`playRestLookAtViewer`）用同一套「轉為面向觀看者」視覺語言（同樣只用
    // alpha 淡入淡出過場，reduce-motion 安全），差別是：這裡沒有內建的固定持續時間——
    // 「陪你歇」要一直保持到 `GameScene` 判定使用者活動恢復（`PresenceSchedule.shouldRestTogether`
    // 由 `true` 轉 `false`）才呼叫 `endAwayRestPose()` 起身，可能長達數分鐘甚至更久。
    // 呼吸（`breathingKey` scale action）完全不受影響、持續疊加——這正是「有生命的休息姿態，
    // 不是凍結的走路幀」的來源（`22` §4 P1c 要求）。

    /// 進入「陪你歇」：淡出走路循環、轉為面向觀看者的姿態並停留（不會自己結束，
    /// 需呼叫 `endAwayRestPose()`）。找不到 `front_` 幀時優雅降級為「什麼都不做」——
    /// `GameScene` 仍會照常凍結世界捲動（不變式本身不依賴這裡有沒有視覺表現）。
    public func playAwayRestPose() {
        guard action(forKey: Self.restKey) == nil else { return }
        guard let frontTexture = frontTextures.first, !rightTextures.isEmpty else { return }

        removeAction(forKey: "walkCycle")

        let half = HeroRestSchedule.transitionDurationSeconds / 2
        let dimOut = SKAction.fadeAlpha(to: Self.restTransitionDimAlpha, duration: half)
        dimOut.timingMode = .easeInEaseOut
        let toFront = SKAction.run { [weak self] in self?.texture = frontTexture }
        let brightenToFront = SKAction.fadeAlpha(to: 1.0, duration: half)
        brightenToFront.timingMode = .easeInEaseOut
        run(SKAction.sequence([dimOut, toFront, brightenToFront]), withKey: Self.restKey)
    }

    /// 結束「陪你歇」：淡回走路 frame、恢復走路循環。與 `playAwayRestPose` 對稱，
    /// 同樣只用 alpha 過場（無位移/縮放）。
    public func endAwayRestPose() {
        removeAction(forKey: Self.restKey)
        guard !rightTextures.isEmpty else { return }

        let half = HeroRestSchedule.transitionDurationSeconds / 2
        let dimOutBack = SKAction.fadeAlpha(to: Self.restTransitionDimAlpha, duration: half)
        dimOutBack.timingMode = .easeInEaseOut
        let toRight = SKAction.run { [weak self] in self?.texture = self?.rightTextures.first }
        let brightenBack = SKAction.fadeAlpha(to: 1.0, duration: half)
        brightenBack.timingMode = .easeInEaseOut
        let resumeWalk = SKAction.run { [weak self] in
            guard let self else { return }
            self.runWalkAnimation(textures: self.rightTextures)
        }
        run(SKAction.sequence([dimOutBack, toRight, brightenBack, resumeWalk]), withKey: Self.restKey)
    }

    /// 睡眠／長時間離線恢復（`GameScene.resumeWithCatchUp`）的安全網：若角色仍卡在任何
    /// 「看你／陪你歇」姿態中（極罕見——例如恰好在陪你歇期間系統進入睡眠），立即reset回
    /// 正常走路，不做過場（這個情境的補間本就無意義，`resumeWithCatchUp` 對 `displayedDistance`
    /// 也是直接對齊、不補間，這裡呼應同一種「長時間中斷後直接歸零複雜狀態」原則）。
    public func forceResumeWalkingIfNeeded() {
        guard action(forKey: Self.restKey) != nil else { return }
        removeAction(forKey: Self.restKey)
        alpha = 1.0
        guard !rightTextures.isEmpty else { return }
        texture = rightTextures.first
        runWalkAnimation(textures: rightTextures)
    }

    /// P1a 歸來的溫暖：若使用者回來時旅人已經在「陪你歇」姿態中面向著你，恢復本身
    /// （起身走路）就是最自然的歡迎——這裡只補一點極輕暖光，不重播轉身（避免重疊/多餘）。
    /// 重用既有 `playWarmGlow`（純 alpha，reduce-motion 安全）。
    public func playReturnWarmGlow() {
        playWarmGlow()
    }

    /// 點角色 → 暖心回應（Phase 4d，`12` §5 / ADR-006 嚴格零功利）：一次溫和、慢、無 jolt 的
    /// 「注意到你了」小動作（輕輕一跳 + 放大再收）+ 一圈極淡暖光，數幀內就散。
    ///
    /// **絕對不**碰 `GameState`、不給任何資源/加速/解鎖——純表達，呼叫端（`GameScene`）
    /// 負責防連點節流；本方法本身也會擋掉「動作還在播放中」的重疊觸發，避免洗版式抖動。
    public func playWarmResponse() {
        guard action(forKey: Self.warmResponseKey) == nil else { return }

        guard !reducedMotion else {
            // Reduce-motion：拿掉跳動（位移）與放大再收（縮放），只留暖光的 alpha 淡入淡出——
            // 仍然給「聽到你點擊了」的回饋（Standard 1 valid purpose），但不含位移/縮放動態。
            playWarmGlow()
            return
        }

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
