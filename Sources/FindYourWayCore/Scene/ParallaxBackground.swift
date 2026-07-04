import SpriteKit

/// Phase 4a 背景分層（`12_PHASE4_SPEC.md` §1/§2，取代 Phase 2 純色佔位）；
/// Stage B（`18_STAGE_B_SPEC.md` §1/§3）擴充為**地域化**：每個地域一組
/// `Resources/art/regions/<region>/bg/{far,mid,fore?,ground}.png` + 該地域道具池，
/// 由遠到近堆疊，依 `WorldScroll.panoramaTileXs` 各自 `layerFactor` 做無縫水平平鋪填滿視窗寬。
/// 遠景最慢、地面最快，呈現視差深度；`filteringMode = .nearest` 保留像素邊緣。
///
/// **Blend Zone crossfade**（`18` §3）：`GameScene` 會在地域邊界前後同時持有「當前地域」與
/// 「下一地域」兩組 `RegionVisuals`，各自包在一個容器 `SKNode` 底下，呼叫端只需調整
/// 容器的 `alpha` 就能整組（背景 + 道具）一起淡入淡出，不需要逐層/逐道具處理。
///
/// 注意：這裡刻意**不**沿用 `WorldScroll.wrappedX`——`wrappedX` 是為 Phase 2「散落小草叢」
/// 這類獨立小物件的循環出現設計的（各槽位各自 `mod span`），拿來鋪一整條連續 panorama
/// 會在 `distance` 增加後讓所有 tile 一起被繞到可視範圍外、露出整片透空（Phase 4a 背景全黑
/// 的根因）。`panoramaTileXs` 改以「tile 寬度」為平鋪單位，任何 `distance` 下都保證
/// `[0, sceneWidth]` 被連續覆蓋，無縫接合。
///
/// 找不到美術資源（例如尚未執行切圖腳本）時優雅降級回 Phase 2 純色滿版，不 crash。
public enum ParallaxBackground {

    /// 可捲動景物層：一組節點依左緣連續平鋪（anchor 左下），共用 `layerFactor` 與單張顯示寬 `tileWidth`；
    /// 實際螢幕 x 由 `WorldScroll.panoramaTileXs` 算出（見 `GameScene.applyWorldScroll`）。
    public struct SceneryLayer {
        public let nodes: [SKSpriteNode]
        public let layerFactor: Double
        public let tileWidth: Double
    }

    /// 一個地域的完整視覺集合：背景圖層（far/mid/fore?/ground）+ 該地域道具，
    /// 全部掛在同一個 `container` 節點下（`18` §3：Blend Zone crossfade 只需調整 `container.alpha`）。
    public struct RegionVisuals {
        public let container: SKNode
        public let layers: [SceneryLayer]
        public let propNodes: [(node: SKSpriteNode, slot: PropScatter.Slot)]
        /// 居民 NPC 節點（Stage B+ → 美術大改版第 3 波泛用化，`02` §2 社會臨場感）：每個地域
        /// 依 `RegionNpcScatter.slots(for:)` 配置一組指定居民，尚無美術/骨架地域為 `[]`。
        public let npcNodes: [(node: NpcNode, slot: RegionNpcScatter.Slot)]
    }

    /// 地面平台的顯示高度（點）：作為整組背景的「主尺度」，遠景/中景/前景依同一縮放比例換算，
    /// 保證各層像素密度一致（避免遠景/中景/前景/地面「像素大小」不成比例）。所有地域共用同一
    /// 基準，這樣切換地域時角色腳邊的地面頂線（`CharacterNode` 站立基準）不會跳動（`18` §3
    /// 「角色仍站 groundDisplayHeight 頂線」）。
    /// `CharacterNode` 站立的基準線（`GameScene` 用本值算角色腳邊 y）。
    public static let groundDisplayHeight: CGFloat = 40

