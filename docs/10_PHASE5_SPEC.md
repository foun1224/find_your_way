# Phase 5 建置規格 — 打包與長駐（Ship & Live）

> 狀態：**已審閱 (Accepted)** — Fable review 通過（2026-07-04）。撰寫依準則二「先文字後實作」。
>
> **Fable review 註記 + 待決定案**：工程結構、偏好資料層可測性、SMAppService status 當真相來源、狀態卡片 glanceable（無裸數字、未相遇隱藏）、純 AppKit 狀態卡片、reduce-motion 純函式——全數採納。
> §10 待決全部定案：(1) **簽章＝(a) ad-hoc 不公證**（使用者拍板「只自己用」，ADR-008 更新；`SIGN_MODE=adhoc` 預設）；(2) icon 用佔位（正式留 Phase 4）；(3) 狀態卡片三行封頂（走多遠/章節/相遇隱藏未達成）；(4) 狀態卡片純 AppKit、不投 SwiftUI popover；(5) 不做位置記憶（恆定右下角）；(6) 音量先不放。
> **R1（ad-hoc × SMAppService 自啟）為最高驗證優先**；若 ad-hoc 無法穩定自啟，fallback 優先序：① 使用者手動加入「系統設定→登入項目」（免簽章升級、仍可自啟）；② 若使用者日後有 Developer ID 帳號再用本地 devid 簽章。**不因自啟卡關而阻擋其餘 Phase 5 交付**（選單列/偏好/打包可獨立完成）。
> **目標一句話**：把「開發中 `swift run`」變成「像正常軟體般雙擊安裝、開機自啟、選單列常駐、可調偏好」的真 App —— 而且全程守住 Calm Technology 非侵入原則，不喧賓奪主。
> 前置：Phase 1–3 已完成（106 測試綠）。既有極簡選單列（`StatusItemController`：結束 + 顯示/隱藏）為本階段的擴充起點。
> 依 `04_ARCHITECTURE.md` §7（打包與常駐）、§1（版本）、§6.4（LSUIElement）；ADR-001（Swift/SPM）、**ADR-008（先 Developer ID、App Store 延後）**；`03_DESIGN_SYSTEM.md` §3（非侵入）、§1.5（reduce motion）。
> 凡標 **[待 Phase 5 驗證]** 者為 SMAppService / 簽章 / 沙盒 / SwiftUI-in-agent 的行為未在真機確認，不得當既定事實施工。

---

## 0. 驗收標準（Definition of Done）

1. **可雙擊安裝/執行的 `.app`**：`scripts/build_app.sh`（擴充版）產出 `FindYourWay.app`，拖進 `/Applications` 後雙擊即啟動（首次可能需右鍵「打開」一次，見 §6）；無 Dock 圖示、選單列出現圖示。
2. **開機自啟可開關**：偏好設定有「登入時啟動」開關；勾選 → 下次登入自動啟動；取消 → 不自啟。開關狀態與系統實際登入項狀態一致（`SMAppService.Status`）。
3. **完整選單列**：選單列點開有 —— (a) **狀態卡片**（走了多遠 / 第幾章 / 是否已相遇，克制 glanceable）、(b) **偏好設定…**、(c) 顯示/隱藏桌寵、(d) 結束。
4. **偏好設定視窗**：SwiftUI（via `NSHostingController`）視窗，至少含 —— 登入自啟、降低動態（reduce motion）、關於；音量預留（灰掉/停用，音效 Phase 4 才有）。偏好存 UserDefaults，與遊戲主存檔（`save.json`）分離。
5. **降低動態實際生效**：開啟 reduce motion 後，晝夜 tint 漸變與粒子關閉（Phase 4 功能上線後掛此旗標；Phase 5 先把旗標與讀寫/套用邏輯建好並測試）。
6. **`swift test` 不回歸**：既有 106 測試維持綠；新增偏好資料層純函式測試（見 §8）。
7. **非侵入不破**：選單列、狀態卡片、偏好視窗皆非常駐 HUD、不搶焦點、不彈 modal；狀態卡片走 progressive disclosure（點開才看，不長駐畫面）。

> Phase 5 **不做**：正式 App icon 美術（用佔位，正式留 Phase 4 美術）、App Store 上架（ADR-008 延後）、音效（Phase 4）、公證自動化 CI（除非決定分發，見 §6）。

