# Find Your Way — 技術架構 (Architecture)

> 狀態：**已審閱 (Accepted)** — Fable review 通過（2026-07-03）。作為 Sonnet / Codex 施工依據。
> 遵循 `00_CONSTITUTION.md`：技術棧 Swift + SpriteKit（ADR-001）、桌寵式懸浮視窗（ADR-002）、純放置陪伴（ADR-003）。
> 凡標記 **[待 Phase 1 驗證]** 者，為 API 行為或系統限制尚需在真機/模擬環境確認，不得當作已知事實施工。
>
> **Fable review 註記**：關鍵 API 設定逐項驗證正確（透明 NSWindow 組合、SKView.allowsTransparency、SMAppService↔macOS 13、Codable+JSON 原子寫入、模擬/渲染解耦、時間戳離線結算）。R1（透明合成電耗底噪）列為 Phase 1 最高驗證優先。OQ-2/OQ-4 技術方案採納，產品參數（離線速率/上限、多存檔與否）併入 OQ 綜合定案。

---

## 0. 本文件涵蓋範圍

| 章節 | 內容 | 對應需求 |
|------|------|----------|
| 1 | 技術棧與版本 | 最低系統、Swift、框架分工 |
| 2 | 透明懸浮桌寵視窗（核心） | NSWindow / SKView 設定、點擊穿透 |
| 3 | 專案結構 | 目錄樹、模組切分 |
| 4 | 模擬與時間推進 | 遊戲迴圈、離線推進、降頻策略 |
| 5 | 存檔持久化 | 存哪、用什麼、schema 版本化 |
| 6 | 效能與省電 | 常駐軟體省電策略 |
| 7 | 打包與常駐 | Bundle、自啟、選單列、多螢幕/Spaces |
| 8 | 待決問題技術建議 | OQ-2 離線推進、OQ-4 存檔 |
| 9 | 風險與未知 | Phase 1 需驗證清單 |

---

## 1. 技術棧與版本

### 1.1 建議版本

| 項目 | 建議 | 理由 |
|------|------|------|
| 最低 macOS 版本 | **macOS 13 Ventura** | `SMAppService`（新版開機自啟 API）需 macOS 13+。降到 12 以下要改用已 deprecated 的 `SMLoginItemSetEnabled`，不值得。13 已是主流普及版本。 |
| 語言 | **Swift 5.9+**（Xcode 15+ 開發） | 現行穩定版；`if/switch` 表達式、macro 等便利特性可用。不強制 Swift 6 嚴格並行模式（見 6.5）。 |
| 建置工具 | **Xcode 專案（.xcodeproj）** | SpriteKit 的 `.sks`/貼圖圖集（Texture Atlas）與資源 pipeline 由 Xcode 管理最順。SPM 純套件不利於資源打包。 |
| UI 主體 | **AppKit（NSWindow / NSApplication）** | 透明無邊框置頂視窗與 hit-testing 只有 AppKit 有完整掌控。 |
| 遊戲渲染 | **SpriteKit（SKView / SKScene）** | 2D sprite 動畫、Texture Atlas、粒子，貼合像素風放置。 |
| 選單列/偏好設定 | **SwiftUI（局部）** | 見 1.3。 |

### 1.2 框架分工

```
NSApplication (AppKit)          ← App 生命週期、LSUIElement 隱藏 Dock
 ├─ NSStatusItem (AppKit)       ← 選單列常駐入口
 ├─ PetWindow: NSWindow (AppKit)← 透明無邊框置頂懸浮視窗（核心）
 │    └─ SKView (SpriteKit)     ← 透明背景，承載遊戲場景
 │         └─ GameScene: SKScene← 角色、背景、動畫、模擬掛載點
 └─ 偏好設定 Window (SwiftUI)   ← 選項頁（可選，Phase 5）
```

### 1.3 是否需要 SwiftUI

**建議：SwiftUI 只用於「選單列選單」與「偏好設定視窗」，不碰桌寵渲染。**

- 桌寵渲染區塊必須是 SpriteKit + AppKit，SwiftUI 無法精細控制透明/hit-test/window level。
- 但偏好設定（開關自啟、音量、推進速率顯示等）用 SwiftUI 開發最快，且可用 `NSHostingController` 包進一個普通 `NSWindow`。
- 選單列 popover 若簡單，用 AppKit `NSMenu` 即可；若要做較豐富的狀態卡片，再用 SwiftUI `NSHostingView`。
- **原則**：SwiftUI 是「附屬 UI 的加速器」，非架構主線。Phase 1 完全不需要 SwiftUI；Phase 5 打包時再引入。

