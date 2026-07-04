import AppKit
import SwiftUI

/// 持有並複用同一個偏好設定 `NSWindow`（`10` §4.1）：再次點開就 `makeKeyAndOrderFront`，不重複建立。
/// 一般普通視窗（有標題列、可關閉），非置頂穿透。
final class PreferencesWindowController: NSWindowController {

    private let viewModel: PreferencesViewModel

    init() {
        let viewModel = PreferencesViewModel()
        self.viewModel = viewModel

        let hostingController = NSHostingController(rootView: PreferencesView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "偏好設定"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 開啟/前景化偏好視窗。agent app（`.accessory`）預設不吃焦點，故需 `NSApp.activate`
    /// 讓 SwiftUI 表單可互動（`10` §4.1，[待 Phase 5 驗證] R3）。
    func show() {
        viewModel.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
