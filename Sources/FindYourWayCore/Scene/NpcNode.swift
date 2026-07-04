import SpriteKit

/// 王國市民 NPC 節點（Stage B+，`02_PSYCHOLOGY_FOUNDATION.md` §2 社會臨場感）：純裝飾的
/// 靜態站立像素圖（各地域居民代表幀），沿世界捲動（`RegionNpcScatter`），
/// 不驅動任何遊戲邏輯、不入 `GameState`——純粹讓王國看起來「有人住」。
///
/// 極輕微待機呼吸（同 `CharacterNode.runBreathing`，振幅/週期完全一致以維持同一套「活著」語彙、
/// `03_DESIGN_SYSTEM` §2.3 克制原則）：受 `reducedMotion` 控制，降低動態時關閉（`03` §1.5）。
public final class NpcNode: SKSpriteNode {

    /// 顯示高度（點）：比主角矮一截（NPC 是背景裝飾、非主角，`02` §2 避免搶焦），
    /// 但仍清楚可辨識人形。
    public static let displayHeight: CGFloat = 34

    private static let breathScaleAmplitude: CGFloat = 0.012
    /// 呼吸一個完整週期（吸+吐）秒數。`public`：`ParallaxBackground.buildNpcNodes` 用它算
    /// 確定性相位偏移（見下方 `breathPhaseOffset`），避免多個 NPC 完全同步呼吸。
    public static let breathPeriodSeconds: TimeInterval = 3.6
    private static let breathingKey = "npcBreathing"

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

    /// 呼吸起始相位延遲（秒）：由呼叫端依槽位 `baseX` 算出的固定值（確定性、非隨機），
    /// 讓同畫面多個 NPC 的呼吸不會完全同步起伏（同步會顯得像機器人陣列，違反 §2 社會臨場感
    /// 「像是活著的個體」的用意）。
    private let breathPhaseOffset: TimeInterval

    public init(texture: SKTexture, reducedMotion: Bool, breathPhaseOffset: TimeInterval = 0) {
        self.reducedMotion = reducedMotion
        self.breathPhaseOffset = breathPhaseOffset
        let aspect = texture.size().width / texture.size().height
        let size = CGSize(width: Self.displayHeight * aspect, height: Self.displayHeight)
        super.init(texture: texture, color: .clear, size: size)
        texture.filteringMode = .nearest
        if !reducedMotion {
            runBreathing()
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("NpcNode does not support NSCoding")
    }

    private func runBreathing() {
        let inhale = SKAction.scale(to: 1.0 + Self.breathScaleAmplitude, duration: Self.breathPeriodSeconds / 2)
        inhale.timingMode = .easeInEaseOut
        let exhale = SKAction.scale(to: 1.0, duration: Self.breathPeriodSeconds / 2)
        exhale.timingMode = .easeInEaseOut
        let loop = SKAction.repeatForever(SKAction.sequence([inhale, exhale]))
        if breathPhaseOffset > 0 {
            run(SKAction.sequence([SKAction.wait(forDuration: breathPhaseOffset), loop]), withKey: Self.breathingKey)
        } else {
            run(loop, withKey: Self.breathingKey)
        }
    }
}
