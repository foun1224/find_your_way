import Foundation
import ServiceManagement

/// 封裝 `SMAppService.mainApp` 的 register/unregister/status 查詢（`10` §2）。
/// **不用 UserDefaults 記自啟狀態**——真相來源永遠是系統（`status`），避免與使用者在
/// 「系統設定 → 登入項目」外部改動的狀態漂移（`10` §2.2）。
///
/// [待 Phase 5 驗證] ad-hoc 簽章下 `register()` 能否穩定成功、重開機後是否真的自啟，
/// 屬 `10` §9.3 R1 最高風險項，須真機驗證，本類別本身只負責如實轉呼叫 API 結果。
final class LoginItemService {

    enum Status: Equatable {
        case enabled
        case notRegistered
        case requiresApproval
        case notFound

        init(_ status: SMAppService.Status) {
            switch status {
            case .enabled: self = .enabled
            case .notRegistered: self = .notRegistered
            case .requiresApproval: self = .requiresApproval
            case .notFound: self = .notFound
            @unknown default: self = .notRegistered
            }
        }
    }

    /// 目前登入項狀態；單一真相來源，UI 每次出現/前景化都應重讀（`10` §2.2）。
    var status: Status {
        Status(SMAppService.mainApp.status)
    }

    /// 註冊為登入項（開機自啟）。失敗時 throw，呼叫端不得假設成功、應重讀 `status` 回退 UI。
    func register() throws {
        try SMAppService.mainApp.register()
    }

    /// 取消登入項註冊。失敗時 throw，呼叫端不得假設成功、應重讀 `status` 回退 UI。
    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    /// `.requiresApproval` 時，帶使用者去系統設定的登入項目頁面允許（`10` §2.2 / R5）。
    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
