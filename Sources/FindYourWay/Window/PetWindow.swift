import AppKit
import SpriteKit
import FindYourWayCore

/// 透明無邊框置頂懸浮視窗，套用 `PetWindowConfig` 的設定值（照 `04` §2.2）。
///
/// **ADR-011（拖曳 + 記住位置，2026-07-04 更新「背景也可以拖曳」）**：整個視窗（含背景）都能
/// 抓拖。`ClickThroughController` 現在只要游標在視窗 frame 內就設 `ignoresMouseEvents == false`，
/// 所以本類攔截到的 `leftMouseDown`/`leftMouseDragged`/`leftMouseUp` 可能發生在角色上、也可能
/// 在背景——因此放開時（未拖曳的短按分支）需要額外對放開位置做角色 hit-test（見
/// `characterHitTest`），才能分流「角色→暖心回應」「背景→無作用、吃掉不穿透」。
///
/// click-vs-drag 用移動距離門檻區分（`WindowDragGesture`，Core 純函式、可測）：放開時位移
/// 小於門檻＝短按——命中角色才呼叫 `onCharacterClicked`（觸發暖心回應，ADR-006 不變），命中
/// 背景則什麼都不做；超過門檻＝拖曳（任一處皆可，視窗跟著游標即時移動，放開時透過
/// `onWindowDragEnded` 回報最終 origin 供外部存偏好）。
final class PetWindow: NSWindow {

    private let skView: SKView

    /// 拖曳開始時的游標螢幕座標與視窗 origin（用於算位移量、還原起點）。
    private var dragStartScreenLocation: CGPoint?
    private var dragStartWindowOrigin: CGPoint?
    /// 這次按下-放開，是否已經被判定為「拖曳」（超過門檻後就不會變回點擊）。
    private var isDraggingWindow = false

    /// 確定是「點擊」（放開時位移 < 門檻）且命中角色時呼叫，供外部觸發暖心回應（ADR-006）。
    var onCharacterClicked: (() -> Void)?
    /// 確定是「拖曳」且已放開時呼叫，帶上最終 origin，供外部存到偏好（ADR-011）。
    var onWindowDragEnded: ((CGPoint) -> Void)?
    /// 判斷「視窗座標系」中的一點是否落在角色命中框內（外部注入，通常是
    /// `GameScene.isPointOnCharacter`，底層共用 `CharacterHitTest` 純函式）。
    /// 短按放開時用它分流角色（暖心回應）vs 背景（無作用），ADR-011 2026-07-04 更新。
    var characterHitTest: ((CGPoint) -> Bool)?

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

    // MARK: - 拖曳移動視窗 + click-vs-drag 判定（ADR-011）

    /// 攔截於 `NSApplication`/`NSWindow` 派送事件給 content view（`SKView`/`GameScene`）之前，
    /// 是實作「按住角色拖曳整個視窗」的標準做法：一旦視窗判定為拖曳，就不再把該事件轉給場景，
    /// 避免場景端另外收到一份重複、語意衝突的滑鼠事件。非左鍵事件、或本次判定為點擊時，
    /// 仍照常呼叫 `super.sendEvent`，維持既有事件流程不變。
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            handleMouseDown(event)
        case .leftMouseDragged:
            handleMouseDragged(event)
            if isDraggingWindow { return }
        case .leftMouseUp:
            handleMouseUp(event)
        default:
            break
        }
        super.sendEvent(event)
    }

    private func handleMouseDown(_ event: NSEvent) {
        dragStartScreenLocation = NSEvent.mouseLocation
        dragStartWindowOrigin = frame.origin
        isDraggingWindow = false
    }

    private func handleMouseDragged(_ event: NSEvent) {
        guard let startScreen = dragStartScreenLocation, let startOrigin = dragStartWindowOrigin else { return }
        let current = NSEvent.mouseLocation
        let dx = Double(current.x - startScreen.x)
        let dy = Double(current.y - startScreen.y)

        if !isDraggingWindow {
            guard WindowDragGesture.exceedsThreshold(dx: dx, dy: dy) else { return }
            isDraggingWindow = true
        }

        let rawOrigin = CGPoint(x: startOrigin.x + dx, y: startOrigin.y + dy)
        setFrameOrigin(clampedOrigin(rawOrigin))
    }

    private func handleMouseUp(_ event: NSEvent) {
        defer {
            dragStartScreenLocation = nil
            dragStartWindowOrigin = nil
        }

        if isDraggingWindow {
            isDraggingWindow = false
            onWindowDragEnded?(frame.origin)
        } else if characterHitTest?(event.locationInWindow) == true {
            // 短按命中角色 → 暖心回應（ADR-006）。命中背景則什麼都不做——
            // 整窗互動化後背景不再穿透（ADR-011 更新），但也不應誤觸暖心回應。
            onCharacterClicked?()
        }
    }

    /// 夾在「游標目前所在螢幕」的可視範圍內，跨螢幕拖曳時也不會被夾在原螢幕、也不會跑到畫面外
    /// （ADR-011 多螢幕守則）；找不到任何螢幕時退回目前 frame 本身（不夾取，維持原樣，極端情況保底）。
    private func clampedOrigin(_ origin: CGPoint) -> CGPoint {
        let visibleFrames = NSScreen.screens.map { $0.visibleFrame }
        guard let owningFrame = WindowPlacement.owningVisibleFrame(
            for: origin,
            windowSize: frame.size,
            visibleFrames: visibleFrames
        ) ?? visibleFrames.first else {
            return origin
        }
        return WindowPlacement.clampedOrigin(origin, windowSize: frame.size, visibleFrame: owningFrame)
    }
}
