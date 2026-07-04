import Foundation
import SpriteKit
#if canImport(AppKit)
import AppKit
#endif

/// Phase 2 場景：消費 `GameState`，世界依里程捲動（ADR-009），回歸時播離線呈現。
/// 照 `04` §2.3：`backgroundColor = .clear`、`scaleMode = .resizeFill`。
public final class GameScene: SKScene {

    /// 低頻模擬 tick 間隔（秒）。`08` §7 P7 provisional：2 秒，帶大 tolerance 讓系統合併喚醒（由呼叫端的 Timer/SKView 設定）。
    public static let tickInterval: Double = 2.0

    private var character: CharacterNode?
    private var companion: CompanionNode?
    private var landmarkNodes: [String: SKNode] = [:]

    // MARK: - 地域背景/地面/道具 + Blend Zone crossfade（Stage B，`18_STAGE_B_SPEC.md` §3）

    /// 目前顯示中的地域視覺集合（背景四層 + 該地域道具，見 `ParallaxBackground.RegionVisuals`）。
    /// `nil` 代表美術資源缺失、已降級為 `buildFallbackFlatColors` 純色滿版（`usingFallbackBackground`）。
    private var currentRegionVisuals: ParallaxBackground.RegionVisuals?
    private var currentRegionType: RegionType?

    /// Blend Zone 內才存在的「即將進入的下一地域」視覺集合；zone 外恆為 `nil`。
    /// `container.zPosition` 固定設為 `Self.nextRegionZOffset`（略為靠後），`container.alpha`
    /// 恆為 1（永遠不透明）；由 `currentRegionVisuals` 的 alpha 從 1 降到 0 蓋在它前面淡出，
    /// 揭露出下一地域——這樣任一時刻疊起來的可視區域都是滿版不透明，不會露出視窗背後的桌面
    /// （`03` §2.3 透明視窗）也不會有 jolt（`18` §3 無 jolt）。
    private var nextRegionVisuals: ParallaxBackground.RegionVisuals?
    private var nextRegionType: RegionType?

    /// `nextRegionVisuals.container` 相對 `currentRegionVisuals.container`（zPosition 0）
    /// 略靠後的偏移量：小到不會跨過各背景層本身的 zPosition 間距（≥5，見 `ParallaxBackground`），
    /// 只用來確保「下一地域」永遠疊在「當前地域」後面。
    private static let nextRegionZOffset: CGFloat = -0.5

    /// `true` 代表找不到任何地域美術、已降級為 Phase 2 純色滿版；此時不跑地域切換/Blend Zone 邏輯
    /// （純色背景本來就不分地域，維持 Phase 2 行為，不 crash）。
    private var usingFallbackBackground = false

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

    // MARK: - 季節 + 相遇卡（Stage A，`16_STAGE_A_SPEC.md` §1/§2）：純裝飾氛圍層，不入 `GameState`。

    /// 季節色調 overlay：依 `Season.tint(atDistance:)`（純函式）套色，每幀依 `displayedDistance` 更新
    /// （連續函式，慢、無跳變，同晝夜 tint 範式）。`motionEnabled == false` 時維持中性（不套色）。
    private var seasonOverlay: SKSpriteNode?

    private var lastUpdateTime: TimeInterval?
    private var timeSinceLastTick: Double = 0
    private var pendingOutcome: OfflineOutcome?

    /// 單幀時間 clamp 上限（秒）：避免掉幀/尖峰 `dt`（例如系統短暫卡頓）讓 `displayedDistance`
    /// 單幀跳一大步，看起來像瞬移。正常幀遠低於此值（60fps ≈ 0.0167s），只在異常時生效。
    private static let maxFrameDt: Double = 0.25

    /// 極小漂移校正的比例增益（每秒收斂比例，見 `advanceDisplayedDistance` 說明）：只是安全網，
    /// 修正因 `maxFrameDt` clamp 或浮點誤差累積造成的 `displayedDistance`/`gameState.distance` 微小落差，
    /// 用連續比例修正（類似臨界阻尼）而非硬設，確保不會產生可見跳動。
    private static let driftCorrectionGain: Double = 2.0

    /// `true` 表示目前有一段捲動補間 `SKAction` 正在跑（`presentReturnCatchUp` 的離線回歸、
    /// `catchUpDisplayedDistance` 的偶爾看你結束追趕）：此時每幀推進讓路給補間動畫全權主導
    /// `displayedDistance`，避免兩邊同時寫入互相打架、抵銷補間的加速/緩動曲線。
    private var isCatchUpActive = false