---

## 2. 透明懸浮桌寵視窗（核心技術點）

> 這是本專案風險最高、最需 Phase 1 驗證的部分。以下設定為業界成熟做法的組合，但**點擊穿透的精確 hit-test 行為需實測**。

### 2.1 目標行為

1. 視窗背景完全透明，只看得到角色 sprite（無標題列、無邊框、無陰影方框）。
2. 永遠浮在其他視窗之上（置頂）。
3. 出現在所有 Spaces / 全螢幕 App 之上（跨桌面陪伴）。
4. **點擊穿透**：點在「角色身上」有反應（未來微互動 OQ-3）；點在「空白透明區」則穿透到底下的桌面/App，像沒這個視窗一樣。
5. 不搶焦點（不把使用者正在打字的 App 踢到背景）。

### 2.2 NSWindow 關鍵設定

```swift
// 示意，非完整實作
let window = NSWindow(
    contentRect: screenRect,
    styleMask: [.borderless],           // 無標題列、無邊框
    backing: .buffered,
    defer: false
)
window.isOpaque = false                 // 允許透明
window.backgroundColor = .clear         // 背景透明（關鍵）
window.hasShadow = false                // 去掉視窗陰影方框
window.level = .floating                // 置頂（見 2.4 討論層級選擇）
window.collectionBehavior = [
    .canJoinAllSpaces,                  // 出現在所有 Spaces
    .fullScreenAuxiliary,               // 疊在全螢幕 App 之上
    .stationary                         // 切換 Space 時不隨動畫位移（待驗證手感）
]
window.ignoresMouseEvents = true        // 預設整窗穿透，見 2.5 動態切換
window.isMovableByWindowBackground = false
```

| 設定 | 值 | 作用 |
|------|----|------|
| `styleMask` | `.borderless` | 去除系統邊框/標題列 |
| `isOpaque` | `false` | 開啟透明合成 |
| `backgroundColor` | `.clear` | 背景不畫任何顏色 |
| `hasShadow` | `false` | 移除包住整窗的陰影框 |
| `level` | `.floating` 或自訂 | 置頂層級（見 2.4） |
| `collectionBehavior` | 見上 | 跨 Spaces / 全螢幕行為 |
| `ignoresMouseEvents` | 動態 | 穿透總開關（見 2.5） |

### 2.3 SKView 嵌入並保持透明背景

`SKView` 與 `SKScene` 兩層都要設透明，否則會出現黑底或不透明底：

```swift
skView.allowsTransparency = true        // SKView 允許透明
skView.wantsLayer = true
// SKScene:
scene.backgroundColor = .clear          // 場景背景透明
scene.scaleMode = .resizeFill
```

- **要點**：`SKView.allowsTransparency = true` 是讓 GPU 合成保留 alpha 的關鍵；漏設會得到黑底。
- SKView 作為 `window.contentView`（或其子 view）。
- 像素風需關閉貼圖平滑：Texture 使用 `.nearest` filtering（`texture.filteringMode = .nearest`），避免縮放糊化。
- **[待 Phase 1 驗證]**：透明 SKView 疊在桌面上時的合成效能與電耗（透明合成成本高於不透明），需實測 4.2/6 的降頻是否足夠。

### 2.4 置頂層級的選擇

- `.floating` = `NSWindow.Level(kCGFloatingWindowLevel)`，浮在一般視窗上。
- 若要更頑固地蓋過幾乎所有東西，可用更高的自訂 level（如 `.statusBar`、`.screenSaver` 對應數值），但**層級越高越容易蓋到系統 UI（選單列、Dock、通知），觀感與禮貌上不佳**。
- **建議**：起手用 `.floating`。是否要在全螢幕影片/簡報上仍顯示，屬產品決策（會不會惱人），留給 Fable 定 UX 準則後再調。

### 2.5 點擊穿透與 hit-testing（最關鍵細節）

有兩種策略，建議採 **B（動態切換）**：