---

## 1. 範圍與策略決策（延續 SPM）

- **建置維持 SPM executable + `build_app.sh` 組 bundle**（承 `06` §1，不轉 `.xcodeproj`）。Phase 5 仍無 Texture Atlas 剛性需求（美術是 Phase 4），SPM 更利於 AI 施工與 CI。若 Phase 4 引入 atlas 才評估遷移，本階段不動 ADR-001。
- **SwiftUI 只用於「偏好設定視窗」與（可選）「狀態卡片」**，不碰桌寵渲染（`04` §1.3 原則）。SwiftUI 透過 `NSHostingController` / `NSHostingView` 嵌進既有 AppKit agent app。
- **偏好與遊戲主存檔分離**：偏好 = UserDefaults（`04` §5.1 明訂輕量偏好走 UserDefaults）；遊戲狀態仍 = `save.json`。兩者不混。
- **新程式分層**：可測的偏好資料層放 `FindYourWayCore`（library，headless 可測）；SMAppService / NSStatusItem / NSHostingController 等 runtime 難測部分放 executable target `FindYourWay`。與既有分層（`06` §2）一致。

---

## 2. 開機自啟（SMAppService）

### 2.1 API（macOS 13+，`04` §7.2）

```swift
import ServiceManagement

// 註冊（登入時啟動）
try SMAppService.mainApp.register()
// 取消
try SMAppService.mainApp.unregister()
// 查詢目前狀態（驅動偏好開關的顯示）
let status = SMAppService.mainApp.status   // .enabled / .notRegistered / .requiresApproval / .notFound
```

- `SMAppService.mainApp` = 把「主 App 自己」註冊為登入項，**無需 helper bundle**（舊 `SMLoginItemSetEnabled` 已 deprecated，不採用，`04` §7.2）。
- `register()` / `unregister()` 皆 `throws`，UI 端要 try/catch，失敗時開關回退到實際狀態、不要假設成功。

### 2.2 偏好開關 ↔ 狀態綁定

「登入時啟動」開關**不是自己記一個 bool 就好**，必須以 `SMAppService.mainApp.status` 為真相來源（single source of truth），因為使用者可能在「系統設定 → 一般 → 登入項目」外部改動：

| 顯示/動作 | 對應 |
|-----------|------|
| 開關「開」的判定 | `status == .enabled` |
| 使用者打開開關 | `try register()`；成功後重讀 `status` 更新 UI |
| 使用者關閉開關 | `try unregister()`；成功後重讀 `status` |
| `status == .requiresApproval` | 顯示提示「請到系統設定 → 登入項目允許」；可用 `SMAppService.openSystemSettingsLoginItems()` 一鍵帶去 |
| 偏好視窗每次出現 / 前景化 | 重讀 `status`，避免與外部狀態不同步 |

- 我方**不用 UserDefaults 記自啟狀態**（會與系統真實狀態漂移）；UserDefaults 只記其他偏好（reduce motion 等）。自啟一律問 `SMAppService`。

### 2.3 安裝位置 / 簽章要求與限制 [待 Phase 5 驗證]

- **[待驗證]** `SMAppService.mainApp.register()` 對「App 安裝位置」的敏感度：一般經驗是 **App 需在穩定位置（建議 `/Applications`）** 才能可靠自啟；從 `~/Downloads` 或被 Gatekeeper **path-translocation**（見 §6.2）的隨機唯讀路徑執行時，登入項指向的路徑可能失效或每次變動。**因此驗收前提是「App 已移入 `/Applications`」**（見 §5.4）。
- **[待驗證]** 簽章要求：SMAppService 對登入項通常期望**有效簽章**。**ad-hoc 簽章（`codesign -s -`）能否成功 `register()` 並在重開機後真的自啟，須在真機實測**——這是 §6 簽章決策與自啟能否共存的關鍵未知，列為本階段最高驗證項之一。
- **[待驗證]** `.requiresApproval` 的觸發條件（macOS 13+ 首次註冊常需使用者在登入項目清單按允許）與 UX 流程。

---

## 3. 完整選單列（NSStatusItem 擴充）

擴充既有 `Sources/FindYourWay/Menu/StatusItemController.swift`（目前只有「顯示/隱藏」+「結束」）。