    /// 近景散落道具的顯示高度（點）：與 Phase 4b 既有數值一致，地域化後沿用同一常數。
    private static let propDisplayHeight: CGFloat = 34

    /// 依地域資料夾（`regions/<region>/`）建構背景 + 道具（`18` §1/§3）。`far`/`mid`/`ground`
    /// 為必要層，找不到任一張即回傳 `nil`（呼叫端優雅降級）；`fore` 為選用層（草原沒有前景層，
    /// 王國有旗幟石牆層——`18` §3「有 fore 的地域多一層、沒有的略過」）。
    @discardableResult
    public static func buildRegion(
        _ regionFolder: String,
        in parent: SKNode,
        size: CGSize,
        reducedMotion: Bool = false
    ) -> RegionVisuals? {
        let base = "regions/\(regionFolder)/bg/"
        guard
            let groundTexture = ArtCatalog.texture(relativePath: base + "ground.png"),
            let midTexture = ArtCatalog.texture(relativePath: base + "mid.png"),
            let farTexture = ArtCatalog.texture(relativePath: base + "far.png")
        else {
            return nil
        }
        let foreTexture = ArtCatalog.texture(relativePath: base + "fore.png")
        let region = RegionType.allCases.first { $0.assetFolder == regionFolder } ?? .meadowOrigin

        let container = SKNode()
        parent.addChild(container)

        let scale = groundDisplayHeight / groundTexture.size().height

        var layers: [SceneryLayer] = []

        // far backdrop：獨立縮放比例（與 ground 的 `scale` 脫鉤），目標是讓其顯示高度
        // 「≥ 場景高度」以填滿整個視窗（不留頂部露空），bottomY 對齊視窗底。
        let farScale = size.height / farTexture.size().height
        let far = buildLayer(
            in: container, sceneWidth: Double(size.width), texture: farTexture,
            scale: farScale, bottomY: 0, zPosition: -30, layerFactor: 0.2
        )
        layers.append(far)

        if region.isLayered {
            // 真多層視差（`20_ASSET_SHEET_SPEC.md` §8A 新美術流程驗證，`RegionType.isLayered`）：
            // mid/fore 素材是洋紅去背過的**透明**中景/前景物件層（非各自含天空的完整場景），
            // 可以直接疊在 far backdrop 之前形成正確景深，不會像舊格式那樣露出多條天空線
            // （見下方 else 分支「過渡 workaround」的歷史說明）。三層共用同一個由
            // 「地面顯示高度」換算出的 `scale`，維持像素密度一致；底緣都貼齊地面線
            // （`bottomY: 0`），只靠 `zPosition` 前後疊放順序 + 各自 `layerFactor` 呈現深度。
            let mid = buildLayer(
                in: container, sceneWidth: Double(size.width), texture: midTexture,
                scale: scale, bottomY: 0, zPosition: -20, layerFactor: 0.45
            )
            layers.append(mid)

            if let foreTexture {
                let fore = buildLayer(
                    in: container, sceneWidth: Double(size.width), texture: foreTexture,
                    scale: scale, bottomY: 0, zPosition: -15, layerFactor: 0.65
                )
                layers.append(fore)
            }
        } else {
            // `mid`/`fore` 素材本身各是一條「含自己天空的完整場景」（非可疊加延伸片段），過去把
            // far/mid/fore 依高度垂直堆疊會在畫面中同時露出多條天空+地平線、層間硬接縫，變成
            // 「橫條拼貼」而非單一連貫場景（見本檔案上方 `18` 之後、Fable 截圖診斷）。
            // 修法：只用 `far`（最遠、涵蓋最廣的完整場景）當唯一 backdrop，等比放大到「填滿場景
            // 高度」鋪滿整個視窗、慢速視差；`mid`/`fore` 仍照常存在於硬碟（其他用途/未來可能
            // 隨美術改版轉成 `isLayered` 重啟用），只是不再建節點渲染，避免視覺雜訊。`mid`
            // texture 仍在 guard 中被要求存在，作為「這是一個資源完整的地域」的完整性檢查，
            // 維持向下相容（不因拿掉 mid 渲染而放寬地域資源需求）。
            _ = midTexture
            _ = foreTexture
        }

        let ground = buildLayer(
            in: container, sceneWidth: Double(size.width), texture: groundTexture,
            scale: scale, bottomY: 0, zPosition: -10, layerFactor: 1.0
        )
        layers.append(ground)

        let propNodes = buildPropNodes(regionFolder: regionFolder, in: container)
        let npcNodes = buildNpcNodes(regionFolder: regionFolder, in: container, reducedMotion: reducedMotion)

        return RegionVisuals(container: container, layers: layers, propNodes: propNodes, npcNodes: npcNodes)
    }

