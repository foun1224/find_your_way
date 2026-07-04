import AppKit
import FindYourWayCore

/// 完整選單列（`10` §3 擴充自 Phase 2 極簡版）：
/// 狀態卡片（glanceable，非可點）＋ 偏好設定… ＋ 顯示/隱藏桌寵 ＋ 結束。
/// 動作項（可點）＝ 偏好、顯示/隱藏、結束 = 3 個，守 Hick's law（`03` §3.2 ≤~5）。
final class StatusItemController: NSObject, NSMenuDelegate {

    private var statusItem: NSStatusItem?
    private let onToggleVisibility: () -> Void
    private let onOpenPreferences: () -> Void
    private let onQuit: () -> Void

    /// 選單即將展開時，向上層（`AppDelegate`）要一份當前 `GameState` 快照重建狀態卡片，
    /// 避免持有過期狀態（`10` §3.2）。
    var gameStateProvider: (() -> GameState)?

    private var statusCardItems: [NSMenuItem] = []

    init(
        onToggleVisibility: @escaping () -> Void,
        onOpenPreferences: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onToggleVisibility = onToggleVisibility
        self.onOpenPreferences = onOpenPreferences
        self.onQuit = onQuit
    }

    /// 建立選單列圖示與選單。呼叫一次即可。
    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "🚶"

        let menu = NSMenu()
        menu.delegate = self

        // 狀態卡片區（`10` §3.2）：先放空白，`menuWillOpen` 時重建。
        menu.addItem(NSMenuItem.separator())

        let preferencesItem = NSMenuItem(
            title: "偏好設定…",
            action: #selector(handleOpenPreferences),
            keyEquivalent: ","
        )
        preferencesItem.keyEquivalentModifierMask = [.command]
        preferencesItem.target = self
        menu.addItem(preferencesItem)

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

    // MARK: - NSMenuDelegate

    /// 選單展開前重建狀態卡片文字（`10` §3.2「避免持有過期狀態」）。
    func menuWillOpen(_ menu: NSMenu) {
        guard let state = gameStateProvider?() else { return }

        // 先移除上一輪的狀態卡片項目。
        for item in statusCardItems {
            menu.removeItem(item)
        }
        statusCardItems.removeAll()

        let lines = StatusCardText.lines(for: state)
        // 插入在選單最上方（index 0 之前是我們預留的分隔線，見 install()）。
        var insertIndex = 0
        for line in lines {
            let cardItem = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            cardItem.isEnabled = false
            menu.insertItem(cardItem, at: insertIndex)
            statusCardItems.append(cardItem)
            insertIndex += 1
        }
    }

    // MARK: - Actions

    @objc private func handleToggleVisibility() {
        onToggleVisibility()
    }

    @objc private func handleOpenPreferences() {
        onOpenPreferences()
    }

    @objc private func handleQuit() {
        onQuit()
    }
}