### 3.1 選單結構（由上而下）

```
[狀態卡片區]   ← glanceable，非可點動作（見 3.2）
────────────
偏好設定…      ⌘,        → 開啟偏好視窗
顯示 / 隱藏桌寵           → 既有
────────────
結束 Find Your Way  ⌘Q   → 既有
```

- 動作項數量守 Hick's law（`03` §3.2「同時可見操作 ≤ ~5」）：偏好、顯示/隱藏、結束 = 3 個動作，其餘是資訊區。
- 選單列圖示維持既有「🚶」佔位（或改 SF Symbol `figure.walk`）；icon 佔位 vs 正式屬待決（§10）。

### 3.2 狀態卡片：克制的 glanceable 語言（`03` §3.3）

狀態卡片呈現三件事，**全部走「世界的變化」語言、避免裸數字**（`03` §3.3 明訂「用數字說話是最後手段」、禁止百分比/經驗條 HUD）：

| 要表達 | glanceable 呈現（建議） | 資料來源 | 備註 |
|--------|------------------------|----------|------|
| 走了多遠 | 「已路過：一座舊石橋」（最近通過的地標名）或「已路過 N 個地標」 | `GameState.landmarksPassed` + `Landmark.all` | **不顯示 `distance` 原始數字**（`08` §7 P2：抽象單位，預設不對使用者顯示） |
| 第幾章 | 章節名，如「第二章 · 有人同行」 | `GrowthStage.chapterName(forDistance:)` | 純函式已存在，直接用 |
| 是否已相遇 | 相遇後才顯示一行「旅伴同行中」；未相遇則**不顯示此行**（不劇透、不製造「未達成」焦慮） | `GameState.companionJoined` | 未相遇時整行隱藏＝非侵入，非顯示「未相遇 ✗」 |

- **progressive disclosure**：狀態卡片本身就是「點開選單列才看得到」的一層揭露；卡片內只放 glanceable 摘要，不放時間軸/完整日誌（若未來要旅程日誌，另開一層，Phase 5 不做）。
- **非常駐**：這些資訊只在使用者主動點開選單時出現，桌面上不長駐任何文字/數字（守 `03` §3.1 戒律三、§3.2 資訊密度）。
- **資料流**：`AppDelegate` 已持有 `gameScene.gameState`；選單即將展開時（`NSMenuDelegate.menuWillOpen`）向上層要一份當前 `GameState` 快照，重建卡片文字。避免持有過期狀態。

### 3.3 狀態卡片：AppKit vs SwiftUI NSHostingView —— 建議

**建議：Phase 5 狀態卡片用純 AppKit（`NSMenuItem` 停用態顯示文字，或自訂 view）**，理由：

- 卡片只是**幾行唯讀文字**，資訊密度低（§3.2 就三行且克制）。用 `NSMenuItem`（`isEnabled = false` 當標題列，或 `NSMenuItem.view` 掛一個小 `NSTextField` 堆疊）成本最低、無額外框架風險。
- `NSHostingView` 塞進 `NSMenu` 的 item 雖可行，但在 agent app + 選單列 popover 場景下的**尺寸自適應/生命週期**有 [待驗證] 風險（見 §9），為三行字引入不划算。
- **SwiftUI 的投資點放在偏好視窗**（§4），那裡表單控制項多、SwiftUI 效益高。狀態卡片保持 AppKit，符合「SwiftUI 是附屬 UI 加速器、非主線」（`04` §1.3）。
- 若日後狀態卡片要做成圖文並茂的 popover（地標剪影等，`03` §3.3 次要層），再評估改 `NSPopover` + `NSHostingView`。**此為待決（§10）**。

---

## 4. 偏好設定視窗（SwiftUI via NSHostingController）

### 4.1 視窗承載

- 一個普通 `NSWindow`（標題列、可關閉、**非**置頂穿透），`contentViewController = NSHostingController(rootView: PreferencesView())`。
- 由 `StatusItemController` 的「偏好設定…」觸發；`AppDelegate`/一個 `PreferencesWindowController` 持有並複用同一視窗（再次點開就 `makeKeyAndOrderFront`，不重複建立）。
- 開啟偏好視窗時**需要短暫切 activation policy**：agent app（`.accessory`）預設不吃焦點，SwiftUI 表單需要能接收鍵盤/點擊。做法 [待驗證]：開視窗前 `NSApp.activate(ignoringOtherApps:)` 讓視窗可互動，關閉後不必改回 `.accessory`（policy 本身沒變，只是 activate）。**此互動細節列 [待 Phase 5 驗證]**（§9 R3）。