**策略 A：整窗永久穿透**
`window.ignoresMouseEvents = true`。整個視窗完全不吃滑鼠，桌寵永遠不能被點。實作最簡單，但無法支援 OQ-3 的「點角色有反應」。適合 Phase 1（角色還不需互動）。

**策略 B：動態穿透（依游標是否在角色不透明像素上切換）** ← 建議最終方案
- 追蹤全域滑鼠位置（`NSEvent.mouseLocation` 或 `addGlobalMonitorForEvents`）。
- 每次移動時，換算游標在角色貼圖上的座標，檢查該點 alpha 是否 > 門檻（角色實體像素）。
- 在角色實體上 → `window.ignoresMouseEvents = false`（吃點擊，可觸發互動）；
- 在透明區 → `window.ignoresMouseEvents = true`（穿透到桌面）。
- alpha 命中測試可用「維護一份角色目前 frame 的 alpha mask / bitmap」在 CPU 端查詢，避免每幀讀 GPU。

**[待 Phase 1 / Phase 4 驗證]**：
- 全域滑鼠監聽 `addGlobalMonitorForEvents` 在**沙盒（App Sandbox）下是否受限**，以及是否需要「輔助使用權限（Accessibility）」。這會影響是否上架 App Store（見 7.5 / 9）。
- `ignoresMouseEvents` 動態切換的延遲是否會造成「點得到卻慢半拍」的手感問題。
- 更省事的替代：不做全域監聽，改用 `NSTrackingArea` + 視窗內事件，但透明穿透窗能否穩定收到 hover 事件需實測。

> Phase 1 只需策略 A（整窗穿透），把「會走路、不擋操作」做出來即可。策略 B 是 Phase 4 微互動時的工作，現在只需把它列為架構預留。

---

## 3. 專案結構

### 3.1 目錄樹建議

```
FindYourWay/
├─ FindYourWay.xcodeproj
├─ FindYourWay/
│  ├─ App/                          # App 生命週期與入口
│  │  ├─ AppDelegate.swift          # NSApplicationDelegate，組裝各層
│  │  ├─ main.swift 或 @main        # 進入點
│  │  └─ AppEnvironment.swift       # 依賴組裝（DI 容器，手寫即可）
│  │
│  ├─ Window/                       # 視窗層（AppKit）
│  │  ├─ PetWindow.swift            # NSWindow 子類：透明/置頂/穿透設定
│  │  ├─ PetWindowController.swift  # 視窗生命週期、多螢幕定位
│  │  ├─ ClickThrough.swift         # 點擊穿透 / alpha hit-test 邏輯
│  │  └─ ScreenManager.swift        # 多螢幕、Spaces、螢幕變更監聽
│  │
│  ├─ Menu/                         # 選單列常駐
│  │  ├─ StatusItemController.swift # NSStatusItem + NSMenu
│  │  └─ PreferencesWindow.swift    # 偏好設定（SwiftUI via NSHostingController，Phase 5）
│  │
│  ├─ Scene/                        # SpriteKit 遊戲場景層
│  │  ├─ GameScene.swift            # SKScene：掛載角色/背景/更新循環
│  │  ├─ CharacterNode.swift        # 角色 sprite + 走路動畫狀態
│  │  ├─ ParallaxBackground.swift   # 橫向捲軸背景（分層視差）
│  │  └─ SceneCoordinator.swift     # 場景與模擬層的橋接
│  │
│  ├─ Simulation/                   # 模擬 / 推進系統（與渲染解耦，可單元測試）
│  │  ├─ GameState.swift            # 純資料模型（Codable）：距離、等級、時間戳
│  │  ├─ SimulationEngine.swift     # 推進規則（線上 tick + 離線結算共用）
│  │  ├─ OfflineProgress.swift      # 離線推進結算（依 OQ-2）
│  │  ├─ TimeProvider.swift         # 可注入時鐘（測試用）
│  │  └─ EnergyPolicy.swift         # 前景/背景/閒置降頻策略
│  │
│  ├─ Persistence/                  # 存檔
│  │  ├─ SaveStore.swift            # 讀寫 Application Support
│  │  ├─ SaveSchema.swift           # 版本化 schema + 遷移
│  │  └─ Migrations/                # v1→v2 等遷移器
│  │
│  ├─ Resources/                    # 資源
│  │  ├─ Characters.atlas/          # 角色貼圖圖集（走路循環等）
│  │  ├─ Backgrounds/               # 背景分層圖
│  │  └─ Assets.xcassets            # App icon、選單列 icon
│  │
│  └─ Support/
│     ├─ Info.plist                 # LSUIElement、最低版本等
│     └─ FindYourWay.entitlements   # 沙盒/權限（見 7.5）
│
└─ FindYourWayTests/                # 單元測試（重點測 Simulation / Persistence）
   ├─ SimulationEngineTests.swift
   ├─ OfflineProgressTests.swift
   └─ SaveMigrationTests.swift
```

