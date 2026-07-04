import SpriteKit

/// Phase 4a 背景分層（`12_PHASE4_SPEC.md` §1/§2，取代 Phase 2 純色佔位）：
/// 用 `scripts/slice_assets.py` 切出的三條 panorama（`Resources/art/bg/{far,mid,ground}.png`）
/// 由遠到近堆疊，依 `WorldScroll.panoramaTileXs` 各自 `layerFactor` 做無縫水平平鋪填滿視窗寬。
/// 遠景最慢、地面最快，呈現視差深度；`filteringMode = .nearest` 保留像素邊緣。
///
/// 注意：這裡刻意**不**沿用 `WorldScroll.wrappedX`——`wrappedX` 是為 Phase 2「散落小草叢」
/// 這類獨立小物件的循環出現設計的（各槽位各自 `mod span`），拿來鋪一整條連續 panorama
/// 會在 `distance` 增加後讓所有 tile 一起被繞到可視範圍外、露出整片透空（Phase 4a 背景全黑
/// 的根因）。`panoramaTileXs` 改以「tile 寬度」為平鋪單位，任何 `distance` 下都保證
/// `[0, sceneWidth]` 被連續覆蓋，無縫接合。
///
/// 找不到美術檔案（例如尚未執行切圖腳本）時優雅降級回 Phase 2 純色滿版，不 crash。
public enum ParallaxBackground {

    /// 可捲動景物層：一組節點依左緣連續平鋪（anchor 左下），共用 `layerFactor` 與單張顯示寬 `tileWidth`；
    /// 實際螢幕 x 由 `WorldScroll.panoramaTileXs` 算出（見 `GameScene.applyWorldScroll`）。
    public struct SceneryLayer {
        public let nodes: [SKSpriteNode]
        public let layerFactor: Double
        public let tileWidth: Double
    }

    /// 地面平台的顯示高度（點）：作為整組背景的「主尺度」，遠景/中景依同一縮放比例換算，
    /// 保證三層像素密度一致（避免遠景/中景/地面「像素大小」不成比例）。
    /// `CharacterNode` 站立的基準線（`GameScene` 用本值算角色腳邊 y）。
    public static let groundDisplayHeight: CGFloat = 40

    /// 中景/遠景相鄰層之間的重疊量（點）：讓「較近的層」（zPosition 較高）蓋住「較遠的層」
    /// 圖塊本身自帶的小片天空，避免明顯的接縫（各條 panorama 是各自獨立小場景，非無縫延伸）。
    private static let groundMidOverlap: CGFloat = 10
    private static let midFarOverlap: CGFloat = 15

    @discardableResult
    public static func build(in parent: SKNode, size: CGSize) -> [SceneryLayer] {
        guard
            let groundTexture = ArtCatalog.texture(relativePath: "bg/ground.png"),
            let midTexture = ArtCatalog.texture(relativePath: "bg/mid.png"),
            let farTexture = ArtCatalog.texture(relativePath: "bg/far.png")
        else {
            return buildFallbackFlatColors(in: parent, size: size)
        }

        let scale = groundDisplayHeight / groundTexture.size().height
        let groundHeight = groundTexture.size().height * scale
        let midHeight = midTexture.size().height * scale

        let groundBottomY = 0.0
        let midBottomY = Double(groundHeight - groundMidOverlap)
        let farBottomY = midBottomY + Double(midHeight - midFarOverlap)

        // zPosition：遠景最後（最負）、地面最前（最靠近角色），近層蓋住遠層的接縫。
        let ground = buildLayer(
            in: parent, sceneWidth: Double(size.width), texture: groundTexture,
            scale: scale, bottomY: groundBottomY, zPosition: -10, layerFactor: 1.0
        )
        let mid = buildLayer(
            in: parent, sceneWidth: Double(size.width), texture: midTexture,
            scale: scale, bottomY: midBottomY, zPosition: -20, layerFactor: 0.45
        )
        let far = buildLayer(
            in: parent, sceneWidth: Double(size.width), texture: farTexture,
            scale: scale, bottomY: farBottomY, zPosition: -30, layerFactor: 0.15
        )

        // 回傳順序不影響繪製（zPosition 決定疊放），僅供 `GameScene` 逐層套用捲動。
        return [far, mid, ground]
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
        for x in initialXs {
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: width, height: height)
            node.texture?.filteringMode = .nearest
            node.anchorPoint = CGPoint(x: 0, y: 0)
            node.position = CGPoint(x: CGFloat(x), y: CGFloat(bottomY))
            node.zPosition = zPosition
            parent.addChild(node)
            nodes.append(node)
        }
        return SceneryLayer(nodes: nodes, layerFactor: layerFactor, tileWidth: width)
    }

    // MARK: - 找不到美術時的優雅降級（Phase 2 純色滿版）

    private static func buildFallbackFlatColors(in parent: SKNode, size: CGSize) -> [SceneryLayer] {
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