### 4.2 選項清單

| 選項 | 控制項 | 綁定 | 說明 |
|------|--------|------|------|
| 登入時啟動 | Toggle | `SMAppService.mainApp.status`（§2.2） | 真相來源是系統，非 UserDefaults |
| 降低動態（Reduce Motion） | Toggle | `UserDefaults` `reduceMotion` | 關晝夜 tint 漸變 + 粒子（`03` §1.5 WCAG 2.3.3） |
| 〔預留〕音量 | Slider（灰掉/`disabled`） | — | 音效 Phase 4 才有；先放停用控制項或不放，見 §10 |
| 關於 | 靜態區塊 | — | App 名、版本（讀 `CFBundleShortVersionString`）、一句話定位 |

- **降低動態的預設值**：建議預設**跟隨系統** `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`（系統開了就預設開）。使用者可在偏好覆寫。此「系統預設 + 使用者覆寫」的解析邏輯抽純函式可測（§8）。
- 表單克制：選項 ≤ ~5（Hick's law）；不做花俏設定頁分頁，一頁到底即可（符合非侵入、低負擔）。

### 4.3 偏好資料層（可測，放 Core）

新增 `Sources/FindYourWayCore/Preferences/`：

- `Preferences.swift`：偏好的**純值模型**（`struct Preferences: Equatable`，欄位 `reduceMotion: Bool`、`volume: Double`（預留）等）+ 各鍵的 `UserDefaults` key 常數。
- `PreferencesStore.swift`：讀寫 `UserDefaults`（可注入 `UserDefaults` 實例，測試用 `UserDefaults(suiteName:)` 或自訂），把「讀 default → 套用 → 寫回」做成可測方法。**不含** SMAppService（那是系統呼叫，非資料層）。
- `MotionSettings.swift`（或併入上者）：**reduce-motion 解析純函式** —— `effectiveReduceMotion(userOverride:Bool?, systemPref:Bool) -> Bool`，把「使用者未設 → 跟隨系統；已設 → 用使用者值」的邏輯抽出可測。
- 消費端（Phase 4 的晝夜/粒子）讀這個 effective 旗標決定是否播放。Phase 5 先把旗標與套用開關（render 層一個 `motionEnabled` 檢查點）接好，Phase 4 功能上線即受控。

> **與 SMAppService 分離的理由**：登入自啟狀態存在系統、非 UserDefaults（§2.2）；`PreferencesStore` 只管 UserDefaults 那些純資料偏好，故可 headless 測試，不碰系統 API。

---

## 5. 打包（擴充 build_app.sh）

### 5.1 現況 → 目標

現有 `scripts/build_app.sh` 已能組出含 Info.plist 的 `.app`（`06` §3）。Phase 5 擴充：**icon、簽章、（可選）公證**，Info.plist 補欄位、版本號集中管理。

### 5.2 Info.plist（在既有基礎上補齊）

既有已有：`CFBundleExecutable`、`CFBundleIdentifier`（`com.findyourway.app`）、`CFBundleName`、`CFBundlePackageType`、`CFBundleShortVersionString`（0.1.0）、`CFBundleVersion`、`LSMinimumSystemVersion=13.0`、`LSUIElement=YES`、`NSHighResolutionCapable=YES`。

Phase 5 補/確認：

| 鍵 | 值 | 理由 |
|----|----|------|
| `CFBundleIconFile` / icon 檔 | `AppIcon.icns`（佔位） | 雙擊/選單/關於顯示 icon；佔位即可（§10） |
| `CFBundleShortVersionString` | 升到 `0.5.0`（Phase 5） | 版本語意對齊 Phase（`04` §1）；由 script 變數集中管理 |
| `CFBundleVersion` | 遞增 build 號 | — |
| `LSUIElement` | `YES`（維持） | agent app、無 Dock（`04` §6.4） |
| `LSMinimumSystemVersion` | `13.0`（維持） | SMAppService 需 macOS 13+ |
| `NSHighResolutionCapable` | `YES`（維持） | Retina 銳利像素 |

