import SpriteKit

/// Phase 1/2 極簡背景：上半天空藍、下半草原綠兩塊色帶。
/// 真正的 7 層 parallax（`03` §2.4）留待 Phase 4 正式美術。
///
/// 每層附帶一個 `layerFactor`（視差係數），供 `GameScene` 依 `WorldScroll.scrollOffset`
/// 把里程換算成該層的捲動偏移（遠景係數小、捲動慢；近景係數大、捲動快）。
/// **已知限制**：Phase 2 背景仍是滿版純色色塊，捲動色塊本身不會產生可視位移
/// （色塊本身無紋理），此處先把「世界依 distance 捲動」的資料流接好，
/// Phase 4 換上有紋理的美術後即可看到視差效果；Phase 2 的「世界在動」主要靠地標節點左移呈現。
public enum ParallaxBackground {

    /// 一個 parallax 層：節點本體 + 視差係數 + 初始 x（世界原點時的位置）。
    public struct Layer {
        public let node: SKSpriteNode
        public let layerFactor: Double
        public let baseX: Double
    }

    /// 建立填滿 `size` 的天空/草原兩色帶節點，掛在 `parent` 底下（zPosition 最低）。
    @discardableResult
    public static func build(in parent: SKNode, size: CGSize) -> [Layer] {
        let halfHeight = size.height / 2.0
        let baseX = Double(size.width) / 2.0

        let sky = SKSpriteNode(color: Palette.skyAzure.skColor, size: CGSize(width: size.width, height: halfHeight))
        sky.anchorPoint = CGPoint(x: 0.5, y: 0)
        sky.position = CGPoint(x: baseX, y: Double(halfHeight))
        sky.zPosition = -10

        let meadow = SKSpriteNode(color: Palette.meadowGreen.skColor, size: CGSize(width: size.width, height: halfHeight))
        meadow.anchorPoint = CGPoint(x: 0.5, y: 0)
        meadow.position = CGPoint(x: baseX, y: 0)
        meadow.zPosition = -10

        parent.addChild(sky)
        parent.addChild(meadow)

        return [
            Layer(node: sky, layerFactor: 0.1, baseX: baseX),      // 遠景：捲動慢
            Layer(node: meadow, layerFactor: 0.4, baseX: baseX)    // 近景：捲動較快
        ]
    }
}