### 3.2 分層原則

- **模擬層（Simulation）與渲染層（Scene）解耦**：`SimulationEngine` 只操作 `GameState` 純資料，不 import SpriteKit。渲染層讀 `GameState` 來畫。
  - 好處：離線推進（無畫面）與線上推進共用同一套規則；模擬可脫離 UI 做單元測試（憲法「先文件後實作」下，規則正確性可被驗證）。
- **視窗層（Window）不含遊戲邏輯**：只負責「一個透明置頂穿透的容器」。
- **依賴方向**：App → Window/Menu → Scene → Simulation → Persistence（單向，下層不反向依賴上層）。

---

## 4. 模擬與時間推進

### 4.1 遊戲迴圈 vs 事件驅動

採 **混合**：

- **渲染/動畫**：SpriteKit 的 `SKScene.update(_ currentTime:)` 幀迴圈負責視覺（走路動畫、視差捲動）。此迴圈只做「表現」，且可大幅降頻/暫停（見 6）。
- **模擬推進**：不綁死在每幀。用**低頻 tick**（如每 1～5 秒一次，`Timer` 或 SpriteKit action）推進 `GameState`（距離累加、事件擲骰）。放置類推進本質是慢變數，不需要 60fps。
- **狀態變化事件驅動**：偶發事件、升級、跨地標等用事件觸發回呼，通知渲染層播動畫。

> 關鍵解耦：**模擬時間以真實時鐘為準，不以幀數為準**。這樣降頻或暫停 render 都不影響「走了多遠」的正確性，也讓離線推進與線上推進用同一套公式。

### 4.2 更新頻率策略（省電核心，見 6）

| 狀態 | 渲染 (SKView) | 模擬 tick | 說明 |
|------|--------------|-----------|------|
| 前景 / 使用者可見且互動 | 正常（可上限 30fps） | 每 1～2 秒 | 桌寵通常不需 60fps；30 已流暢且省一半電 |
| 可見但使用者忙（長時間無操作） | 降至 ~10fps 或暫停動畫 | 每 5 秒 | 只保留必要生命感 |
| 視窗被完全遮擋 / 螢幕休眠 | `isPaused = true`，停 render | 每 30～60 秒或改為時間戳法 | 看不到就別畫 |
| App 進背景 / 選單列隱藏桌寵 | 停 render | 停 tick，僅記時間戳 | 下次顯示時用離線結算補上 |

**[待 Phase 1 驗證]**：「視窗被其他視窗完全遮擋」是否能可靠偵測。`occlusionState`（`NSWindow.occlusionState`）理論上可用，但置頂懸浮窗幾乎不會被遮擋（它總在最上層），所以此訊號可能意義不大；更實際的省電訊號是「螢幕休眠 / 系統閒置 / 使用者切走」。

### 4.3 離線推進（OQ-2 的技術實作）

核心機制 = **時間戳差值結算（deterministic catch-up）**：

1. 每次存檔與每個 tick，記錄 `lastActiveTimestamp`（真實時鐘）。
2. App 啟動或從休眠恢復時，讀出 `lastActiveTimestamp`，計算 `elapsed = now - last`。
3. 用**同一套推進公式**一次算出 `elapsed` 期間的推進結果（距離、可能發生的事件），套用到 `GameState`。
4. 用一段短動畫或旅程日誌「你不在時走了 N 公里、路過 X」呈現，強化「默默前行」的療癒感（呼應 ADR-003：靠時間感/旅程感營造正回饋）。

實作注意：