### 5.3 icon（佔位）

- 產一個佔位 `AppIcon.icns`：可用陶紅 `#C56A4E` 方塊 / 「🚶」渲染成 1024²，`iconutil` 轉 `.icns`。腳本化或手動預先產好放 `Resources/`。
- **正式 icon 留 Phase 4 美術**（§10 待決）。佔位只要能讓雙擊/關於不空白。

### 5.4 release 建置 + 安裝位置

- 腳本流程：`swift build -c release` → 組 bundle → 放 icon → 寫 Info.plist → `codesign`（§6 依決策）→（可選）notarize/staple。
- **是否需放 `/Applications` 才能穩定自啟**：**是，建議**。理由：
  - SMAppService 登入項指向 app 路徑；放使用者可搬動的位置（Downloads/桌面）易讓自啟指向失效或觸發 translocation（§2.3、§6.2 [待驗證]）。
  - **驗收流程**：build 完把 `.app` **拖進 `/Applications`**，從那裡雙擊、再測自啟。腳本可印一行提示「請將 FindYourWay.app 移至 /Applications 後再啟用開機自啟」。
  - 個人自用亦可放 `~/Applications`（使用者家目錄下的 Applications），同屬穩定位置；避免從 `.build/` 或 Downloads 直接跑正式驗收。

---

## 6. 簽章決策（重要 · 供 Fable / 使用者定案）

> **核心問題（需使用者拍板）：這支 App 只自己一台 Mac 用，還是要分發給別人？有沒有 Apple Developer 帳號（$99/年）？** 答案直接決定走 (a) 還是 (b)。

### 6.1 三條路對照

| 路線 | 簽章 | 公證(Notarize) | 需要 | Gatekeeper 行為 | SMAppService 相容性 | 適用 |
|------|------|----------------|------|-----------------|---------------------|------|
| **(a) 個人自用** | ad-hoc（`codesign -s -`）或本地 Developer ID | **不公證** | 免帳號 | 首次雙擊被擋，需**右鍵「打開」→ 允許一次**（或系統設定→隱私與安全性→「仍要打開」）；之後正常 | **[待驗證]** ad-hoc 能否穩定 `register()` 並重開機自啟（§2.3）——本階段最高風險 | ✅ 個人、自己機器 |
| **(b) 分發給他人** | Developer ID Application 憑證簽章 | **需公證 + staple** | **Apple Developer 帳號 $99/年** | 雙擊直接開、無警告（公證通過） | 有效簽章，相容性最佳 | 要給別人下載時 |
| **(c) App Store** | App Store 憑證 | 走 App Store 審核 | 帳號 + **App Sandbox** | 商店安裝、無警告 | 沙盒下相容，但受沙盒功能限制 | ADR-008 **延後** |

### 6.2 各路線的 Gatekeeper / translocation 細節

- **(a) ad-hoc**：無 Developer ID，Gatekeeper 視為未識別開發者。從瀏覽器下載會帶 `com.apple.quarantine` 屬性 → 首次執行可能被 **path-translocation**（系統把 app 複製到隨機唯讀路徑執行），這會**破壞自啟的路徑穩定性**（§2.3）。**緩解**：自己 build 的 app 通常無 quarantine 屬性（非下載而來）；若有，`xattr -dr com.apple.quarantine FindYourWay.app` 可清除。移入 `/Applications` 後 translocation 不觸發。→ 個人自用可接受，但務必實測自啟。
- **(b) Developer ID + Notarize**：公證後 staple 票據，Gatekeeper 放行、無 translocation、自啟路徑穩定。分發（別人下載）唯一乾淨路徑。
- **(c) App Store**：受 App Sandbox 限制。`04` §7.5 / R3 指出**全域滑鼠監聽（Phase 4 點角色互動策略 B）與沙盒有潛在衝突**；ADR-008 已據此**延後 App Store 決策**。Phase 5 不走。

### 6.3 建議

