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
