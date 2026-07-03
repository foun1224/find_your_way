import SpriteKit

/// 32×32 陶紅方塊角色 + 悠閒走路節奏（Phase 1 佔位美術，照 `03` §2.2/2.3）。
///
/// **ADR-009**：角色固定在畫面左側、原地走路（walk-in-place），不再左右 roam。
/// 螢幕水平座標 `position.x` 在 `init` 後恆定不變；「前進」改由世界（背景/地標）向左捲動表現，
/// 由 `GameScene` 依 `WorldScroll` 對里程換算後套用到其他節點。本類只保留原地踏步的視覺表現（bob）。
public final class CharacterNode: SKSpriteNode {

    /// 角色邊長（點）。
    public static let size: CGFloat = 32

    /// 走路步伐節奏（每步秒數），對應 6–8fps 的悠閒感（1/7 秒 ≈ 7fps）。
    private static let stepInterval: TimeInterval = 1.0 / 7.0

    private let stepBobAmplitude: CGFloat = 3

    /// - Parameters:
    ///   - screenX: 固定的螢幕水平位置（ADR-009：畫面左側約 20–25%，由 `WorldScroll.characterScreenX` 算出）。
    ///   - screenY: 固定的螢幕垂直位置。
    public init(screenX: Double, screenY: Double) {
        super.init(
            texture: nil,
            color: Palette.travelerTerracotta.skColor,
            size: CGSize(width: Self.size, height: Self.size)
        )
        self.position = CGPoint(x: screenX, y: screenY)
        runWalkStepAnimation()
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("CharacterNode does not support NSCoding")
    }

    /// 悠閒走路節奏的佔位表現：上下微幅位移模擬步伐，速率對應 6–8fps。
    /// 純粹是「原地走路」的視覺表現，不驅動任何邏輯座標（里程由 `GameState.distance` 決定）。
    private func runWalkStepAnimation() {
        let stepUp = SKAction.moveBy(x: 0, y: stepBobAmplitude, duration: Self.stepInterval)
        let stepDown = SKAction.moveBy(x: 0, y: -stepBobAmplitude, duration: Self.stepInterval)
        let bob = SKAction.sequence([stepUp, stepDown])
        run(SKAction.repeatForever(bob), withKey: "walkStep")
    }
}