- **個人自用 → 走 (a) ad-hoc，不公證。** 最省、免帳號、夠用。代價：首次右鍵「打開」一次；且 **ad-hoc × SMAppService 自啟需在真機驗證能否共存**（§2.3、§9 R1）。若實測 ad-hoc 無法穩定自啟，退而求其次：使用者若已有 Apple Developer 帳號，可用本地 Developer ID 簽章（仍不公證，自用），簽章有效性較高、自啟較穩。
- **要分發給他人 → 才需 (b) Developer ID + Notarize（$99/年）。** 公證只在分發時才必要，個人自用不必為此付費。
- **(c) App Store 延後**（ADR-008 不變）。
- **腳本設計**：`build_app.sh` 接一個 `SIGN_MODE` 參數 / 環境變數（`adhoc`（預設）| `devid`），預設 ad-hoc；`devid` 模式才跑 Developer ID 簽章與（可選）notarize。這樣同一支腳本兼顧 (a)/(b)，決策交給呼叫者。

---

## 7. 多螢幕 / Spaces 常駐行為（`04` §7.4）

長駐後可能經歷睡眠喚醒、接拔外接螢幕、切換 Space。既有已設 `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`（跨 Space 陪伴）。Phase 5 補常駐穩定性：

| 情境 | 行為 | 實作 |
|------|------|------|
| 螢幕參數變更（接拔/解析度） | 桌寵重新錨定到有效螢幕的右下角，不跑到畫面外 | 監聽 `NSApplication.didChangeScreenParametersNotification`，重算 `PetWindowConfig.bottomRightFrame`（純函式已有，可測）並套用 |
| 主螢幕消失（拔掉外接） | 落回 `NSScreen.main` 或第一個可用螢幕 | 取螢幕時 fallback（既有 `AppDelegate` 已有 `NSScreen.main ?? 預設 frame` 的雛形，擴充到螢幕變更事件） |
| 切換 Space | 跟著出現（`.canJoinAllSpaces`），留意切換位移/閃爍 | 沿用既有；`04` R4 [待驗證] 觀感 |
| 全螢幕 App 之上 | `.fullScreenAuxiliary` 決定是否疊上；是否惱人屬 UX 決策 | 沿用；留 Fable UX 準則 |

### 7.1 位置記憶（偏好記住位置？）—— 待決建議

- **Phase 5 建議：不做「記住任意拖曳位置」，維持「恆定右下角」**（`06`/ADR-009 桌寵定位語言）。桌寵目前不可拖曳（`ignoresMouseEvents=true` 整窗穿透），拖曳本身是 Phase 4 互動範疇。
- 若未來 Phase 4 開放拖曳，再考慮把「上次位置 / 偏好落位螢幕」記進 UserDefaults（偏好，非主存檔）。**此為待決（§10），Phase 5 先不引入位置持久化**，避免與尚不存在的拖曳功能耦合。
- 螢幕變更時的重新錨定（上表）是**穩定性**需求，與「記憶使用者自訂位置」是兩件事；Phase 5 只做前者。

---

## 8. 測試（TDD 清單 + 人工驗收清單）

> 專案級紀律：`swift test` 全綠才算完成（`05` §測試紀律）。打包/簽章/自啟屬人工驗收；偏好資料層抽純函式測試。

### 8.1 TDD 清單（可自動化，放 `Tests/FindYourWayCoreTests/`）

| 測試檔 | 覆蓋 | 範例斷言 |
|--------|------|----------|
| `PreferencesStoreTests` | UserDefaults 讀寫往返、預設值、與注入的 defaults 隔離 | 寫入 `reduceMotion=true` → 讀回 true；空 defaults 讀出預期預設；不污染 standard defaults |
| `MotionSettingsTests` | reduce-motion 解析純函式 | `effectiveReduceMotion(userOverride:nil, systemPref:true)==true`（跟隨系統）；`userOverride:false, systemPref:true → false`（使用者覆寫勝出） |
| `StatusCardTests` | 狀態卡片文字組裝（純函式：`GameState → 顯示字串`） | 給 `landmarksPassed=["old_bridge"]` → 「已路過：一座舊石橋」；`companionJoined=false` → 不含相遇行；章節名對映 `GrowthStage` |
| `PetWindowConfigTests`（既有，補案例） | 螢幕變更後重新錨定計算 | 換一組 `visibleFrame` → origin 仍落在新螢幕右下角、不越界 |

