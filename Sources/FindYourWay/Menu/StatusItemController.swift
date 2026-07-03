import AppKit

/// 極簡選單列常駐入口（`08_PHASE2_SPEC` §0 併入項目二，原屬 `06_PHASE1_SPEC` §8）。
/// `NSStatusItem` + `NSMenu`：至少含「結束 Find Your Way」(Cmd-Q → `NSApp.terminate`)
/// 與「顯示/隱藏桌寵」。維持 `.accessory` 無 Dock。
///
/// **理由**：關不掉的陪伴違反紅線四（邀請非強迫）/ SDT 自主 —— Phase 1 驗收發現的 gap，
/// Phase 2 補上，讓使用者永遠有明確、隨時可用的離開入口。
final class StatusItemController {

    private var statusItem: NSStatusItem?
    private let onToggleVisibility: () -> Void
    private let onQuit: () -> Void

    init(onToggleVisibility: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onToggleVisibility = onToggleVisibility
        self.onQuit = onQuit
    }

    /// 建立選單列圖示與選單。呼叫一次即可。
    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "🚶"

        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "顯示/隱藏桌寵",
            action: #selector(handleToggleVisibility),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "結束 Find Your Way",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func handleToggleVisibility() {
        onToggleVisibility()
    }

    @objc private func handleQuit() {
        onQuit()
    }
}
