# Phase 1 建置規格 — Walking Skeleton（會走路的空殼）

> 狀態：**Accepted**（Fable 定案，2026-07-03）— Sonnet/Codex 施工依據。
> 依準則二「先文字後實作」。本規格是 `04_ARCHITECTURE.md` 附錄 A 的可施工細化版。
> **目標一句話**：桌面一角出現一個透明懸浮視窗，裡面一個陶紅像素方塊小人在橫向走動，不擋任何操作。

---

## 0. 驗收標準（Definition of Done）

1. `swift run`（或跑 build script 後開 .app）後，桌面**右下角**出現一個透明區域，裡面有：
   - 一條天空藍→草原綠的簡單背景色帶（單層或雙層佔位）。
   - 一個 **`#C56A4E` 陶紅 32×32 方塊**小人，以走路節奏水平移動（走到邊緣折返或循環）。
2. 視窗**無邊框、無標題列、無陰影方框、背景全透明**（只看到色帶與方塊，看不到視窗框）。
3. 視窗**置頂**、**出現在所有 Spaces**。
4. **整窗點擊穿透**：點在視窗任何地方都穿透到底下的桌面/App（Phase 1 用策略 A，不做互動）。
5. **不搶焦點**：出現時不把使用者正在用的 App 踢到背景。
6. **無 Dock 圖示**（agent app）。
7. 掛機時 **CPU 接近 0、能耗 Low**；跑一次 R1 能耗基準（見 §5）。
8. **`swift test` 全綠**：Palette / 走路邏輯 / 視窗定位計算皆有測試覆蓋（見 §5b）。
9. **可關閉（驗收後追加，見 §8）**：使用者**不需終端機**即可結束 App —— 選單列有「結束」。

> Phase 1 **不做**：離線推進、存檔、點角色互動、開機自啟、旅伴、正式美術。
> ~~選單列~~ → **修訂（2026-07-04 驗收發現）**：Phase 1 需要一個**極簡選單列**提供「結束」（見 §8）。完整選單列狀態卡片/自啟仍在 Phase 5。

---

## 1. 實作策略決策（Fable 對 `04` 的細化）

- **建置方式**：Phase 1 採 **Swift Package Manager executable target**，再用一支 `scripts/build_app.sh` 組出 `.app` bundle（含 `Info.plist`）。
  - 理由：Phase 1 是純色方塊、無 Texture Atlas，不需要 `.xcodeproj` 的資源 pipeline（`04` §1.1 選 xcodeproj 的理由在 atlas，Phase 1 用不到）。手寫 `.pbxproj` 易錯，SPM 更穩、更利於 AI 施工與 CI。
  - **遷移點**：Phase 4 需要 atlas / `.xcassets` 時，再評估遷移到 `.xcodeproj` 或用 SPM resources。此決策記於本節，不動 ADR-001（技術棧仍是 Swift+SpriteKit）。
- **無 Dock 圖示**：runtime 用 `NSApp.setActivationPolicy(.accessory)`（等同 `LSUIElement`，SPM executable 無 Info.plist 主導時用此法最可靠）；build script 產出的 .app 之 Info.plist 亦標 `LSUIElement=YES`。
- **最低系統**：`Package.swift` 設 `.macOS(.v13)`（雖然本機是 macOS 26，仍以 13 為相容目標）。

---

## 2. 檔案結構（Phase 1 範圍）

```
FindYourWay/
├─ Package.swift                      # SPM：library + executable + test target，platforms macOS 13
├─ scripts/
│  └─ build_app.sh                    # 組 .app bundle（含 Info.plist）
├─ Sources/
│  ├─ FindYourWayCore/               # 「可測邏輯」放這（library target，不含 @main）
│  │  ├─ Support/
│  │  │  └─ Palette.swift            # §1.2 色盤 HEX → NSColor/SKColor 常數 + HEX 解析工具
│  │  ├─ Scene/
│  │  │  ├─ CharacterNode.swift      # 32×32 陶紅方塊 + 走路節奏
│  │  │  ├─ WalkMotion.swift         # 走路/折返的純邏輯（不 import SpriteKit → 可測）
│  │  │  ├─ GameScene.swift          # SKScene：clear、背景色帶、掛角色
│  │  │  └─ ParallaxBackground.swift # 單/雙層佔位背景色帶
│  │  └─ Window/
│  │     └─ PetWindowConfig.swift    # 視窗設定「值」與定位計算（純函式 → 可測）
│  └─ FindYourWay/                   # executable target（薄殼，只做組裝，難測的部分）
│     ├─ main.swift                   # 進入點：NSApplication、setActivationPolicy(.accessory)
│     ├─ App/AppDelegate.swift        # 組裝視窗與場景
│     └─ Window/PetWindow.swift       # NSWindow：套用 PetWindowConfig 的設定
├─ Tests/
│  └─ FindYourWayCoreTests/
│     ├─ PaletteTests.swift           # HEX→color 解析正確、關鍵色值正確
│     ├─ WalkMotionTests.swift        # 走路推進、邊緣折返/循環邏輯正確
│     └─ PetWindowConfigTests.swift   # 右下角定位計算、視窗旗標集合正確
└─ .gitignore                         # .build/、*.app 等
```

