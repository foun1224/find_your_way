import SpriteKit

/// Phase 2 背景（`08` §4b 視覺補正）：
/// - **天空/草地＝固定滿版填充**：不做橫向視差捲動（對純色填充無意義且會造成錯位/露空），
///   永遠覆蓋整個視窗。晝夜色調留 Phase 4。
/// - **可捲動、可循環的佔位景物層**：讓「前進」看得見、有視差層次。
///   近景（草叢/石頭，快）+ 遠景（丘陵剪影，慢），依 `distance` 向左捲動、移出後 wrap 回收。
///   這些純裝飾、**不入 `GameState`、不記錄**（同 Phase 3 §2.2 B 類精神）。真正美術留 Phase 4。
public enum ParallaxBackground {

    /// 可捲動景物層：一組節點共用 `layerFactor` 與循環週期 `span`；
    /// 每個節點的 `baseX` 是它在單一週期內的槽位，實際螢幕 x 由 `WorldScroll.wrappedX` 算出。
    public struct SceneryLayer {
        public let nodes: [(node: SKSpriteNode, baseX: Double)]
        public let layerFactor: Double
        public let span: Double
    }

    /// 角色腳邊高度（草地帶內的比例），近景景物與路面條帶都座落於此，作為速度參照。
    private static let trailYRatio = 0.16

    /// 天空/草地固定填充後，回傳可捲動景物層供 `GameScene` 依 `distance` 更新位置。
    @discardableResult
    public static func build(in parent: SKNode, size: CGSize) -> [SceneryLayer] {
        buildStaticSkyAndMeadow(in: parent, size: size)

        let width = Double(size.width)
        let horizonY = Double(size.height) / 2.0
        let trailY = horizonY * trailYRatio

        // 貼地山徑條帶（固定滿版，赭色，作為角色腳下的「路」；路面上的紋理由近景景物捲動呈現）。
        buildTrailStrip(in: parent, sceneWidth: width, trailY: trailY)

        let far = buildFarHills(in: parent, sceneWidth: width, horizonY: horizonY)
        let near = buildNearScenery(in: parent, sceneWidth: width, trailY: trailY)

        // 遠景在前、近景在後（zPosition 亦對應），近景蓋在遠景之上。
        return [far, near]
    }

    // MARK: - 固定滿版天空/草地

    private static func buildStaticSkyAndMeadow(in parent: SKNode, size: CGSize) {
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
    }

    // MARK: - 貼地山徑條帶（固定，赭色路面）

    private static func buildTrailStrip(in parent: SKNode, sceneWidth: Double, trailY: Double) {
        let strip = SKSpriteNode(color: Palette.trailOchre.skColor, size: CGSize(width: sceneWidth, height: 22))
        strip.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        strip.position = CGPoint(x: sceneWidth / 2.0, y: trailY)
        strip.zPosition = -18 // 在草地(-30)之上、近景景物(-15)之下
        parent.addChild(strip)
    }

    // MARK: - 遠景丘陵剪影（慢，layerFactor ≈ 0.3）

    private static func buildFarHills(in parent: SKNode, sceneWidth: Double, horizonY: Double) -> SceneryLayer {
        let spacing = 160.0
        let span = ceilToSpacing(sceneWidth + spacing, spacing: spacing)
        let count = Int(span / spacing)

        var nodes: [(node: SKSpriteNode, baseX: Double)] = []
        for i in 0..<count {
            let hill = SKSpriteNode(color: Palette.meadowGreen.skColor, size: CGSize(width: 120, height: 60))
            hill.alpha = 0.5 // 剪影感：較淡、退到後面
            hill.anchorPoint = CGPoint(x: 0.5, y: 0)
            hill.zPosition = -20
            hill.position.y = horizonY - 8 // 座落地平線稍下，露出丘頂
            parent.addChild(hill)
            nodes.append((hill, Double(i) * spacing))
        }
        return SceneryLayer(nodes: nodes, layerFactor: 0.3, span: span)
    }

    // MARK: - 近景草叢/石頭（快，layerFactor ≈ 1.0）

    /// 近景是負責呈現「快速前進感」的層：用 **Pine Shadow 松影綠**（深綠，同系但夠對比），
    /// 在草地綠 `#7FB069` 上明顯可見（`08` §4b 修正——舊版與草地同色故看不見）。
    /// 座落於角色腳邊高度（`trailY`）、貼在赭色路面上一起橫向快速掠過 → 清楚的速度參照。
    /// z-order：`-15`，在草地填充(-30)與路面(-18)之上、角色(10)之下。
    private static func buildNearScenery(in parent: SKNode, sceneWidth: Double, trailY: Double) -> SceneryLayer {
        let spacing = 80.0
        let span = ceilToSpacing(sceneWidth + spacing, spacing: spacing)
        let count = Int(span / spacing)

        var nodes: [(node: SKSpriteNode, baseX: Double)] = []
        for i in 0..<count {
            let bush = SKSpriteNode(color: Palette.pineShadow.skColor, size: CGSize(width: 14, height: 14))
            bush.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            bush.zPosition = -15
            bush.position.y = trailY + 2 // 落在路面上、角色腳邊
            parent.addChild(bush)
            nodes.append((bush, Double(i) * spacing))
        }
        return SceneryLayer(nodes: nodes, layerFactor: 1.0, span: span)
    }

    private static func ceilToSpacing(_ value: Double, spacing: Double) -> Double {
        (value / spacing).rounded(.up) * spacing
    }
}
