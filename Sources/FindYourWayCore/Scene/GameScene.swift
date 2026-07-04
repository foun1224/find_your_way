import SpriteKit

/// Phase 2 場景：消費 `GameState`，世界依里程捲動（ADR-009），回歸時播離線呈現。
/// 照 `04` §2.3：`backgroundColor = .clear`、`scaleMode = .resizeFill`。
public final class GameScene: SKScene {

    /// 低頻模擬 tick 間隔（秒）。`08` §7 P7 provisional：2 秒，帶大 tolerance 讓系統合併喚醒（由呼叫端的 Timer/SKView 設定）。
    public static let tickInterval: Double = 2.0

    private var character: CharacterNode?
    private var companion: CompanionNode?
    private var sceneryLayers: [ParallaxBackground.SceneryLayer] = []
    private var landmarkNodes: [String: SKNode] = [:]

    private var lastUpdateTime: TimeInterval?
    private var timeSinceLastTick: Double = 0
    private var pendingOutcome: OfflineOutcome?

    private let rules: SimulationRules
    private let timeProvider: TimeProvider

    /// 目前的權威模擬狀態（每次 tick 更新）。
    public private(set) var gameState: GameState

    /// 目前實際畫在畫面上的里程（回歸呈現時會與 `gameState.distance` 短暫不同，用於補間動畫）。
    private var displayedDistance: Double

    /// 每次 tick 推進後呼叫，供 executable 層節流存檔（`08` §3.6 存檔時機）。
    public var onStateChanged: ((GameState) -> Void)?

    /// reduce-motion 消費檢查點（`10` §4.3 / §9.2 步驟 7）：`false` 時應關閉晝夜 tint 漸變與粒子。
    /// Phase 5 尚無晝夜/粒子渲染（Phase 4 功能），此旗標先接好、供 Phase 4 上線時消費。
    public var motionEnabled: Bool = true

    /// - Parameters:
    ///   - initialState: 啟動時（已完成離線結算的）狀態。
    ///   - initialOutcome: 啟動時的離線結算結果；若 `distanceGained > 0` 會播放回歸呈現（`08` §3.8）。
    public init(
        size: CGSize,
        initialState: GameState = GameState(),
        initialOutcome: OfflineOutcome? = nil,
        rules: SimulationRules = .default,
        timeProvider: TimeProvider = SystemTimeProvider()
    ) {
        self.gameState = initialState
        self.displayedDistance = initialState.distance
        self.pendingOutcome = initialOutcome
        self.rules = rules
        self.timeProvider = timeProvider
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("GameScene does not support NSCoding")
    }

    public override func didMove(to view: SKView) {
        super.didMove(to: view)
        guard character == nil else { return }
        buildScene()

        if let outcome = pendingOutcome, outcome.distanceGained > 0 {
            presentReturnCatchUp(outcome: outcome)
        }
        pendingOutcome = nil
    }

    private func buildScene() {
        sceneryLayers = ParallaxBackground.build(in: self, size: size)

        // ADR-009：角色固定於畫面左側、原地走路，不再左右 roam。
        let screenX = WorldScroll.characterScreenX(sceneWidth: Double(size.width))
        let screenY = Double(size.height) * 0.25
        let node = CharacterNode(screenX: screenX, screenY: screenY)
        node.zPosition = 10
        addChild(node)
        character = node

        buildLandmarkNodes()
        applyWorldScroll(distance: displayedDistance)

        // 若載入的存檔已相遇過旅伴，直接常態呈現同行（不重播 peak，peak 只在「當下相遇」發生一次）。
        if gameState.companionJoined {
            addCompanionNodeIfNeeded(animateIn: false)
        }
    }

    private func buildLandmarkNodes() {
        for landmark in Landmark.all {
            let marker = SKLabelNode(text: "◆ \(landmark.name)")
            marker.fontSize = 12
            marker.fontColor = Palette.travelerTerracotta.skColor
            marker.zPosition = 5
            marker.position.y = Double(size.height) * 0.28
            addChild(marker)
            landmarkNodes[landmark.id] = marker
        }
    }

    public override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        defer { lastUpdateTime = currentTime }
        guard let last = lastUpdateTime else { return }
        let dt = currentTime - last
        guard dt > 0 else { return }