- 這些皆放 `FindYourWayCore`，不啟 NSApplication、不開視窗、不呼叫 SMAppService（避免 headless/CI 卡住或改動系統登入項）。
- 狀態卡片的**文字組裝邏輯**務必抽成 Core 純函式（吃 `GameState` 吐字串），才可測；`StatusItemController` 只負責把字串塞進 NSMenuItem。

### 8.2 人工驗收清單（無法自動化）

1. `build_app.sh` 產出 `.app`，移入 `/Applications`，雙擊啟動（記錄首次是否需右鍵「打開」）。
2. 選單列出現圖示；點開有狀態卡片（走多遠/章節/相遇）+ 偏好/顯示隱藏/結束。
3. 偏好視窗可開、可互動（能點 toggle、能關）、關於顯示正確版本號。
4. **開機自啟**：偏好開「登入時啟動」→ `SMAppService.status` 變 `.enabled`（或 `.requiresApproval` 走允許流程）→ **登出/重開機**→ 自動啟動。關掉開關 → 重開機不啟動。
5. **reduce motion**：開關切換，確認旗標寫入 UserDefaults；（Phase 4 功能上線後）晝夜/粒子確實停。
6. **多螢幕**：接/拔外接螢幕，桌寵重新落到有效螢幕右下角、不消失於畫面外。
7. **簽章 × 自啟共存**（最關鍵）：以決定的 `SIGN_MODE`（預設 ad-hoc）實測「重開機後真的自啟」——驗證 §9 R1。
8. **常駐一天**：長掛不崩、選單列不消失、CPU/能耗維持 Low（沿用 `04` §6.2 指標）。

---

## 9. 檔案結構、施工順序、風險

### 9.1 檔案結構（延續 SPM 分層）

```
FindYourWay/
├─ scripts/
│  └─ build_app.sh                         # 擴充：icon / codesign / (可選)notarize / Info.plist 補欄位 / SIGN_MODE 參數
├─ Resources/
│  └─ AppIcon.icns                          # 佔位 icon（正式留 Phase 4）
├─ Sources/
│  ├─ FindYourWayCore/                      # 可測邏輯（headless）
│  │  └─ Preferences/
│  │     ├─ Preferences.swift               # 純值模型 + UserDefaults key 常數
│  │     ├─ PreferencesStore.swift          # UserDefaults 讀寫（可注入 defaults）
│  │     ├─ MotionSettings.swift            # reduce-motion 解析純函式
│  │     └─ StatusCardText.swift            # GameState → 狀態卡片顯示字串（純函式）
│  └─ FindYourWay/                          # executable（runtime 難測部分）
│     ├─ Menu/
│     │  └─ StatusItemController.swift       # 擴充：狀態卡片 + 偏好入口（既有結構上加）
│     ├─ Preferences/
│     │  ├─ PreferencesWindowController.swift# 持有/複用偏好 NSWindow + NSHostingController
│     │  └─ PreferencesView.swift            # SwiftUI 表單（自啟/reduce motion/關於）
│     ├─ Login/
│     │  └─ LoginItemService.swift           # SMAppService register/unregister/status 封裝
│     └─ App/AppDelegate.swift               # 擴充：組裝偏好/自啟、螢幕變更監聽、供狀態卡片取 GameState
└─ Tests/FindYourWayCoreTests/
   ├─ PreferencesStoreTests.swift
   ├─ MotionSettingsTests.swift
   └─ StatusCardTests.swift
```

### 9.2 施工順序（逐步可驗）

1. **偏好資料層（TDD 先行）**：`Preferences` / `PreferencesStore` / `MotionSettings` / `StatusCardText` + 測試 → `swift test` 綠。
2. **狀態卡片**：`StatusItemController` 用 `StatusCardText` 組字串，掛非可點 `NSMenuItem`；`AppDelegate` 提供 `menuWillOpen` 時的 `GameState` 快照。
3. **偏好視窗**：`PreferencesView`（SwiftUI）+ `PreferencesWindowController`（NSHostingController）；「偏好設定…」選單項開啟；接 `PreferencesStore`（reduce motion）。
4. **開機自啟**：`LoginItemService` 封裝 SMAppService；偏好「登入時啟動」toggle 綁 `status`（§2.2）。
5. **多螢幕穩定**：`AppDelegate` 監聽 `didChangeScreenParameters`，重算 frame。
6. **打包**：擴充 `build_app.sh`（icon、Info.plist 版本、`SIGN_MODE` 預設 ad-hoc）；產 `.app` → `/Applications`。
7. **reduce-motion 消費點**：render 層留一個受 effective 旗標控制的開關（Phase 4 晝夜/粒子接上）。
8. 對照 §0 DoD + §8.2 人工驗收；重點跑 §9.3 R1（簽章 × 自啟）。