- **上限（cap）**：離線推進要設封頂（例如最多結算 24 小時），避免關機兩週回來爆量、也避免數值意義崩壞。上限值是產品手感，留 Fable 定。
- **時鐘防作弊/防跳動**：使用者改系統時間會導致 `elapsed` 為負或暴增。處理：`elapsed < 0` 視為 0；`elapsed` 超上限則截斷。是否嚴防作弊視定位（純陪伴、無排行榜，寬鬆即可）。
- **確定性**：離線期間的偶發事件建議用「以 timestamp 為 seed 的確定性亂數」或「單純以時間比例累積」，確保結算可重現、不因結算時機不同而不同。
- **省電最大來源**：背景時**完全不跑 tick**，只在回到前景時做一次結算 —— 這是常駐軟體省電的關鍵手法。

---

## 5. 存檔持久化

### 5.1 存哪 / 用什麼

| 決策 | 建議 |
|------|------|
| 格式 | **Codable + JSON**（人類可讀、易 debug、易手動修、易版本遷移） |
| 位置 | `~/Library/Application Support/FindYourWay/save.json` |
| 取得路徑 | `FileManager.default.url(for: .applicationSupportDirectory, ...)` + bundle id 子目錄 |
| 寫入方式 | **原子寫入**（`Data.write(to:options: .atomic)`）避免寫一半崩潰壞檔 |
| 備份 | 寫新檔前保留上一份 `save.bak.json`，壞檔時可回退 |

**為何不用 UserDefaults / Core Data / SwiftData**：

- UserDefaults：適合小偏好設定（音量、開關），**不適合**遊戲狀態主檔。可用它存「輕量偏好」。
- Core Data / SwiftData：對本專案「單一玩家、單一存檔、扁平狀態」是過度工程，增加複雜度與相依。
- JSON 檔最貼合「單檔、可版本化、可被別的 AI/人讀懂」的專案精神。

### 5.2 Schema 版本化

```jsonc
{
  "schemaVersion": 1,          // 每次結構破壞性變更 +1
  "lastActiveTimestamp": 1751500000,
  "character": { "level": 1, "distance": 1234.5 },
  "journey": { "landmarksPassed": ["hill_01"] }
  // ...
}
```

- `SaveSchema.swift` 定義當前版本結構；`SaveStore` 讀檔時先看 `schemaVersion`。
- 版本落後 → 依序跑 `Migrations/`（v1→v2→…）升級後再用。
- 版本高於程式（使用者裝了舊版）→ 安全降級策略（唯讀 / 提示更新），避免寫壞新格式。
- **原則**：只增欄位、給預設值，優先向後相容；破壞性改動才升版本。

### 5.3 存檔時機

- 每次離線結算後、每 N 分鐘定期、App 即將終止（`applicationWillTerminate`）、進入背景/休眠前。
- 每次 tick 更新記憶體中的 `lastActiveTimestamp`，但寫檔可節流（不必每秒寫盤，省 IO 與 SSD 壽命）。

---

## 6. 效能與省電

> 常駐一整天，CPU/RAM/電耗必須低。這是 ADR-001 選原生的主要理由，實作上要兌現。

### 6.1 關鍵策略清單

1. **模擬與幀率脫鉤**（4.1）：慢變數用低頻 tick，不靠 60fps 前進。
2. **降幀**：桌寵 render 上限設 30fps（`SKView.preferredFramesPerSecond = 30`），忙碌/閒置時再降到 10 或暫停。
3. **`SKView` / `SKScene.isPaused`**：看不到就停。螢幕休眠、使用者長時間閒置、桌寵被使用者隱藏時 `isPaused = true`，SpriteKit 會停止渲染與 action 計時。
4. **背景全停 tick**：進背景/休眠不跑模擬，回前景用時間戳結算（4.3）。這是省電最大杠杆。
5. **避免透明合成浪費**：透明視窗合成成本較高，故「不動時不重繪」尤其重要（配合 3）。
6. **貼圖圖集（Texture Atlas）**：角色/背景用 atlas，減少 draw call 與記憶體。
7. **粒子/特效克制**：偶發特效短暫且低粒子數，用完即移除節點，避免常駐粒子系統燒電。
8. **暫停動畫而非銷毀節點**：頻繁增刪節點成本高；改用 `isPaused` 與隱藏。
9. **Timer 合併與容忍度**：低頻 `Timer` 設較大 `tolerance`，讓系統合併喚醒（coalescing），對電池友善。
10. **監聽系統電源/休眠通知**：`NSWorkspace.willSleepNotification` / `didWakeNotification`、螢幕休眠通知，作為停/續的觸發源。

