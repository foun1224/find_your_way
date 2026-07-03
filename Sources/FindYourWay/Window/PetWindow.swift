import AppKit
import SpriteKit
import FindYourWayCore

/// 透明無邊框置頂懸浮視窗，套用 `PetWindowConfig` 的設定值（照 `04` §2.2）。
final class PetWindow: NSWindow {

    private let skView: SKView

    init(contentRect: CGRect) {
        skView = SKView(frame: CGRect(origin: .zero, size: contentRect.size))

        super.init(
            contentRect: contentRect,
            styleMask: PetWindowConfig.Flags.styleMask,
            backing: .buffered,
            defer: false
        )

        isOpaque = PetWindowConfig.Flags.isOpaque
        backgroundColor = PetWindowConfig.Flags.backgroundColor
        hasShadow = PetWindowConfig.Flags.hasShadow
        level = PetWindowConfig.Flags.level
        collectionBehavior = PetWindowConfig.Flags.collectionBehavior
        ignoresMouseEvents = PetWindowConfig.Flags.ignoresMouseEvents
        isMovableByWindowBackground = PetWindowConfig.Flags.isMovableByWindowBackground

        skView.allowsTransparency = true
        skView.wantsLayer = true
        skView.preferredFramesPerSecond = 30

        contentView = skView
    }

    /// Phase 1 不需要鍵盤/焦點：視窗不可成為 key window。
    override var canBecomeKey: Bool { PetWindowConfig.Flags.canBecomeKey }

    /// 顯示走路場景。
    func presentScene(_ scene: SKScene) {
        skView.presentScene(scene)
    }

    /// 不搶焦點地顯示視窗。
    func showWithoutActivating() {
        orderFrontRegardless()
    }
}
