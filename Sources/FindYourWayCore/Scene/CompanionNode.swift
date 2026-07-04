import SpriteKit

/// 旅伴佔位美術（`09_PHASE3_SPEC.md` §3.3）：相遇後常態同行。
///
/// **構圖主從**（ADR-004 / `03` §4 OQ-1）：主角陶紅、最前、最亮；
/// 旅伴略小、略後（呼叫端設定較低 `zPosition`）、明度略降——在場但不搶焦點。
/// **沉默、僅肢體語言、不命名**（`09` §3.4 E3）：本節點不帶任何文字/對話，
/// 只有走路節奏與偶爾的「看向主角」微行為，意義留給使用者投射。
public final class CompanionNode: SKSpriteNode {

    /// 略小於主角（`CharacterNode.size == 32`）。
    public static let size: CGFloat = 26

    private static let stepInterval: TimeInterval = 1.0 / 7.0
    private let stepBobAmplitude: CGFloat = 2.5

    /// - Parameters:
    ///   - screenX: 固定的螢幕水平位置（略後於主角，由呼叫端依 `WorldScroll` 算出）。
    ///   - screenY: 固定的螢幕垂直位置。
    public init(screenX: Double, screenY: Double) {
        super.init(
            texture: nil,
            // 明度略降：同色系但不搶主角的暖紅，避免雙焦點打架（ADR-004 Consequences）。
            color: Palette.travelerTerracotta.skColor.withAlphaComponent(0.7),
            size: CGSize(width: Self.size, height: Self.size)
        )
        self.position = CGPoint(x: screenX, y: screenY)
        self.alpha = 0.7
        runWalkStepAnimation()
        runOccasionalLookAtCompanion()
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("CompanionNode does not support NSCoding")
    }

    private func runWalkStepAnimation() {
        let stepUp = SKAction.moveBy(x: 0, y: stepBobAmplitude, duration: Self.stepInterval)
        let stepDown = SKAction.moveBy(x: 0, y: -stepBobAmplitude, duration: Self.stepInterval)
        let bob = SKAction.sequence([stepUp, stepDown])
        run(SKAction.repeatForever(bob), withKey: "walkStep")
    }

    /// 回應性微行為（`02` §4 依附回應性）：偶爾停下片刻，像是看向主角，
    /// 不帶任何文字，只是節奏上的一次小停頓。
    private func runOccasionalLookAtCompanion() {
        let pause = SKAction.wait(forDuration: 8, withRange: 6)
        let hold = SKAction.run { [weak self] in
            self?.run(SKAction.scale(to: 1.03, duration: 0.6)) {
                self?.run(SKAction.scale(to: 1.0, duration: 0.6))
            }
        }
        run(SKAction.repeatForever(SKAction.sequence([pause, hold])), withKey: "lookOver")
    }
}