### 6.2 觀測指標（Phase 1/2 驗收用）

- 掛機 1 小時的平均 CPU%（目標：閒置時接近 0，個位數以下）。
- 常駐 RAM（目標：數十 MB 級）。
- 能耗評級（Xcode Energy Impact / `powermetrics`）在「Low」。
- **[待驗證]** 透明置頂 SKView 即使降幀，合成本身是否仍有固定電耗底噪，需實測後決定「完全靜止時是否 `isPaused` 停到底」。

### 6.3 記憶體

- 資源按需載入、離開場景釋放；背景圖用合理解析度（像素風本身低解析，天然省記憶體）。

### 6.4 App 生命週期與 Dock

- `Info.plist` 設 `LSUIElement = YES`（Agent App）：**不顯示 Dock 圖示、不佔用 Dock**，只以選單列存在，符合桌寵定位。

### 6.5 並行策略

- 不在 Phase 1 引入 Swift 6 嚴格並行；模擬層用簡單的主執行緒 tick + 值型別 `GameState` 即可，避免過早並行複雜度。存檔 IO 可放背景 queue。

---

## 7. 打包與常駐

### 7.1 App Bundle

- 標準 `.app` bundle，Xcode 建置。含 Info.plist、entitlements、資源 atlas。
- 發佈需 **Developer ID 簽章 + Notarization**（若走 App Store 外分發）；或 App Store 上架（受沙盒限制，見 7.5）。

### 7.2 開機自啟

- **`SMAppService.mainApp.register()`**（macOS 13+）：現代、無需 helper bundle 的做法。使用者在偏好設定切換「開機自動啟動」。
- 舊 API `SMLoginItemSetEnabled` 已 deprecated，不採用。

### 7.3 選單列常駐（NSStatusItem）

- `NSStatusBar.system.statusItem(withLength:)` 建立選單列 icon。
- 選單提供：顯示/隱藏桌寵、偏好設定、（狀態卡片：目前走了多遠/等級）、離開。
- 因 `LSUIElement`，選單列是使用者操作 App 的主要入口。

### 7.4 多螢幕 / Spaces 行為

- **多螢幕**：`ScreenManager` 監聽 `NSApplication.didChangeScreenParametersNotification`，處理螢幕增減/解析度變更時重新定位桌寵。決定桌寵預設落在哪個螢幕（主螢幕右下角為建議預設），與是否可拖到別的螢幕（Phase 4）。
- **Spaces**：`collectionBehavior` 含 `.canJoinAllSpaces` → 桌寵跟著使用者出現在每個 Space（陪伴感一致）。`.fullScreenAuxiliary` 決定是否疊在全螢幕 App 上。
- **[待 Phase 1 驗證]**：跨 Space 切換時懸浮窗的位移/閃爍行為、以及在全螢幕 App 上顯示是否惱人（產品 UX 決策）。

### 7.5 沙盒與權限（影響上架與功能）

| 需求 | 沙盒影響 |
|------|----------|
| 讀寫 Application Support 存檔 | 沙盒下走 container 內路徑即可，無礙 |
| `SMAppService` 開機自啟 | 沙盒相容 |
| 全域滑鼠監聽（策略 B 點角色互動） | **[待驗證]** 可能需 Accessibility 權限或無法在沙盒下全域監聽 |
| 置頂 / 跨全螢幕懸浮 | 一般可行，但需實測沙盒限制 |

- **建議**：Phase 1～4 先以**非 App Store（Developer ID + Notarize）**為目標，保留必要的視窗/事件自由度；是否上架 App Store 待 Phase 5 依實測的沙盒限制再定。此決策留 Fable。

---

## 8. 針對待決問題的技術方案建議（供 Fable 定案）

### 8.1 OQ-2：離線推進機制

**建議：採用「時間戳差值結算 + 上限封頂 + 旅程日誌呈現」。**

