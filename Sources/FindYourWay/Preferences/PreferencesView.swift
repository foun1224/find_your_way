import SwiftUI
import AppKit
import FindYourWayCore

/// 偏好視窗的 view model：串接 `LoginItemService`（系統真相）與 `PreferencesStore`（UserDefaults）。
/// 執行期難測部分（`10` §4.3 與 SMAppService 分離的理由）。
final class PreferencesViewModel: ObservableObject {

    @Published var isLoginItemEnabled: Bool = false
    @Published var loginItemNeedsApproval: Bool = false
    @Published var reduceMotion: Bool = false

    let appVersion: String

    private let loginItemService: LoginItemService
    private let preferencesStore: PreferencesStore

    init(
        loginItemService: LoginItemService = LoginItemService(),
        preferencesStore: PreferencesStore = PreferencesStore()
    ) {
        self.loginItemService = loginItemService
        self.preferencesStore = preferencesStore
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        refresh()
    }

    /// 偏好視窗每次出現/前景化都重讀（`10` §2.2：避免與系統外部改動的登入項狀態漂移）。
    func refresh() {
        let status = loginItemService.status
        isLoginItemEnabled = (status == .enabled)
        loginItemNeedsApproval = (status == .requiresApproval)

        let prefs = preferencesStore.load()
        let systemPref = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        reduceMotion = MotionSettings.effectiveReduceMotion(userOverride: prefs.reduceMotionOverride, systemPref: systemPref)
    }

    /// 使用者切換「登入時啟動」：呼叫 SMAppService，成功與否都重讀 `status` 更新 UI（不假設成功，`10` §2.2）。
    func setLoginItemEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try loginItemService.register()
            } else {
                try loginItemService.unregister()
            }
        } catch {
            // [待 Phase 5 驗證] register/unregister 失敗情境：不假設成功，回退到實際狀態。
        }
        refresh()
    }

    func setReduceMotion(_ enabled: Bool) {
        preferencesStore.setReduceMotionOverride(enabled)
        refresh()
    }

    func openSystemSettingsForApproval() {
        loginItemService.openSystemSettingsLoginItems()
    }
}

/// 偏好設定表單（`10` §4）：登入自啟、降低動態、關於。選項 ≤5（Hick's law）；一頁到底、不分頁。
struct PreferencesView: View {

    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        Form {
            Section {
                Toggle("登入時啟動", isOn: Binding(
                    get: { viewModel.isLoginItemEnabled },
                    set: { viewModel.setLoginItemEnabled($0) }
                ))

                if viewModel.loginItemNeedsApproval {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("需要到「系統設定 → 一般 → 登入項目」允許")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("前往系統設定") {
                            viewModel.openSystemSettingsForApproval()
                        }
                    }
                }

                Toggle("降低動態（Reduce Motion）", isOn: Binding(
                    get: { viewModel.reduceMotion },
                    set: { viewModel.setReduceMotion($0) }
                ))
            }

            Section("關於") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Find Your Way").font(.headline)
                    Text("版本 \(viewModel.appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("一段安靜的、始終在走的旅程。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { viewModel.refresh() }
    }
}
