import Foundation
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
    /// 近景散落道具（Phase 4b `12` §2/§6）：純裝飾、不入 `GameState`，位置由 `PropScatter` 純函式決定。
    private var propNodes: [(node: SKSpriteNode, slot: PropScatter.Slot)] = []

    // MARK: - 晝夜光影 + 天氣（Phase 4c，`12` §3/§4）：純裝飾 L6 氛圍層，不入 `GameState`。

    /// 晝夜色調 overlay：全螢幕覆蓋、依 `DayNightCycle`（純函式）套色，`update(_:)` 每幀更新（連續函式，
    /// 逐幀更新也不會跳變）。`motionEnabled == false` 時停用漸變、維持白日中性（`03` §1.5 reduce motion）。
    private var dayNightOverlay: SKSpriteNode?
    /// 天氣 overlay：依 `Weather`（純函式）套色，僅在天氣「切換」時才變（低頻），切換時做柔和 crossfade。
    private var weatherOverlay: SKSpriteNode?
    /// 目前套用中的天氣，供偵測「是否切換」。
    private var currentWeather: WeatherKind = .clear
    /// 雨天粒子容器（緩慢雨絲，低密度）；`motionEnabled == false` 或非雨天時為 `nil`。
    private var rainLayer: SKNode?

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
        // screenY 對齊地面平台頂線（`ParallaxBackground.groundDisplayHeight`），
        // 讓角色（anchorPoint 腳邊）看起來站在地面上，而非懸空/陷入。
        let screenX = WorldScroll.characterScreenX(sceneWidth: Double(size.width))
        let screenY = Double(ParallaxBackground.groundDisplayHeight)
        let node = CharacterNode(screenX: screenX, screenY: screenY)
        node.zPosition = 10
        addChild(node)
        character = node

        buildLandmarkNodes()
        buildPropNodes()
        buildAtmosphereOverlays()
        applyWorldScroll(distance: displayedDistance)

        // 若載入的存檔已相遇過旅伴，直接常態呈現同行（不重播 peak，peak 只在「當下相遇」發生一次）。
        if gameState.companionJoined {
            addCompanionNodeIfNeeded(animateIn: false)
        }
    }

    /// 地標視覺（Phase 4b `12` §2/§6）：一支路標 sprite（`props/signpost.png`）+ 小字名稱。
    /// 找不到美術時優雅降級為 Phase 3 的純文字「◆ 名稱」（不 crash）。
    private func buildLandmarkNodes() {
        let signpostHeight: CGFloat = 46
        let signpostTexture = ArtCatalog.texture(relativePath: "props/signpost.png")

        for landmark in Landmark.all {
            let container = SKNode()
            container.zPosition = 5
            container.position.y = Double(ParallaxBackground.groundDisplayHeight)

            if let texture = signpostTexture {
                let aspect = texture.size().width / texture.size().height
                let sprite = SKSpriteNode(texture: texture)
                sprite.size = CGSize(width: signpostHeight * aspect, height: signpostHeight)
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
                container.addChild(sprite)

                let label = SKLabelNode(text: landmark.name)
                label.fontSize = 10
                label.fontColor = Palette.travelerTerracotta.skColor
                label.position = CGPoint(x: 0, y: Double(signpostHeight) + 6)
                container.addChild(label)
            } else {
                let marker = SKLabelNode(text: "◆ \(landmark.name)")
                marker.fontSize = 12
                marker.fontColor = Palette.travelerTerracotta.skColor
                container.addChild(marker)
            }

            addChild(container)
            landmarkNodes[landmark.id] = container
        }
    }

    /// 近景散落道具（Phase 4b `12` §2/§6）：純裝飾，位置由 `PropScatter`（純函式，`08`/`12` 同一套
    /// wrap 邏輯）決定，依 distance 捲動；找不到某道具美術時該槽位就不放（優雅降級，不 crash）。
    private func buildPropNodes() {
        let displayHeight: CGFloat = 34
        for slot in PropScatter.slots {
            guard let texture = ArtCatalog.texture(relativePath: "props/\(slot.propName).png") else { continue }
            let aspect = texture.size().width / texture.size().height
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: displayHeight * aspect, height: displayHeight)
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.position.y = Double(ParallaxBackground.groundDisplayHeight)
            node.zPosition = -1 // 地面之前、角色/旅伴之後（近景裝飾，`12` §2）。
            addChild(node)
            propNodes.append((node: node, slot: slot))
        }
    }

    /// L6 氛圍層（`03` §2.4）：晝夜 tint + 天氣 overlay，兩張覆蓋全畫面的 `SKSpriteNode`，
    /// zPosition 高於場景/角色（40 一族）、低於旅程日誌 toast（100），blend 為預設 `.alpha`
    /// （克制的半透明疊色，不用 `.multiply` 以免在夜間把暗部壓到看不清角色，`12` §7 風險）。
    private func buildAtmosphereOverlays() {
        let dayNight = SKSpriteNode(color: .white, size: size)
        dayNight.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        dayNight.position = CGPoint(x: Double(size.width) / 2.0, y: Double(size.height) / 2.0)
        dayNight.zPosition = 40
        dayNight.colorBlendFactor = 1.0 // texture-less color sprite 需設此才會套用 .color tint
        dayNight.alpha = 0
        addChild(dayNight)
        dayNightOverlay = dayNight

        let weather = SKSpriteNode(color: .clear, size: size)
        weather.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        weather.position = dayNight.position
        weather.zPosition = 41
        weather.colorBlendFactor = 1.0
        weather.alpha = 0
        addChild(weather)
        weatherOverlay = weather
    }

    /// 視窗尺寸變動（縮放/多螢幕）時，氛圍 overlay 需跟著填滿新尺寸，否則邊緣露出未染色的畫面。
    public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        let center = CGPoint(x: Double(size.width) / 2.0, y: Double(size.height) / 2.0)
        dayNightOverlay?.size = size
        dayNightOverlay?.position = center
        weatherOverlay?.size = size
        weatherOverlay?.position = center
    }

    public override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        updateAtmosphere()
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

    // MARK: - 晝夜光影 + 天氣的每幀套用（`12` §3/§4）

    /// 每幀套用晝夜 tint（連續函式，逐幀更新不會跳變）與偵測天氣切換。
    /// `motionEnabled == false`（reduce motion）時：停用漸變、維持白日中性、天氣強制回晴天、停用粒子
    /// （`03` §1.5、`12` §3「受 motionEnabled 控制」）。
    ///
    /// 支援環境變數強制指定時段/天氣，供 Fable 截圖驗收黎明/夜晚/雨天等畫面而不必真的等到那個時刻：
    /// `FYW_DEBUG_SECONDS_INTO_DAY`（0..<86400 的秒數）、`FYW_DEBUG_WEATHER`（`clear`/`overcast`/`rain`）。
    private func updateAtmosphere() {
        guard let dayNightOverlay, let weatherOverlay else { return }

        guard motionEnabled else {
            dayNightOverlay.removeAllActions()
            dayNightOverlay.color = .white
            dayNightOverlay.alpha = 0
            if currentWeather != .clear {
                applyWeatherChange(.clear)
            } else {
                weatherOverlay.removeAllActions()
                weatherOverlay.alpha = 0
                stopRain()
            }
            return
        }

        let secondsIntoDay = Self.debugSecondsIntoDayOverride() ?? Self.localSecondsIntoDay(unixSeconds: timeProvider.now)
        let tint = DayNightCycle.tint(forSecondsIntoDay: secondsIntoDay)
        // color 必須用不透明版本（alpha=1）：若帶 tint 自己的 alpha，SpriteKit 會與 node.alpha
        // 相乘（0.46×0.46≈0.21，再被感知為更弱）導致 tint 讀不出——這是本 overlay 曾無效的根因。
        dayNightOverlay.color = tint.withAlpha(1.0).skColor
        dayNightOverlay.alpha = CGFloat(tint.alpha)

        let weather = Self.debugWeatherOverride() ?? Weather.kind(forUnixSeconds: timeProvider.now)
        if weather != currentWeather {
            applyWeatherChange(weather)
        }
    }

    /// 換算「當日秒數」用**本機時區**（使用者實際看到的日夜，而非 UTC）。
    private static func localSecondsIntoDay(unixSeconds: Double) -> Double {
        let date = Date(timeIntervalSince1970: unixSeconds)
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        return hour * 3600 + minute * 60 + second
    }

    private static func debugSecondsIntoDayOverride() -> Double? {
        guard let raw = ProcessInfo.processInfo.environment["FYW_DEBUG_SECONDS_INTO_DAY"] else { return nil }
        return Double(raw)
    }

    private static func debugWeatherOverride() -> WeatherKind? {
        guard let raw = ProcessInfo.processInfo.environment["FYW_DEBUG_WEATHER"] else { return nil }
        switch raw.lowercased() {
        case "clear": return .clear
        case "overcast": return .overcast
        case "rain": return .rain
        default: return nil
        }
    }

    /// 天氣切換（低頻，每 `Weather.periodSeconds` 才可能變一次）：先淡出舊 tint 再換色再淡入新 tint，
    /// 避免「可見狀態下色相瞬間跳變」；`motionEnabled == false` 時直接設定不做動畫。
    private func applyWeatherChange(_ kind: WeatherKind) {
        currentWeather = kind
        guard let weatherOverlay else { return }
        let tint = Weather.overlayTint(for: kind)
        // 同 dayNight：color 用不透明版本，opacity 全交給 node.alpha（避免 color.alpha × node.alpha 相乘變透明）。
        let targetColor = tint?.withAlpha(1.0).skColor ?? .clear
        let targetAlpha = CGFloat(tint?.alpha ?? 0)

        weatherOverlay.removeAllActions()
        if motionEnabled {
            let fadeOut = SKAction.fadeAlpha(to: 0, duration: 4.0)
            let swap = SKAction.run { weatherOverlay.color = targetColor }
            let fadeIn = SKAction.fadeAlpha(to: targetAlpha, duration: 6.0)
            weatherOverlay.run(SKAction.sequence([fadeOut, swap, fadeIn]))
        } else {
            weatherOverlay.color = targetColor
            weatherOverlay.alpha = targetAlpha
        }

        if kind == .rain && motionEnabled {
            startRain()
        } else {
            stopRain()
        }
    }

    /// 低密度、緩慢的雨絲（`12` §4：加緩慢粒子）。不用 `SKEmitterNode`（需要粒子貼圖，headless/測試環境
    /// 產生貼圖需要可渲染的 view context，風險較高）；改用一組手動管理、`repeat` 位移的細長色塊，
    /// 效果相同且完全可控、無額外資源依賴。
    private static let rainDropCount = 14

    private func startRain() {
        guard motionEnabled, rainLayer == nil else { return }
        let layer = SKNode()
        layer.zPosition = 42
        for _ in 0..<Self.rainDropCount {
            let drop = SKSpriteNode(color: SKColor(white: 0.85, alpha: 0.35), size: CGSize(width: 2, height: 12))
            drop.anchorPoint = CGPoint(x: 0.5, y: 1.0)
            layer.addChild(drop)
            resetRainDrop(drop)
            animateRainDrop(drop)
        }
        addChild(layer)
        rainLayer = layer
    }

    private func resetRainDrop(_ drop: SKSpriteNode) {
        let x = Double.random(in: 0...Double(size.width))
        let y = Double(size.height) + Double.random(in: 0...80)
        drop.position = CGPoint(x: x, y: y)
    }

    /// 有機、非等速：每滴雨速度略有隨機差異（`03` §3.4「有機」原則），且刻意偏慢（緩慢雨粒子）。
    private func animateRainDrop(_ drop: SKSpriteNode) {
        let duration = Double.random(in: 3.2...4.6)
        let fall = SKAction.moveBy(x: -14, y: -(Double(size.height) + 120), duration: duration)
        fall.timingMode = .linear
        let reset = SKAction.run { [weak self, weak drop] in
            guard let drop else { return }
            self?.resetRainDrop(drop)
        }
        let chain = SKAction.run { [weak self, weak drop] in
            guard let drop else { return }
            self?.animateRainDrop(drop)
        }
        drop.run(SKAction.sequence([fall, reset, chain]))
    }

    private func stopRain() {
        guard let layer = rainLayer else { return }
        layer.children.forEach { $0.removeAllActions() }
        layer.removeAllActions()
        layer.removeFromParent()
        rainLayer = nil
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
            // Panorama 是一整條連續背景，用 `panoramaTileXs` 無縫平鋪（不可用 `wrappedX`：
            // `wrappedX` 各槽位獨立 `mod span`，會讓整片 tile 一起繞出可視範圍，背景全黑）。
            let xs = WorldScroll.panoramaTileXs(
                sceneWidth: Double(size.width),
                tileWidth: layer.tileWidth,
                distance: distance,
                layerFactor: layer.layerFactor
            )
            for (node, x) in zip(layer.nodes, xs) {
                node.position.x = CGFloat(x)
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

        for (node, slot) in propNodes {
            node.position.x = CGFloat(PropScatter.screenX(for: slot, distance: distance))
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