    // MARK: - 點角色微互動（Phase 4d，`12` §5 / ADR-006 嚴格零功利：純情感、不入 `GameState`）

    /// 防連點節流：避免狂點洗版式重複觸發動畫（不是「不能點」，只是同一瞬間只播一次）。
    private static let warmResponseCooldown: TimeInterval = 0.6
    private var lastWarmResponseTime: TimeInterval = -1000

    // MARK: - 主角自主微行為：偶爾看你（`13_PSYCH_AUDIT.md` P1 / `02` §2, §6）

    private static let heroRestScheduleKey = "heroRestSchedule"

    /// 主角是否正在「偶爾看你」休息中：休息期間**只凍結世界視覺捲動（`displayedDistance`）**，
    /// 絕不能凍結 `GameState.distance` 的推進（不變式，見 `performTick`）。
    private var isCharacterResting = false

    // MARK: - 靠近 / 游標回應性（`13_PSYCH_AUDIT.md` P2 / `02` §4，ADR-006 嚴格零功利）

    /// 上一輪 `notifyCursorNear`/`notifyCursorFar` 評估時，游標是否在感應圈內（供
    /// `ProximityAwareness.shouldAcknowledge` 做邊緣觸發判斷）。由 `ClickThroughController` 驅動。
    private var wasCursorNear = false
    private var lastProximityAcknowledgeTime: Double = -.infinity

    private let rules: SimulationRules
    private let timeProvider: TimeProvider

    /// 目前的權威模擬狀態（每次 tick 更新）。
    public private(set) var gameState: GameState

    /// 目前實際畫在畫面上的里程（回歸呈現時會與 `gameState.distance` 短暫不同，用於補間動畫）。
    private var displayedDistance: Double

    /// 每次 tick 推進後呼叫，供 executable 層節流存檔（`08` §3.6 存檔時機）。
    public var onStateChanged: ((GameState) -> Void)?

    /// reduce-motion 消費檢查點（`10` §4.3 / §9.2 步驟 7）：`false` 時關閉晝夜 tint 漸變、粒子，
    /// 以及角色/旅伴的裝飾性位移/縮放微行為（呼吸、暖心回應的跳動、旅伴偶爾看你的縮放）與
    /// 世界捲動補間（離線回歸/偶爾看你結束後的追趕，見 `presentReturnCatchUp`/`catchUpDisplayedDistance`）
    /// ——這些連續橫向捲動對前庭敏感使用者是典型的暈動誘因，reduce motion 時改為瞬間到位
    /// （`03` §1.5、WCAG 2.3.3）。角色的「看你」轉身（alpha 淡入淡出、無位移）與旅程日誌 toast
    /// （純 alpha 淡入淡出）不受影響——它們本就只用 opacity，符合「降低動態保留 opacity 過場」準則。
    public var motionEnabled: Bool = true {
        didSet {
            guard motionEnabled != oldValue else { return }
            character?.reducedMotion = !motionEnabled
            companion?.reducedMotion = !motionEnabled
            for visuals in [currentRegionVisuals, nextRegionVisuals] {
                guard let visuals else { continue }
                for (node, _) in visuals.npcNodes {
                    node.reducedMotion = !motionEnabled
                }
            }
        }
    }

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
        let initialRegion = Self.debugRegionOverride() ?? Region.at(distance: displayedDistance)
        if let visuals = ParallaxBackground.buildRegion(initialRegion.assetFolder, in: self, size: size, reducedMotion: !motionEnabled) {
            currentRegionVisuals = visuals
            currentRegionType = initialRegion
        } else {
            ParallaxBackground.buildFallbackFlatColors(in: self, size: size)
            usingFallbackBackground = true
        }

        // ADR-009：角色固定於畫面左側、原地走路，不再左右 roam。
        // screenY 對齊地面平台頂線（`ParallaxBackground.groundDisplayHeight`），
        // 讓角色（anchorPoint 腳邊）看起來站在地面上，而非懸空/陷入。
        let screenX = WorldScroll.characterScreenX(sceneWidth: Double(size.width))
        let screenY = Double(ParallaxBackground.groundDisplayHeight)
        let node = CharacterNode(screenX: screenX, screenY: screenY, reducedMotion: !motionEnabled)
        node.zPosition = 10
        addChild(node)
        character = node

        buildLandmarkNodes()
        buildAtmosphereOverlays()
        applyWorldScroll(distance: displayedDistance)
        scheduleNextHeroRest()