- 機制如 4.3：關掉期間以真實時鐘差值一次結算，回來看到「你不在時走了多遠、路過哪裡」。
- 貼合 ADR-003：正回饋靠時間感/旅程感，非任務。離線推進正是放置類「默默前行」療癒感的核心手感。
- **需 Fable 定的產品參數**（非技術）：
  1. 是否要有離線推進（建議：要，這是放置類靈魂）。
  2. 推進速率（線上與離線是否同速；建議同速，最單純且誠實）。
  3. 離線結算上限（建議 8～24 小時，避免數值失控）。
  4. 是否嚴防改系統時間作弊（建議寬鬆，純陪伴無競爭）。

### 8.2 OQ-4：存檔策略

**建議：Codable + JSON，存 `~/Library/Application Support/FindYourWay/save.json`，原子寫入 + 備份 + `schemaVersion` 版本化。**

- 理由見第 5 章：單存檔、扁平狀態、可讀可遷移、可被其他 AI/人理解，最貼合專案精神。
- 輕量偏好設定（音量、自啟開關）可另存 UserDefaults，與遊戲主檔分離。
- **需 Fable 定**：存檔是否需要「多存檔/重新開始」功能（建議 Phase 1 單存檔即可，重來＝刪檔）。

---

## 9. 風險與未知（Phase 1 需驗證清單）

> 誠實列出。以下每項應在 Phase 1「會走路的空殼」期間以最小實驗驗證，再進 Phase 2+。

| # | 風險 / 未知 | 影響 | 驗證方式 |
|---|------------|------|----------|
| R1 | 透明 SKView 合成的**電耗底噪**：即使降幀，透明置頂視窗是否仍持續耗電 | 省電目標（核心賣點） | 掛機測 Energy Impact；比較 `isPaused` 停到底 vs 低幀 |
| R2 | **點擊穿透 hit-test 精度**：`ignoresMouseEvents` 動態切換 + alpha 命中的手感與延遲 | OQ-3 微互動可行性 | Phase 4 前先做原型；Phase 1 用整窗穿透繞過 |
| R3 | **全域滑鼠監聽 + 沙盒/Accessibility 權限** | 能否上架 App Store、互動功能 | 實測 `addGlobalMonitorForEvents` 在沙盒下行為 |
| R4 | **跨 Spaces / 全螢幕**懸浮窗的位移、閃爍、觀感 | 陪伴一致性與非侵入原則 | 多 Space + 全螢幕 App 實測 |
| R5 | **多螢幕**熱插拔/解析度變更時桌寵定位 | 穩定性 | 接拔外接螢幕測 `didChangeScreenParameters` |
| R6 | **系統時鐘變動**對離線結算的影響（負 elapsed、跳變） | 存檔正確性 | 手動改系統時間跑結算 |
| R7 | **置頂層級 vs 系統 UI**：`.floating` 是否被某些系統情境蓋掉或反而蓋到不該蓋的 | 觀感/禮貌 | 各情境（通知、Mission Control、Dock）實測 |
| R8 | 螢幕休眠 / App 背景的**可靠停更新訊號**來源 | 省電落地 | 測 `NSWorkspace` sleep/wake 與螢幕休眠通知 |
| R9 | Notarization / 簽章流程與（若走）App Store 沙盒清單 | 出貨 | Phase 5 前跑一次完整打包 |

---

## 附錄 A：Phase 1 最小技術骨架（施工順序建議）

1. Xcode 專案：`LSUIElement=YES`、最低 macOS 13、AppKit 入口（`AppDelegate`）。
2. `PetWindow`：borderless + clear + floating + canJoinAllSpaces + `ignoresMouseEvents=true`（策略 A）。
3. `SKView`（`allowsTransparency=true`）+ `GameScene`（`backgroundColor=.clear`），確認桌面透出、無黑底。
4. `CharacterNode`：一個像素方格 sprite + 走路循環（`SKAction` 或 atlas 動畫），`filteringMode=.nearest`。
5. `ParallaxBackground`：單層佔位背景橫向捲動。
6. `preferredFramesPerSecond=30`，掛機量一次 CPU/能耗（先建立 R1 基準）。
7. 驗收：桌面右下角小人走動、不擋操作、能耗 Low。

> Phase 1 **不做**：離線推進、存檔、點角色互動、選單列、自啟。那些是 Phase 2/4/5，本文件已預留掛載點。

---

*本文件為架構草稿，待 Fable review 定案。API 設定片段為示意，實作以官方文件為準；標記 [待 Phase 1 驗證] 者不得當作既定事實施工。*
