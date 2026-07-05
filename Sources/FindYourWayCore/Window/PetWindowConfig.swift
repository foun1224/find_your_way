import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// 視窗設定「值」與定位計算（純函式，可測）。
/// 照 `04_ARCHITECTURE.md` §2.2 與 `06_PHASE1_SPEC.md` §3。
/// 只描述設定值與計算，**不建立/顯示任何實際 NSWindow**，因此可在 headless 測試環境下驗證。
public enum PetWindowConfig {

    /// Phase 1 預設視窗尺寸（邏輯點）。
    public static let defaultSize = CGSize(width: 320, height: 180)

    /// 錨定右下角時，距螢幕右下邊緣的邊距（邏輯點）。
    public static let defaultMargin = CGSize(width: 24, height: 24)

    // MARK: - 拉場景大小（使用者需求 2026-07-05：拖右下角拉手 resize + reflow）

    /// 拉縮的最小視窗尺寸（邏輯點）：避免拉到過小讓地面條/角色比例失衡。自由比例（reflow 允許
    /// 任意長寬——拉寬看更廣、拉高露更多天空），min 只防退化。
    public static let minSize = CGSize(width: 220, height: 130)

    /// 右下角「拉手」感應區邊長（邏輯點，視窗座標系 bottom-left origin：右下角＝x 近寬、y 近 0）。
    /// 在此區域內按下拖曳＝縮放；其餘區域按下拖曳＝移動整窗（既有 ADR-011）。
    public static let resizeGripSize: CGFloat = 30

    /// 判斷視窗座標系中的一點是否落在右下角拉手感應區內（純函式，可測）。
    /// `pointInWindow` 為 `NSEvent.locationInWindow`（bottom-left origin）。
    public static func isInResizeGrip(
        pointInWindow: CGPoint,
        windowSize: CGSize,
        gripSize: CGFloat = resizeGripSize
    ) -> Bool {
        pointInWindow.x >= windowSize.width - gripSize && pointInWindow.y <= gripSize
    }

    /// 由「右下角拉手」的拖曳位移算出新視窗 frame（純函式，可測）：錨定左上角不動
    /// （AppKit bottom-left origin 下＝ origin.x 與 origin.y+height 固定），拖右＝變寬、
    /// 拖下（螢幕向下＝ dy<0）＝變高。長寬各自夾在 `minSize` 以上，夾取後重算 origin.y
    /// 維持上緣不動。`dx`/`dy` 為游標相對按下點的螢幕位移（AppKit y 向上）。
    public static func resizedFrame(
        startFrame: CGRect,
        dx: Double,
        dy: Double,
        minSize: CGSize = minSize
    ) -> CGRect {
        let newWidth = max(minSize.width, startFrame.width + CGFloat(dx))
        let newHeight = max(minSize.height, startFrame.height - CGFloat(dy))
        let topFixedY = startFrame.origin.y + startFrame.height
        return CGRect(
            x: startFrame.origin.x,
            y: topFixedY - newHeight,
            width: newWidth,
            height: newHeight
        )
    }

    /// 計算視窗應放置的 origin，使其錨定在 `visibleFrame` 的右下角，並留出 `margin` 邊距。
    ///
    /// - Parameters:
    ///   - visibleFrame: 目標螢幕的可視區域（如 `NSScreen.main.visibleFrame`）。
    ///   - windowSize: 視窗尺寸。
    ///   - margin: 距右下邊緣的邊距。
    /// - Returns: 視窗 origin（左下角座標，AppKit 座標系）。
    public static func bottomRightOrigin(
        visibleFrame: CGRect,
        windowSize: CGSize = defaultSize,
        margin: CGSize = defaultMargin
    ) -> CGPoint {
        let x = visibleFrame.maxX - windowSize.width - margin.width
        let y = visibleFrame.minY + margin.height
        return CGPoint(x: x, y: y)
    }

    /// 計算視窗應放置的完整 frame（錨定右下角）。
    public static func bottomRightFrame(
        visibleFrame: CGRect,
        windowSize: CGSize = defaultSize,
        margin: CGSize = defaultMargin
    ) -> CGRect {
        let origin = bottomRightOrigin(visibleFrame: visibleFrame, windowSize: windowSize, margin: margin)
        return CGRect(origin: origin, size: windowSize)
    }
}

#if canImport(AppKit)
public extension PetWindowConfig {

    /// 視窗旗標設定值（照 `04` §2.2 / `06` §3）。
    /// 這裡只描述「該是什麼值」，實際套用到 NSWindow 由 executable target 的 `PetWindow` 負責。
    enum Flags {
        public static let styleMask: NSWindow.StyleMask = [.borderless]
        public static let isOpaque: Bool = false
        public static let backgroundColor: NSColor = .clear
        public static let hasShadow: Bool = false
        public static let level: NSWindow.Level = .floating
        public static let collectionBehavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]
        public static let ignoresMouseEvents: Bool = true
        public static let isMovableByWindowBackground: Bool = false
        public static let canBecomeKey: Bool = false
    }
}
#endif