> **分層要點（同時服務可測性與 `04` §3.2）**：把「可用純邏輯表達的部分」抽進 `FindYourWayCore` library（不 import 難測的 AppKit runtime 行為），executable 只留薄薄的組裝殼。這樣 `swift test` 就能覆蓋 Palette、走路邏輯、視窗定位計算。Simulation/Persistence 層 Phase 2 再加進 Core，屆時是 TDD 主場。

---

## 3. 各檔關鍵實作要點

### `Package.swift`
- `swift-tools-version` 對應 Xcode 16（5.9+ 皆可）。
- `platforms: [.macOS(.v13)]`；一個 executable target `FindYourWay`，連結 `AppKit`、`SpriteKit`（系統框架，SPM 直接 import 即可，無需宣告依賴）。

### `main.swift`
- 建 `NSApplication.shared`，`app.setActivationPolicy(.accessory)`（無 Dock、不搶焦點）。
- 設 `AppDelegate`，`app.run()`。

### `PetWindow.swift`（核心，照 `04` §2.2）
```swift
styleMask: [.borderless]
isOpaque = false
backgroundColor = .clear
hasShadow = false
level = .floating
collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
ignoresMouseEvents = true          // 策略 A：整窗穿透
isMovableByWindowBackground = false
```
- **尺寸與定位**：預設一個小視窗（如 320×180 邏輯點），錨定**主螢幕右下角**（留邊距，如距右下各 24pt）。用 `NSScreen.main.visibleFrame` 算位置。
- **不搶焦點**：用 `orderFrontRegardless()` 顯示，**不要** `makeKeyAndOrderFront`；window 可設 `canBecomeKey=false`（Phase 1 不需鍵盤/焦點）。

### `GameScene.swift`（照 `04` §2.3）
- `SKView`：`allowsTransparency = true`、`wantsLayer = true`。
- `SKScene`：`backgroundColor = .clear`、`scaleMode = .resizeFill`。
- 掛 `ParallaxBackground` 與 `CharacterNode`。
- `SKView.preferredFramesPerSecond = 30`（省電，`04` §6）。

### `CharacterNode.swift`（照 `03` §2.2/2.3）
- 一個 **32×32** 的 `SKSpriteNode`，顏色 `Palette.travelerTerracotta`（`#C56A4E`）。
- **走路表現（佔位）**：水平位移 + 極簡「走路節奏」——可用 2–4 格的上下微幅位移/縮放模擬步伐（`SKAction`），速率對應 **6–8fps 的悠閒感**（別太快）。
- 走到可視範圍邊緣則折返或循環（Phase 1 世界捲動未做，先讓小人自己走動即可）。
- 若之後放貼圖：`texture.filteringMode = .nearest`（Phase 1 純色方塊可省）。

### `ParallaxBackground.swift`
- Phase 1 極簡：上半 `#8FC7E8` 天空藍、下半 `#7FB069` 草原綠的兩塊 `SKSpriteNode` 色帶即可。真正的 7 層 parallax（`03` §2.4）留 Phase 2。

### `Palette.swift`
- 把 `03` §1.2 色盤做成 `SKColor`/`NSColor` 常數（至少：travelerTerracotta、skyAzure、meadowGreen、cloudCream、inkUmber）。附 HEX→color 的小工具。

### `scripts/build_app.sh`
- `swift build -c release` → 取 executable → 組 `FindYourWay.app/Contents/{MacOS,Info.plist}`。
- `Info.plist` 至少：`CFBundleExecutable`、`CFBundleIdentifier`（如 `com.findyourway.app`）、`LSMinimumSystemVersion=13.0`、`LSUIElement=YES`、`NSHighResolutionCapable=YES`。

---

## 4. 施工順序（照 `04` 附錄 A，逐步可驗）

1. `Package.swift` + `main.swift`（`.accessory`）+ 空 `AppDelegate` → `swift run` 能起、無 Dock 圖示、無視窗。
2. `PetWindow` borderless+clear+floating+穿透 + 空 `SKView`（clear）→ 確認**桌面透出、無黑底、無邊框、右下角定位、可穿透點擊**。
3. `ParallaxBackground` 天空/草地色帶 → 確認透明背景上出現色帶。
4. `CharacterNode` 陶紅 32×32 方塊 + 走路節奏 → 小人在走。
5. `preferredFramesPerSecond=30`，掛機量 CPU/能耗（R1 基準，§5）。
6. `build_app.sh` 產出可雙擊執行的 `.app`。
7. 對照 §0 驗收。