        timeSinceLastTick += dt
        if timeSinceLastTick >= Self.tickInterval {
            performTick(dt: timeSinceLastTick)
            timeSinceLastTick = 0
        }
    }

    /// 從暫停（閒置回來 / `didWake`）恢復時，走與**離線啟動相同**的 capped 補算路徑：
    /// 直接複用 `OfflineProgress.settle`（含 `min(max(gap,0), capSeconds)` 12h 上限），
    /// 讓「離線啟動 / 閒置恢復 / 睡眠喚醒」三路語意一致（`08` §4 紅線六、§3.5）。
    ///
    /// 關鍵：**把 `lastUpdateTime` 重設為 nil**，讓恢復後第一個 `update()` 只重設時間基準、
    /// 不再用「跨越整段暫停期」的大 `dt` 尖峰重複補算（避免雙重計算）。
    public func resumeWithCatchUp() {
        let (newState, outcome) = OfflineProgress.settle(gameState, now: timeProvider.now, rules: rules)
        gameState = newState
        displayedDistance = gameState.distance
        applyWorldScroll(distance: displayedDistance)

        // 重設 tick 基準，避免恢復後第一個 update 的大 dt 尖峰再補一次。
        lastUpdateTime = nil
        timeSinceLastTick = 0
        isPaused = false

        if outcome.distanceGained > 0 {
            onStateChanged?(gameState)
        }
    }

    /// 低頻模擬推進：套 `SimulationRules`（與離線結算同一套），
    /// 用真實時鐘差 `dt` 而非固定值，降頻不失真（`08` §3.3）。
    private func performTick(dt: Double) {
        // 安全網：即使發生 `dt` 尖峰（例如某條路徑漏走 `resumeWithCatchUp`），
        // 單次推進也不得超過離線上限，保證線上永遠不比離線快（紅線六）。
        let cappedDt = min(dt, OfflineProgress.capSeconds)
        let oldDistance = gameState.distance
        let (newState, _, crossedEvents, companionJustJoined) = SimulationEngine.advance(
            gameState, bySeconds: cappedDt, rules: rules
        )
        var updated = newState
        updated.lastActiveTimestamp = timeProvider.now
        gameState = updated
        displayedDistance = gameState.distance
        applyWorldScroll(distance: displayedDistance)
        onStateChanged?(gameState)

        // 章節轉場（`09` §4.1）：跨越章節門檻時在旅程日誌顯示一行（非互動）。
        let crossedChapters = GrowthStage.chaptersCrossed(from: oldDistance, to: gameState.distance)

        var toastDelay: TimeInterval = 0
        if companionJustJoined {
            presentCompanionMeetPeak()
            toastDelay += 3.0
        }
        for event in crossedEvents where event.id != Companion.meetEvent.id {
            scheduleJourneyLog(text: event.logText, after: toastDelay)
            toastDelay += 3.0
        }
        for chapter in crossedChapters {
            scheduleJourneyLog(text: chapterTransitionText(chapter), after: toastDelay)
            toastDelay += 3.0
        }
    }

    /// 依 `WorldScroll` 把里程換算成各景物層的 wrap 捲動位置與地標螢幕位置。
    /// 天空/草地為固定滿版填充，不在此捲動（`08` §4b）。
    private func applyWorldScroll(distance: Double) {
        for layer in sceneryLayers {
            for entry in layer.nodes {
                let x = WorldScroll.wrappedX(
                    baseX: entry.baseX,
                    distance: distance,
                    layerFactor: layer.layerFactor,
                    span: layer.span
                )
                entry.node.position.x = CGFloat(x)
            }
        }

        let anchorX = WorldScroll.characterScreenX(sceneWidth: Double(size.width))
        for landmark in Landmark.all {
            guard let node = landmarkNodes[landmark.id] else { continue }
            let x = WorldScroll.landmarkScreenX(
                landmarkDistance: landmark.distance,
                currentDistance: distance,
                characterAnchorX: anchorX
            )
            node.position.x = CGFloat(x)
        }
    }

    /// 離線回歸呈現（`08` §3.8 / §7 P6）：短捲動補間（≤2–3 秒）+ 一行溫柔旅程日誌。
    /// **只在有進展時出現**（呼叫端已檢查 `distanceGained > 0`）；語氣敘事留白、不量化施壓，
    /// `wasCapped` 只是內部旗標，**不呈現成損失**（紅線一/二）。
    private func presentReturnCatchUp(outcome: OfflineOutcome) {
        let startDistance = gameState.distance - outcome.distanceGained
        displayedDistance = startDistance
        applyWorldScroll(distance: displayedDistance)

        let catchUpDuration: TimeInterval = 2.5
        let catchUp = SKAction.customAction(withDuration: catchUpDuration) { [weak self] _, elapsed in
            guard let self else { return }
            let progress = min(1.0, Double(elapsed) / catchUpDuration)
            self.displayedDistance = startDistance + outcome.distanceGained * progress
            self.applyWorldScroll(distance: self.displayedDistance)
        }
        run(catchUp)

        // 逐行呈現：地標/一般旅程 → 里程事件 → 章節轉場 → 旅伴相遇（peak，若有），
        // 彼此錯開，避免同時彈出一堆訊息（洗版）。
        var delay: TimeInterval = 0
        for text in journeyLogTexts(for: outcome) {
            scheduleJourneyLog(text: text, after: delay)
            delay += 3.0
        }
        for chapter in outcome.newChapters {
            scheduleJourneyLog(text: chapterTransitionText(chapter), after: delay)
            delay += 3.0
        }

        if outcome.companionJustJoined {
            let wait = SKAction.wait(forDuration: delay)
            let peak = SKAction.run { [weak self] in self?.presentCompanionMeetPeak() }
            run(SKAction.sequence([wait, peak]))
        }
    }

    /// 章節轉場的旅程日誌樣式（`09` §4.1 章節感，非互動）：破折號包夾，與事件 toast 同機制但區別呈現。
    private func chapterTransitionText(_ chapterName: String) -> String {
        "— \(chapterName) —"
    }

    /// 延遲後顯示一行旅程日誌（與事件 toast 同機制），供錯開多行呈現。
    private func scheduleJourneyLog(text: String, after delay: TimeInterval) {
        let wait = SKAction.wait(forDuration: delay)
        let show = SKAction.run { [weak self] in self?.showJourneyLog(text: text) }
        run(SKAction.sequence([wait, show]))
    }

    /// 敘事留白語氣（`02` §5）：只說「走過了○○ / 又走了一段路」，
    /// 不用「荒廢/落後/枯萎/浪費」等施壓字眼（紅線一/二）。`wasCapped` 不呈現成損失（紅線二）。
    private func journeyLogTexts(for outcome: OfflineOutcome) -> [String] {
        var lines: [String] = []
        if let last = outcome.newLandmarks.last {
            lines.append("你不在時，走過了「\(last.name)」")
        } else if outcome.newEvents.isEmpty {
            lines.append("你不在時，又走了一段路")
        }
        for event in outcome.newEvents where event.id != Companion.meetEvent.id {
            lines.append(event.logText)
        }
        return lines
    }

    private func showJourneyLog(text: String) {
        let label = SKLabelNode(text: text)
        label.fontSize = 14
        label.fontColor = Palette.travelerTerracotta.skColor
        label.position = CGPoint(x: Double(size.width) / 2.0, y: Double(size.height) * 0.85)
        label.zPosition = 100
        label.alpha = 0
        addChild(label)

        let fadeIn = SKAction.fadeIn(withDuration: 0.4)
        let hold = SKAction.wait(forDuration: 2.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        let remove = SKAction.removeFromParent()
        label.run(SKAction.sequence([fadeIn, hold, fadeOut, remove]))
    }

    // MARK: - 旅伴相遇 peak（`09` §3.2/§3.4：暖、慢、有機，禁止 overshoot/閃爆/震動）

    /// 相遇為 peak event：暖陽金光暈 + 慢放大，數秒即散；旅伴之後常態同行（構圖主從，`09` §3.3）。
    private func presentCompanionMeetPeak() {
        addCompanionNodeIfNeeded(animateIn: true)
        showJourneyLog(text: Companion.logText)
    }

    /// 建立旅伴節點（若尚未建立）。`animateIn == true` 時播放 peak 光暈+慢放大（僅在「當下相遇」發生一次）；
    /// `animateIn == false` 用於載入已相遇存檔時直接常態呈現（不重播 peak）。
    private func addCompanionNodeIfNeeded(animateIn: Bool) {
        guard companion == nil else { return }
        let anchorX = WorldScroll.characterScreenX(sceneWidth: Double(size.width))
        let screenY = Double(size.height) * 0.25
        // 略後於主角（構圖主從：主角最前最亮，旅伴略小/略後/明度略降）。
        let node = CompanionNode(screenX: anchorX - 34, screenY: screenY - 4)
        node.zPosition = 9 // 低於主角的 10。
        addChild(node)
        companion = node

        guard animateIn else { return }

        // 暖陽金光暈：溫暖「亮起來」而非「爆一下」——慢放大、數秒即散，無 overshoot/彈跳/震動（`03` §3.4）。
        let glow = SKShapeNode(circleOfRadius: CompanionNode.size)
        glow.position = node.position
        glow.zPosition = 8
        glow.fillColor = Palette.warmSunGold.skColor
        glow.strokeColor = .clear
        glow.alpha = 0
        glow.setScale(0.6)
        addChild(glow)

        node.alpha = 0
        node.setScale(0.85)
        let nodeFadeIn = SKAction.group([
            SKAction.fadeAlpha(to: 0.7, duration: 1.6),
            SKAction.scale(to: 1.0, duration: 1.6)
        ])
        nodeFadeIn.timingMode = .easeOut
        node.run(nodeFadeIn)

        let glowFadeIn = SKAction.group([
            SKAction.fadeAlpha(to: 0.35, duration: 1.4),
            SKAction.scale(to: 1.6, duration: 1.4)
        ])
        glowFadeIn.timingMode = .easeOut
        let glowLinger = SKAction.wait(forDuration: 1.2)
        let glowFadeOut = SKAction.fadeOut(withDuration: 2.0)
        let glowRemove = SKAction.removeFromParent()
        glow.run(SKAction.sequence([glowFadeIn, glowLinger, glowFadeOut, glowRemove]))
    }
}