        // 若載入的存檔已相遇過旅伴，直接常態呈現同行（不重播 peak，peak 只在「當下相遇」發生一次）。
        if gameState.companionJoined {
            addCompanionNodeIfNeeded(animateIn: false)
        }
    }

    /// `FYW_DEBUG_REGION`（`meadow`/`kingdom`/`sea_city`，海城也接受 `seacity` 別名）：
    /// 強制指定地域，方便 Fable 截圖三地域畫面不必真的走 8h（`18_STAGE_B_SPEC.md` §4 /
    /// `19_STAGE_C_SPEC.md` §4）。只影響「一開始顯示哪個地域」；不指定時照常依
    /// `displayedDistance` 算，之後仍會隨里程正常交替/Blend（本旗標不凍結地域）。
    /// 美術大改版第 1 波（`21_ASSET_OVERHAUL_PLAN.md` §4）：`meadowOrigin` 的美術資源夾
    /// 已改成 `"grassland"`（見 `RegionType.assetFolder`），故也接受 `"grassland"` 別名，
    /// 方便 Fable 截圖時直接用新名稱；`"meadow"` 仍保留（`RegionType` case 名稱本身沒變）。
    private static func debugRegionOverride() -> RegionType? {
        guard let raw = ProcessInfo.processInfo.environment["FYW_DEBUG_REGION"] else { return nil }
        switch raw.lowercased() {
        case "meadow", "grassland": return .meadowOrigin
        case "kingdom": return .kingdom
        case "sea_city", "seacity": return .seaCity
        default: return nil
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


    /// L6 氛圍層（`03` §2.4）：晝夜 tint + 天氣 overlay，兩張覆蓋全畫面的 `SKSpriteNode`，
    /// zPosition 高於場景/角色（40 一族）、低於旅程日誌 toast（100），blend 為預設 `.alpha`
    /// （克制的半透明疊色，不用 `.multiply` 以免在夜間把暗部壓到看不清角色，`12` §7 風險）。
    private func buildAtmosphereOverlays() {
        // 季節 tint：疊在晝夜/天氣之外的獨立一層（`16` §1.1/§4），zPosition 39（在晝夜 40 之下，
        // 三條慢軸各自一層疊加：晝夜綁現實時間 × 季節綁里程 × 天氣，彼此不互相覆寫）。
        let season = SKSpriteNode(color: .white, size: size)
        season.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        season.position = CGPoint(x: Double(size.width) / 2.0, y: Double(size.height) / 2.0)
        season.zPosition = 39
        season.colorBlendFactor = 1.0
        season.alpha = 0
        addChild(season)
        seasonOverlay = season

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
        seasonOverlay?.size = size
        seasonOverlay?.position = center
        dayNightOverlay?.size = size
        dayNightOverlay?.position = center
        weatherOverlay?.size = size
        weatherOverlay?.position = center
    }

    public override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        updateAtmosphere()
        updateSeasonOverlay()
        defer { lastUpdateTime = currentTime }
        guard let last = lastUpdateTime else { return }
        let dt = currentTime - last
        guard dt > 0 else { return }

        // 世界捲動每幀連續推進（修 `一頓一頓`：先前只在 2 秒 tick 時把 `displayedDistance`
        // 硬設成 `gameState.distance`，世界因此每 2 秒跳一格）。`gameState.distance` 仍完全
        // 由下面的低頻 `performTick` 推進，供事件/章節/相遇/存檔/離線續用；兩者是同一個
        // 「speed × 經過秒數」積分式，長期會自然貼合，這裡只是把「畫面呈現」的積分頻率
        // 從每 2 秒一次改成每幀一次。
        advanceDisplayedDistance(frameDt: dt)

        timeSinceLastTick += dt
        if timeSinceLastTick >= Self.tickInterval {
            performTick(dt: timeSinceLastTick)
            timeSinceLastTick = 0
        }
    }

    /// 每幀把 `displayedDistance` 平滑推進 `rules.speed * frameDt`，並套用世界捲動——這是背景/
    /// 地標/道具/地域連續平滑捲動的核心（角色原地走路的 `SKAction` 本就連續，現在世界捲動也連續）。
    ///
    /// 三種情況讓路、不在這裡推進：
    /// - `isCharacterResting`（偶爾看你）：世界視覺凍結，`gameState.distance` 照常推進，
    ///   結束由 `endHeroRest` → `catchUpDisplayedDistance` 平滑追回（不變式，見該處註解）。
    /// - `isCatchUpActive`：有一段補間 `SKAction` 正在主導 `displayedDistance`（離線回歸/看你
    ///   結束追趕），讓補間自己的緩動曲線說了算，避免兩邊同時寫值互相打架。
    /// - `frameDt <= 0`：無時間經過，無事可做。
    private func advanceDisplayedDistance(frameDt: Double) {
        guard !isCharacterResting, !isCatchUpActive, frameDt > 0 else { return }

        let clampedDt = min(frameDt, Self.maxFrameDt)
        displayedDistance += rules.speed * clampedDt

        // 漂移校正只在「真脫節」時介入，且留一個死區——這是修「頓格」的關鍵。
        // `displayedDistance` 每幀等速推進（= 平滑）；`gameState.distance` 每 2 秒才跳一次（階梯）。
        // 兩者本是同一條 speed×時間 積分曲線、只差取樣頻率，故正常運行時 displayed 會固定「領先」
        // gameState 最多一個 tick 份（speed×tickInterval ≈ 24 單位）——這是正常相位差，不該校正。
        // 舊版每幀把 displayed 拉向階梯狀的 gameState，等於在每個 2 秒週期內把它拉停再放竄，
        // 產生可見的「滑—停—竄」脈動（頓格）。改為：只有 |drift| 超過死區容差（1.5 個 tick 份）
        // 才視為真脫節（掉幀被 `maxFrameDt` clamp 累積、或閒置/離線邊界），且只柔和收斂「超出死區
        // 的部分」；正常運行 → 不校正 → 等速平滑、無脈動。
        let drift = gameState.distance - displayedDistance
        let driftTolerance = rules.speed * Self.tickInterval * 1.5
        if abs(drift) > driftTolerance {
            let excess = drift - (drift > 0 ? driftTolerance : -driftTolerance)
            displayedDistance += excess * min(1.0, Self.driftCorrectionGain * clampedDt)
        }

        applyWorldScroll(distance: displayedDistance)
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

    /// 每幀套用季節 tint（`16` §1）：純函式 `Season.tint(atDistance:)` 依 `displayedDistance` 算色，
    /// 連續、慢、無跳變。`motionEnabled == false`（reduce motion）時維持中性（不套色，`16` §1.2）。
    ///
    /// 支援環境變數強制指定季節，供 Fable 截圖驗收四季 tint：`FYW_DEBUG_SEASON`
    /// （`spring`/`summer`/`autumn`/`winter`；指定時直接用該季純色，略過交界插值）。
    private func updateSeasonOverlay() {
        guard let seasonOverlay else { return }

        guard motionEnabled else {
            seasonOverlay.removeAllActions()
            seasonOverlay.color = .white
            seasonOverlay.alpha = 0
            return
        }

        let tint: Palette.RGBA
        if let forced = Self.debugSeasonOverride() {
            tint = Season.tint(atDistance: Double(forced) * Season.seasonLength + Season.seasonLength * 0.1)
        } else {
            tint = Season.tint(atDistance: displayedDistance)
        }
        // 同晝夜 tint 的 alpha 教訓：color 用不透明版本，opacity 全交給 node.alpha。
        seasonOverlay.color = tint.withAlpha(1.0).skColor
        seasonOverlay.alpha = CGFloat(tint.alpha)
    }

    /// `FYW_DEBUG_SEASON` 回傳其在 `Season.cycle` 中的索引（0=spring…3=winter），供上面換算成一個
    /// 落在該季節「中段」（遠離交界模糊帶）的 distance，呈現該季 authored 純色。
    private static func debugSeasonOverride() -> Int? {
        guard let raw = ProcessInfo.processInfo.environment["FYW_DEBUG_SEASON"] else { return nil }
        switch raw.lowercased() {
        case "spring": return 0
        case "summer": return 1
        case "autumn": return 2
        case "winter": return 3
        default: return nil
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
        // 若恰好在「偶爾看你」休息期間閒置/睡眠，恢復時直接解除凍結、跳過補間直接對齊
        // （長時間睡眠後的補間不具意義），避免卡在「永遠不會結束的休息」。
        isCharacterResting = false
        // 安全網：若恰好有一段捲動補間 `SKAction` 正在跑（離線回歸/看你結束追趕，極罕見——
        // 這兩段補間都只有數秒或不到一秒），閒置/睡眠恢復要直接對齊、解除旗標，讓每幀推進
        // 從這個新基準點接手，不留著半途而廢的補間跟它打架。不用 `removeAllActions()`，
        // 那會連帶砍掉「偶爾看你」的排程動作（`scheduleNextHeroRest`），讓主角從此不再看你。
        isCatchUpActive = false
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
        // 不變式（`13_PSYCH_AUDIT.md` P1 紅線）：`GameState.distance` 的推進（上面幾行）永遠照常
        // 運作，不受「主角正在看你」影響。畫面呈現用的 `displayedDistance` **不在這裡**推進/對齊
        // ——它由 `update(_:)` 的 `advanceDisplayedDistance` 每幀連續推進（世界連續平滑捲動）；
        // 這裡若把它硬設成 `gameState.distance` 會造成世界每 2 秒跳一格（已修的一頓一頓根因）。
        // 休息期間的凍結/追趕仍由 `isCharacterResting` + `endHeroRest` → `catchUpDisplayedDistance`
        // 負責，與這裡的低頻 tick 完全解耦。
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

        // 相遇卡（Stage A，`16` §2.3）：疊加的無盡氛圍層，與上面的 story beats 並存、不搶戲。
        // `motionEnabled == false` 時不冒卡（`16` §4「受 motionEnabled 控制」）。
        if motionEnabled {
            for card in Self.encounterCards(crossedFrom: oldDistance, to: gameState.distance, companionMet: gameState.companionJoined) {
                scheduleJourneyLog(text: card.logText, after: toastDelay)
                toastDelay += 3.0
            }
        }
    }

    /// 沿里程軸掃出 `(fromDistance, toDistance]` 之間跨越的相遇卡卡槽，依序回傳選中的卡
    /// （純函式委派 `EncounterDeck`，本方法只負責把「卡槽的季節」換算成呼叫參數）。
    /// 相遇卡**不入 `GameState`、不持久化**（`16` §2.2 紅線）：這裡只是每次即時算，不記憶。
    /// - Parameter companionMet: 對應結算後的 `GameState.companionJoined`。相遇前一律排除
    ///   `.companion` 類卡（見 `EncounterDeck.card(atSlot:season:companionMet:)`）；離線回歸區間
    ///   若跨越相遇點，採「結算後 companionJoined」為準的最低限度規則：相遇後回來可含 companion
    ///   卡，相遇前不含（不逐槽細分區間前後段）。
    private static func encounterCards(crossedFrom fromDistance: Double, to toDistance: Double, companionMet: Bool) -> [EncounterCard] {
        let oldSlot = EncounterDeck.slotIndex(atDistance: fromDistance)
        let newSlot = EncounterDeck.slotIndex(atDistance: toDistance)
        guard newSlot > oldSlot else { return [] }
        return (max(oldSlot + 1, 0)...newSlot).compactMap { slot in
            let slotDistance = Double(slot) * EncounterDeck.cardSpacing
            let season = Season.at(distance: slotDistance)
            return EncounterDeck.card(atSlot: slot, season: season, companionMet: companionMet)
        }
    }

    // MARK: - 主角自主微行為：偶爾看你排程（`13_PSYCH_AUDIT.md` P1）

    /// 排程下一次「偶爾看你」：等待秒數由 `HeroRestSchedule`（純函式）依均勻亂數換算，
    /// 平均每 40–70 秒一次、帶隨機變化，避免固定節奏顯得機械。
    private func scheduleNextHeroRest() {
        let interval = HeroRestSchedule.nextIntervalSeconds(unit: Double.random(in: 0..<1))
        let wait = SKAction.wait(forDuration: interval)
        let trigger = SKAction.run { [weak self] in self?.performHeroRest() }
        run(SKAction.sequence([wait, trigger]), withKey: Self.heroRestScheduleKey)
    }

    /// 觸發一次「偶爾看你」：凍結世界視覺捲動（`isCharacterResting`）、讓角色轉為面向觀看者
    /// 停留一段隨機時間，結束後恢復走路並排程下一次。
    private func performHeroRest() {
        guard let character else {
            scheduleNextHeroRest()
            return
        }
        isCharacterResting = true
        let duration = HeroRestSchedule.restDurationSeconds(unit: Double.random(in: 0..<1))
        character.playRestLookAtViewer(
            duration: duration,
            transitionDuration: HeroRestSchedule.transitionDurationSeconds
        ) { [weak self] in
            self?.endHeroRest()
        }
    }

    /// 「看你」結束：解除凍結、把 `displayedDistance` 平滑追趕回真實的 `gameState.distance`
    /// （休息期間 `gameState.distance` 一直照常推進，只是沒有反映到畫面上），再排程下一次。
    private func endHeroRest() {
        isCharacterResting = false
        catchUpDisplayedDistance()
        scheduleNextHeroRest()
    }

    /// 平滑（ease-in-out，`HeroRestSchedule.catchUpDurationSeconds` ≈ 0.4–0.6s）把
    /// `displayedDistance` 追趕到 `gameState.distance`，不瞬間跳過去（`02` §6 無 jolt）。
    /// 休息時間短、頻率低，追趕量本身很小，補間幾乎不會被察覺為「加速」。
    private func catchUpDisplayedDistance() {
        let start = displayedDistance
        let target = gameState.distance
        guard target != start else { return }

        guard motionEnabled else {
            // Reduce-motion：跳過捲動補間，直接對齊（`03` §1.5）——持續的橫向世界捲動是
            // 典型的暈動誘因，不該在前庭敏感使用者身上播放，即使追趕量本身很小。
            displayedDistance = target
            applyWorldScroll(distance: target)
            return
        }

        isCatchUpActive = true
        let duration = HeroRestSchedule.catchUpDurationSeconds
        let catchUp = SKAction.customAction(withDuration: duration) { [weak self] _, elapsed in
            guard let self else { return }
            let progress = duration > 0 ? min(1.0, Double(elapsed) / duration) : 1.0
            self.displayedDistance = start + (target - start) * progress
            self.applyWorldScroll(distance: self.displayedDistance)
        }
        catchUp.timingMode = .easeInEaseOut
        let clearFlag = SKAction.run { [weak self] in self?.isCatchUpActive = false }
        run(SKAction.sequence([catchUp, clearFlag]))
    }

    /// 依 `WorldScroll` 把里程換算成各景物層的 wrap 捲動位置與地標螢幕位置，並依
    /// `Region.blend(atDistance:)` 驅動地域背景/道具的 Blend Zone crossfade（`18` §3）。
    /// 天空/草地為固定滿版填充，不在此捲動（`08` §4b）。
    private func applyWorldScroll(distance: Double) {
        updateRegionVisuals(distance: distance)

        for visuals in [currentRegionVisuals, nextRegionVisuals] {
            guard let visuals else { continue }
            applyScroll(to: visuals, distance: distance)
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

    /// 把某一組地域視覺（背景四層 + 該地域道具）依 `distance` 捲動到位。
    private func applyScroll(to visuals: ParallaxBackground.RegionVisuals, distance: Double) {
        for layer in visuals.layers {
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

        for (node, slot) in visuals.propNodes {
            node.position.x = CGFloat(PropScatter.screenX(for: slot, distance: distance))
        }

        for (node, slot) in visuals.npcNodes {
            node.position.x = CGFloat(KingdomNpcScatter.screenX(for: slot, distance: distance))
        }
    }

    /// 地域切換 + Blend Zone crossfade 的核心（`18` §3）：依 `Region.blend(atDistance:)`（純函式）
    /// 決定「現在該顯示哪個地域、要不要疊下一個地域淡入」，並惰性建立/回收對應的
    /// `ParallaxBackground.RegionVisuals`（找不到美術時维持現狀，不 crash）。
    ///
    /// crossfade 手法（見型別上方 `nextRegionVisuals` 的說明）：`nextRegionVisuals` 一旦建立就
    /// 恆為不透明（`alpha = 1`）、疊在 `currentRegionVisuals` 後面（`Self.nextRegionZOffset`）；
    /// 只讓 `currentRegionVisuals` 的 alpha 從 1 降到 0，蓋在前面淡出、露出後面的下一地域——
    /// 任一時刻疊起來的可視畫面永遠是滿版不透明，沒有 jolt、也不會露出視窗背後的桌面。
    private func updateRegionVisuals(distance: Double) {
        guard !usingFallbackBackground else { return }

        // `FYW_DEBUG_REGION`：強制固定顯示某地域，略過正常的 distance-based blend 計算，
        // 方便 Fable 截圖（`18` §4）。存在期間完全不觸發 blend/切換。
        if let forced = Self.debugRegionOverride() {
            if currentRegionType != forced {
                replaceCurrentRegion(with: forced)
            }
            discardNextRegionIfAny()
            currentRegionVisuals?.container.alpha = 1
            return
        }

        let blend = Region.blend(atDistance: distance)

        guard blend.from != blend.to else {
            // Blend Zone 外：只需要 `blend.from`（== 目前地域）存在，且是唯一顯示中的一組。
            if currentRegionType != blend.from {
                if nextRegionType == blend.from, let promoted = nextRegionVisuals {
                    // 剛走出 Blend Zone：下一地域已經淡入完成，直接扶正為目前地域（無需重建）。
                    currentRegionVisuals?.container.removeFromParent()
                    promoted.container.zPosition = 0
                    currentRegionVisuals = promoted
                    currentRegionType = blend.from
                    nextRegionVisuals = nil
                    nextRegionType = nil
                } else {
                    replaceCurrentRegion(with: blend.from)
                    discardNextRegionIfAny()
                }
            } else {
                discardNextRegionIfAny()
            }
            currentRegionVisuals?.container.alpha = 1
            return
        }

        // Blend Zone 內：確保 current == from、next == to，再依 t 套用 alpha。
        if currentRegionType != blend.from {
            replaceCurrentRegion(with: blend.from)
        }
        if nextRegionType != blend.to {
            nextRegionVisuals?.container.removeFromParent()
            nextRegionVisuals = ParallaxBackground.buildRegion(blend.to.assetFolder, in: self, size: size, reducedMotion: !motionEnabled)
            nextRegionVisuals?.container.zPosition = Self.nextRegionZOffset
            nextRegionType = blend.to
        }
        currentRegionVisuals?.container.alpha = CGFloat(1 - blend.t)
        nextRegionVisuals?.container.alpha = 1
    }

    private func replaceCurrentRegion(with region: RegionType) {
        currentRegionVisuals?.container.removeFromParent()
        currentRegionVisuals = ParallaxBackground.buildRegion(region.assetFolder, in: self, size: size, reducedMotion: !motionEnabled)
        currentRegionVisuals?.container.zPosition = 0
        currentRegionType = region
    }

    private func discardNextRegionIfAny() {
        guard nextRegionVisuals != nil else { return }
        nextRegionVisuals?.container.removeFromParent()
        nextRegionVisuals = nil
        nextRegionType = nil
    }

    /// 離線回歸呈現（`08` §3.8 / §7 P6）：短捲動補間（≤2–3 秒）+ 一行溫柔旅程日誌。
    /// **只在有進展時出現**（呼叫端已檢查 `distanceGained > 0`）；語氣敘事留白、不量化施壓，
    /// `wasCapped` 只是內部旗標，**不呈現成損失**（紅線一/二）。
    private func presentReturnCatchUp(outcome: OfflineOutcome) {
        let startDistance = gameState.distance - outcome.distanceGained
        displayedDistance = startDistance
        applyWorldScroll(distance: displayedDistance)

        if motionEnabled {
            isCatchUpActive = true
            let catchUpDuration: TimeInterval = 2.5
            let catchUp = SKAction.customAction(withDuration: catchUpDuration) { [weak self] _, elapsed in
                guard let self else { return }
                let progress = min(1.0, Double(elapsed) / catchUpDuration)
                self.displayedDistance = startDistance + outcome.distanceGained * progress
                self.applyWorldScroll(distance: self.displayedDistance)
            }
            // 修正遺漏：`catchUpDisplayedDistance`（同檔案）的等價補間有明確設 `.easeInEaseOut`
            // 呼應「有機 Organic」（`03` §3.4：避免機械等速），這裡先前漏設、以固定速度捲動；
            // 補上讓兩處世界捲動補間的手感一致。
            catchUp.timingMode = .easeInEaseOut
            let clearFlag = SKAction.run { [weak self] in self?.isCatchUpActive = false }
            run(SKAction.sequence([catchUp, clearFlag]))
        } else {
            // Reduce-motion：跳過捲動補間，直接對齊（`03` §1.5），理由同 `catchUpDisplayedDistance`。
            displayedDistance = gameState.distance
            applyWorldScroll(distance: displayedDistance)
        }

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

        // 離線回歸的相遇卡摘要（`16` §2.3）：挑最後 1–2 張以「路過了…」呈現，不逐一列出、
        // 不做錯過清單（守低喚醒/零功利）。`motionEnabled == false` 時不呈現。
        if motionEnabled {
            let crossed = Self.encounterCards(crossedFrom: startDistance, to: gameState.distance, companionMet: gameState.companionJoined)
            for card in crossed.suffix(2) {
                scheduleJourneyLog(text: "你不在時，路過了…\(card.logText)", after: delay)
                delay += 3.0
            }
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
        let node = CompanionNode(screenX: anchorX - 34, screenY: screenY - 4, reducedMotion: !motionEnabled)
        node.zPosition = 9 // 低於主角的 10。
        addChild(node)
        companion = node

        guard animateIn else { return }

        guard motionEnabled else {
            // Reduce-motion：旅伴相遇仍是一次真實的里程碑（`GameState.companionJoined`），必須
            // 讓使用者看得到「發生了」，但拿掉縮放/光暈位移——只留 opacity 淡入到常態
            // （`CompanionNode` 的 `alpha = 0.92`），符合「保留 opacity、拿掉位移/縮放」準則。
            node.alpha = 0
            let fadeIn = SKAction.fadeAlpha(to: 0.92, duration: 1.2)
            fadeIn.timingMode = .easeOut
            node.run(fadeIn)
            return
        }

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

    // MARK: - 點角色微互動（Phase 4d，`12` §5 / `04` §2.5 策略 B / ADR-006 嚴格零功利）

    /// 判定（場景座標，左下原點，與 window/SKView 座標系一致）某點是否落在角色命中框內。
    /// 純幾何委派給 `CharacterHitTest`（可測），本方法只負責取「目前角色的實際位置/尺寸」這個
    /// 有狀態的部分。同時供本類 `mouseDown` 與執行檔層 `ClickThroughController`（動態穿透切換）
    /// 共用同一份判斷，避免「游標變手型的範圍」與「實際點得到的範圍」兜不起來。
    public func isPointOnCharacter(_ point: CGPoint) -> Bool {
        guard let character else { return false }
        return CharacterHitTest.isPointOnCharacter(
            point: point,
            characterScreenX: Double(character.position.x),
            characterScreenY: Double(character.position.y),
            characterSize: character.size,
            sceneSize: size
        )
    }

    /// 點角色 → 暖心回應（ADR-006 嚴格零功利：純情感，不碰 `GameState`/存檔/模擬）。
    ///
    /// **ADR-011（拖曳+記住位置）**：`mouseDown` 不再自動觸發暖心回應——按下角色也可能是要
    /// 「拖曳整個視窗」的起手勢。click-vs-drag 的判定（移動距離門檻）現在由執行檔層的
    /// `PetWindow`（`sendEvent` 攔截 `mouseDown`/`mouseDragged`/`mouseUp`）負責：只有放開時
    /// 確定「幾乎沒移動＝點擊」，才會呼叫這個 public 方法觸發暖心回應；移動超過門檻則視為拖曳，
    /// 由 `PetWindow` 改為移動視窗，本次不呼叫這裡。
    public func triggerWarmResponseFromConfirmedClick() {
        triggerWarmResponse()
    }

    /// 防連點節流（不是「不能點」，是同一瞬間只播一次，避免洗版式重複動畫）。
    private func triggerWarmResponse() {
        let now = timeProvider.now
        guard now - lastWarmResponseTime >= Self.warmResponseCooldown else { return }
        lastWarmResponseTime = now
        character?.playWarmResponse()
    }

    // MARK: - 靠近 / 游標回應性（`13_PSYCH_AUDIT.md` P2 / `02` §4 依附回應性，ADR-006 嚴格零功利）

    /// 判定某點是否落在「靠近感應圈」內（比點擊命中框大一圈，`ProximityAwareness.radiusPadding`）。
    /// 純幾何委派給 `ProximityAwareness`（可測），供 `ClickThroughController` 追蹤游標時呼叫。
    public func isPointNearCharacter(_ point: CGPoint) -> Bool {
        guard let character else { return false }
        return ProximityAwareness.isNear(
            point: point,
            characterScreenX: Double(character.position.x),
            characterScreenY: Double(character.position.y),
            characterSize: character.size,
            sceneSize: size
        )
    }

    /// 由 `ClickThroughController` 在每次游標移動評估後呼叫，回報「這一刻游標是否在感應圈內」。
    /// 是否真的觸發一次「察覺你來了」反應，交給純函式 `ProximityAwareness.shouldAcknowledge`
    /// 判斷（邊緣觸發 + 節流冷卻）；本方法只負責串接 runtime 狀態（`wasCursorNear`/上次觸發時間）。
    ///
    /// **嚴格零功利（ADR-006）**：這條路徑完全不碰 `GameState`/存檔/任何進度數值，
    /// 純視覺表達（`CharacterNode.playProximityAcknowledgement`）。
    public func notifyCursorNearState(_ isNear: Bool) {
        let now = timeProvider.now
        if ProximityAwareness.shouldAcknowledge(
            wasNear: wasCursorNear,
            isNear: isNear,
            now: now,
            lastAcknowledgeTime: lastProximityAcknowledgeTime
        ) {
            lastProximityAcknowledgeTime = now
            character?.playProximityAcknowledgement()
        }
        wasCursorNear = isNear
    }
}