### 9.3 風險與 [待 Phase 5 驗證]

| # | 風險 / 未知 | 影響 | 驗證方式 |
|---|-------------|------|----------|
| **R1** | **ad-hoc 簽章 × SMAppService 自啟能否共存**（§2.3/§6.3）——最高風險 | 個人自用路線 (a) 是否成立 | 真機：ad-hoc 簽 → 移 `/Applications` → 開自啟 → 重開機看是否啟動；不行則退 Developer ID |
| R2 | **SMAppService 安裝位置敏感度**：非 `/Applications` 是否失效 / translocation 破壞路徑 | 自啟可靠性 | 分別從 Downloads / `/Applications` 測 register + 重開機 |
| R3 | **agent app（`.accessory`）開 SwiftUI 偏好視窗的焦點/互動**：能否正常吃鍵盤點擊、`NSApp.activate` 的正確用法 | 偏好視窗可用性 | 實測開視窗、切走再回、關閉後桌寵行為 |
| R4 | **NSHostingView 嵌入 NSMenu / popover** 的尺寸與生命週期（若狀態卡片改用 SwiftUI） | 狀態卡片方案 | 故 §3.3 建議狀態卡片先用純 AppKit 規避 |
| R5 | `.requiresApproval` 流程與 `openSystemSettingsLoginItems()` 的 UX | 自啟開關體感 | 首次註冊實測是否需使用者到登入項目允許 |
| R6 | **App Sandbox 若未來上架**：全域滑鼠監聽衝突（`04` R3 / ADR-008） | App Store 可行性 | 延後；Phase 5 不走沙盒 |
| R7 | Gatekeeper quarantine / 首次「右鍵打開」對非技術使用者的門檻 | (a) 路線體感 | 記錄實際步驟，必要時寫一頁安裝說明 |

---

## 10. 待決 / 設計分叉（供 Fable / 使用者）

1. **簽章路線 (a/b/c) —— 需使用者拍板**：**只自己一台 Mac 用還是要分發給別人？有無 Apple Developer 帳號（$99/年）？**
   - Opus 建議：**自用走 (a) ad-hoc 不公證**；要分發才走 (b) Developer ID + Notarize；(c) App Store 依 ADR-008 延後。腳本預設 ad-hoc、`SIGN_MODE=devid` 可切。
2. **App icon：佔位 vs 正式** —— Opus 建議 Phase 5 用**佔位**（陶紅方塊/🚶 → `.icns`），**正式 icon 留 Phase 4 美術**一起做（避免美術兩次工）。
3. **狀態卡片資訊密度** —— Opus 建議**三行封頂**（走多遠/章節/相遇，且相遇未達成時整行隱藏），全走 glanceable、無裸數字。是否要更少（只章節名）或加「旅程日誌」入口，請 Fable 定。
4. **狀態卡片技術**：Phase 5 用純 AppKit（§3.3）；未來若要圖文 popover（地標剪影）再上 `NSHostingView`。是否現在就投資 SwiftUI popover？Opus 建議否。
5. **位置記憶**：Phase 5 維持恆定右下角、不做位置持久化（§7.1）；待 Phase 4 拖曳功能出現再議。
6. **音量預留**：偏好放「灰掉的音量 slider」還是「Phase 4 才出現」？Opus 傾向**先不放**（Hick's law，少一個無效控制項更乾淨），Phase 4 音效上線再加。

---

*本文件為 Phase 5 草擬，待 Fable review 定案。SMAppService / 簽章 / 沙盒 / SwiftUI-in-agent 的行為以官方文件與真機實測為準；標 [待 Phase 5 驗證] 者不得當既定事實施工。R1（ad-hoc × 自啟共存）為本階段最高驗證優先。*