    /// 近景散落道具（Phase 4b `12` §2/§6，Stage B 地域化 `18` §3）：純裝飾，位置由
    /// `PropScatter.slots(for:)`（純函式）決定，依 distance 捲動；找不到某道具美術時該槽位
    /// 就不放（優雅降級，不 crash）。
    private static func buildPropNodes(regionFolder: String, in container: SKNode) -> [(node: SKSpriteNode, slot: PropScatter.Slot)] {
        let region = RegionType.allCases.first { $0.assetFolder == regionFolder } ?? .meadowOrigin
        var result: [(node: SKSpriteNode, slot: PropScatter.Slot)] = []
        for slot in PropScatter.slots(for: region) {
            guard let texture = ArtCatalog.texture(relativePath: "regions/\(regionFolder)/props/\(slot.propName).png") else { continue }
            let aspect = texture.size().width / texture.size().height
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: propDisplayHeight * aspect, height: propDisplayHeight)
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.position.y = Double(groundDisplayHeight)
            node.zPosition = -1 // 地面之前、角色/旅伴之後（近景裝飾，`12` §2）。
            container.addChild(node)
            result.append((node: node, slot: slot))
        }
        return result
    }

    /// 地域居民 NPC（Stage B+ → 美術大改版第 3 波泛用化，`02` §2 社會臨場感）：純裝飾，位置由
    /// `RegionNpcScatter.slots(for:)`（純函式）決定，依 distance 捲動；美術改讀**共享**
    /// `Resources/art/npc/<name>.png`（不再是 `regions/<r>/npc/`——同一種 NPC 可能出現在
    /// 多個地域，見 `RegionNpcScatter` 型別註解），找不到某 NPC 美術時該槽位就不放
    /// （優雅降級，不 crash）。尚無配置的骨架地域槽位表為空，自然不會冒出任何節點。
    private static func buildNpcNodes(
        regionFolder: String,
        in container: SKNode,
        reducedMotion: Bool
    ) -> [(node: NpcNode, slot: RegionNpcScatter.Slot)] {
        let region = RegionType.allCases.first { $0.assetFolder == regionFolder } ?? .meadowOrigin
        var result: [(node: NpcNode, slot: RegionNpcScatter.Slot)] = []
        for slot in RegionNpcScatter.slots(for: region) {
            guard let texture = ArtCatalog.texture(relativePath: "npc/\(slot.npcName).png") else { continue }
            // 確定性相位偏移（非隨機）：讓不同槽位的呼吸起伏不完全同步，見 `NpcNode` 說明。
            let phaseOffset = slot.baseX.truncatingRemainder(dividingBy: NpcNode.breathPeriodSeconds)
            let node = NpcNode(texture: texture, reducedMotion: reducedMotion, breathPhaseOffset: phaseOffset)
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.position.y = Double(groundDisplayHeight)
            node.zPosition = -1 // 地面之前、角色/旅伴之後（近景裝飾，同道具層次）。
            container.addChild(node)
            result.append((node: node, slot: slot))
        }
        return result
    }

    private static func buildLayer(
        in parent: SKNode,
        sceneWidth: Double,
        texture: SKTexture,
        scale: CGFloat,
        bottomY: Double,
        zPosition: CGFloat,
        layerFactor: Double
    ) -> SceneryLayer {
        let width = Double(texture.size().width * scale)
        let height = texture.size().height * scale

        // 張數與初始位置只是起始佈局；實際張數/x 座標每次 `applyWorldScroll` 都會依
        // `WorldScroll.panoramaTileXs` 重新計算，這裡先鋪出同樣數量的節點供之後重用/搬移。
        let initialXs = WorldScroll.panoramaTileXs(
            sceneWidth: sceneWidth, tileWidth: width, distance: 0, layerFactor: layerFactor
        )

        var nodes: [SKSpriteNode] = []
        for (index, x) in initialXs.enumerated() {
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: width, height: height)
            node.texture?.filteringMode = .nearest
            node.anchorPoint = CGPoint(x: 0, y: 0)
            // 鏡像平鋪（見型別註解「無縫水平平鋪」）：奇數槽位水平翻轉（`xScale = -1`），
            // 讓每個相鄰 tile 交界處的邊緣欄永遠是同一批像素的鏡像，消除接縫（ABAB 手法）。
            // `mirroredScreenX` 同步把 anchor 從左緣換算成翻轉後的正確 x（見其說明）。
            let flipped = index % 2 == 1
            node.xScale = flipped ? -1 : 1
            node.position = CGPoint(x: CGFloat(mirroredScreenX(x, tileWidth: width, flipped: flipped)), y: CGFloat(bottomY))
            node.zPosition = zPosition
            parent.addChild(node)
            nodes.append(node)
        }
        return SceneryLayer(nodes: nodes, layerFactor: layerFactor, tileWidth: width)
    }

    /// 鏡像平鋪的 x 座標換算（`buildLayer`/`GameScene.applyScroll` 共用）：`WorldScroll.panoramaTileXs`
    /// 算出的 `x` 一律是「tile 左緣」座標，假設 `anchorPoint = (0, 0)` 且未翻轉（`xScale = 1`）時
    /// tile 佔據 `[x, x + tileWidth]`。翻轉（`xScale = -1`）時 SpriteKit 會把節點的本地座標系
    /// 繞 anchor（也就是 `position`）水平鏡射，使 tile 改佔據 `[position.x - tileWidth, position.x]`——
    /// 若仍把 `position.x` 設成 `x`，翻轉後的 tile 會整張左移一個 tile 寬，跟未翻轉時的位置對不齊、
    /// 露出縫隙/重疊。這裡把翻轉 tile 的 `position.x` 補上 `+ tileWidth`，讓翻轉後仍佔據跟未翻轉
    /// 時相同的 `[x, x + tileWidth]` 範圍，捲動位置完全不變、只有內容水平鏡射。
    static func mirroredScreenX(_ x: Double, tileWidth: Double, flipped: Bool) -> Double {
        flipped ? x + tileWidth : x
    }

    // MARK: - 找不到美術時的優雅降級（Phase 2 純色滿版）

    @discardableResult
    public static func buildFallbackFlatColors(in parent: SKNode, size: CGSize) -> [SceneryLayer] {
        let halfHeight = size.height / 2.0
        let centerX = size.width / 2.0

        let sky = SKSpriteNode(color: Palette.skyAzure.skColor, size: CGSize(width: size.width, height: halfHeight))
        sky.anchorPoint = CGPoint(x: 0.5, y: 0)
        sky.position = CGPoint(x: centerX, y: halfHeight)
        sky.zPosition = -30

        let meadow = SKSpriteNode(color: Palette.meadowGreen.skColor, size: CGSize(width: size.width, height: halfHeight))
        meadow.anchorPoint = CGPoint(x: 0.5, y: 0)
        meadow.position = CGPoint(x: centerX, y: 0)
        meadow.zPosition = -30

        parent.addChild(sky)
        parent.addChild(meadow)
        return []
    }
}