---

## 5. R1 能耗基準（本 Phase 必做，`04` R1）

- 用 **Xcode Energy Impact** 或 `powermetrics`（需 sudo）量測掛機 5–10 分鐘：
  - 記錄：平均 CPU%、常駐 RAM、能耗評級。
  - 對照實驗：`preferredFramesPerSecond=30` vs 靜止時 `scene.isPaused=true` 停到底，看透明合成是否有固定電耗底噪。
- 結果寫入 `PROGRESS_LOG.md`，作為「省電＝核心賣點」能否兌現的第一個證據。若底噪過高，Phase 2 需優先處理「靜止即暫停」策略。

---

## 5b. 測試（本 Phase 必做，專案級紀律）

> **專案原則：每個 Phase 的交付都必須含測試，`swift test` 全綠才算完成。** UI/runtime 難測的部分靠「抽出純邏輯」來覆蓋（見 §2 分層）。

Phase 1 必備測試（`Tests/FindYourWayCoreTests/`）：

| 測試檔 | 覆蓋 | 範例斷言 |
|--------|------|----------|
| `PaletteTests` | HEX 字串解析、關鍵色值 | `Palette.hex("#C56A4E")` 的 RGB 分量正確；`travelerTerracotta` == 該值 |
| `WalkMotionTests` | 走路推進與邊緣行為 | 給定位置/速度/邊界，`step(dt:)` 後位置正確；到右邊界會折返/循環、方向反轉 |
| `PetWindowConfigTests` | 右下角定位與旗標 | 給定 `visibleFrame` 與視窗尺寸/邊距，算出的 origin 落在右下角；設定旗標集合含 borderless/clear/floating/canJoinAllSpaces、`ignoresMouseEvents==true` |

- 測試只依賴 `FindYourWayCore`（library），不啟動 NSApplication、不開視窗（避免 CI/headless 卡住）。
- 難以自動化的部分（透明合成外觀、實際穿透手感、能耗）→ 靠 §0 人工驗收 + §5 能耗量測，並在 `PROGRESS_LOG.md` 記錄佐證。

---

## 6. 已知風險（Phase 1 期間留意，`04` §9）

- **R1 電耗底噪**（最重要，見 §5）。
- **R4 跨 Spaces / 全螢幕**觀感：`canJoinAllSpaces` 切 Space 時是否閃爍/位移，順手記錄。
- **R7 置頂層級**：`.floating` 是否被某些系統情境蓋掉或蓋到不該蓋處，順手記錄。
- **SPM executable 的 `.accessory` 是否完全等同 LSUIElement 行為**（焦點、Dock）——實測確認。

---

## 8. 極簡選單列（驗收後追加 · 2026-07-04）

> **背景**：Phase 1 驗收時發現 App 為 agent 型（無 Dock、無選單列）、視窗無邊框且點擊穿透，導致**使用者除了 `pkill`/Ctrl-C 外無法關閉**。這違反準則一（紅線四「邀請非強迫」、SDT 自主）——**能隨時放心關掉的陪伴才療癒**。故從 Phase 5 提前一個**最小集合**的選單列。

**範圍（只做最小，其餘留 Phase 5）**：
- 新增 `Sources/FindYourWay/Menu/StatusItemController.swift`（executable 層，AppKit runtime）。
- `NSStatusBar.system.statusItem(withLength:)` 建立選單列圖示（用簡單 SF Symbol 或短文字，如「🚶」或「FYW」佔位）。
- `NSMenu` 至少含：
  - **「結束 Find Your Way」**（必要）→ `NSApp.terminate(nil)`，快捷鍵 `Cmd-Q`。
  - **「顯示 / 隱藏桌寵」**（低成本、順手做）→ 切換 `PetWindow` 的顯示。
- `AppDelegate` 持有 `StatusItemController`，在 `applicationDidFinishLaunching` 建立。
- `.accessory` 政策與 `NSStatusItem` 相容，維持無 Dock。
- **不做**：狀態卡片（走了多遠/等級）、偏好設定視窗、開機自啟 —— 那些仍是 Phase 5。

**驗收**：App 啟動後選單列出現圖示，點開有「結束」，點了能正常退出；不需開終端機。

## 7. 交付與 review

- 實作者交付：可 `swift run` 與可雙擊 `.app`、**`swift test` 全綠**、通過 §0 驗收、R1 基準數據寫入日誌。
- Fable review：對照 §0 驗收標準、檢查是否守住準則（無多餘功能、無違反非侵入/紅線）、程式碼是否對齊 `04` 分層。
- 通過後更新 `PROGRESS_LOG.md` 與 `05_ROADMAP.md`（勾選 Phase 1），進 Phase 2。
