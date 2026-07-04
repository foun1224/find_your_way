# Phase 2 建置規格 — 時間感與旅程（Time & Journey）

> 狀態：**工程結構已審閱 (Accepted)** — Fable review 通過（2026-07-03）。**實作前尚有兩個前置條件**（見下）。
>
> **Fable review 註記**：工程結構、分層、TDD 測試計畫、§4 心理學紅線落地 —— 全數採納。特別認可 `SimulationRules` 單一速率來源（把 ADR-005 同速做成架構保證 + T2 迴歸鎖）、`TimeProvider`/`SavePaths` 可注入的 headless 可測性、§8 對 R1 的誠實留白。
>
> **實作前置條件（Sonnet/Codex 尚不可開工）**：
> 1. **R1 能耗數據**：使用者跑完 `07_PHASE1_ACCEPTANCE` §C 並回填本文件 §8.3 → 決定省電暫停策略。§3~§6 的 Simulation/Persistence（不依賴 R1）可先做，但需與 §8 一起收尾。
> 2. **產品參數 P1~P7（§7）**：Fable 設定 provisional 預設（P2/P3/P4/P5/P7）；**P1 推進速率、P6 離線回歸呈現**因最貼手感/最靠近紅線，將向使用者確認後回填 `01_DECISIONS.md` 再開工。
> 依準則二「先文字後實作」。延續 `06_PHASE1_SPEC.md` 的 SPM 分層（`FindYourWayCore` library + `FindYourWay` executable + `FindYourWayCoreTests`）。
> **目標一句話**：讓「放置＝前行」成立——關掉再開，人物「走了一段路」的感覺成立，且狀態能跨日存續。
>
> **依據**：`05_ROADMAP` Phase 2 目標與驗收、`04_ARCHITECTURE` §3/§4/§5/§6、`01_DECISIONS` ADR-005（離線推進）/ADR-007（存檔）、`02_PSYCHOLOGY_FOUNDATION` 六條紅線。
> **本 Phase 是 TDD 主場**：Simulation/Persistence 皆為純邏輯，先寫測試再實作。

---

## 0. 驗收標準（Definition of Done）

1. **「走了一段路」成立**：`swift run` 後角色在動；關掉 App、（模擬）經過一段時間再開，角色的**里程明顯前進**，且世界捲動位置對應到新的里程 —— 呈現為「你不在時它走了 N 段路 / 路過某地標」的正向回歸，而非「荒廢」。
2. **跨日存續**：狀態（里程、經過地標、`lastActiveTimestamp`、成長量、`schemaVersion`）寫入 `~/Library/Application Support/FindYourWay/save.json`；重開 App 後從存檔恢復，昨天走到的進度不歸零、不倒退。
3. **離線結算符合 ADR-005**：在線與離線**同速**、只增不減（無損）、上限 **12 小時**、`elapsed < 0` → 0、超上限截斷、**確定性可重現**（同輸入必得同輸出）。
4. **原子寫入 + `.bak` 回退**：寫檔用 atomic；壞檔（JSON 解析失敗）時能回退 `.bak`；兩者皆壞時安全地以新存檔起步（不崩潰、不覆寫式毀損）。
5. **心理學紅線守住**：離線回歸的數值與呈現，經對照 §4 檢查表，無任何「懲罰離開 / FOMO / 催回 / 倒退」成分（準則一）。
6. **`swift test` 全綠**：Simulation 與 Persistence 的測試計畫（§6）全部通過；沿用 Phase 1 既有 19 項測試不回歸。
7. **分層對齊 `04` §3.2**：Simulation/Persistence 純邏輯放 `FindYourWayCore`，**不 import SpriteKit / AppKit runtime**；Scene 層只「讀 `GameState` 來畫」。

> Phase 2 **不做**：偶發事件（Phase 3）、旅伴相遇（Phase 3）、正式美術（Phase 4）、選單列**狀態卡片/偏好/自啟**（Phase 5）、點角色互動（Phase 4）。里程與地標為**確定性推進**，隨機事件不在本 Phase。
>
> **Phase 2 併入的兩項（原屬他處，合併省一次來回）**：
> 1. **ADR-009 呈現**：角色固定左側 + 世界捲動（見 §3.8）—— 取代 Phase 1 的左右 roam。
> 2. **極簡選單列「結束」**（`06_PHASE1_SPEC` §8，Phase 1 驗收發現無法關閉的 gap）：新增 `Sources/FindYourWay/Menu/StatusItemController.swift`，`NSStatusItem` + `NSMenu` 至少含「結束 Find Your Way」(Cmd-Q → `NSApp.terminate`) 與「顯示/隱藏桌寵」；`AppDelegate` 建立之。維持 `.accessory` 無 Dock。理由：關不掉的陪伴違反紅線四/SDT 自主。

---

## 1. 實作策略決策（延續 `06` §1）

- **建置方式**：續用 Phase 1 的 SPM（library + executable + test），**不遷 xcodeproj**（Phase 2 仍無 Texture Atlas；遷移點仍在 Phase 4）。
- **並行**：續 `04` §6.5，模擬層用**主執行緒低頻 tick + 值型別 `GameState`**，不引入 Swift 6 嚴格並行。存檔 IO 可放背景 queue（但 Phase 2 存檔量極小，先主執行緒 atomic 寫入即可，避免過早複雜化；若 R1/實測顯示卡頓再移背景）。
- **時間來源**：所有時間相關邏輯**一律經 `TimeProvider` 取得「現在」**，不得直接呼叫 `Date()`，以確保可注入、可測、確定性（§3.4）。
- **模擬時間以真實時鐘為準，不以幀數為準**（`04` §4.1）：降頻/暫停 render 不影響「走了多遠」。

---

## 2. 檔案結構（Phase 2 範圍）

> 新增集中在 `FindYourWayCore/Simulation/` 與 `FindYourWayCore/Persistence/`（`04` §3.1 已預留這兩個目錄）。executable 只加薄薄的組裝與生命週期掛勾。

```
FindYourWay/
├─ Sources/
│  ├─ FindYourWayCore/
│  │  ├─ Simulation/                      # ← 新增（純邏輯，不 import SpriteKit/AppKit）
│  │  │  ├─ GameState.swift               # 純資料模型（Codable）：里程/地標/時間戳/成長量/schemaVersion
│  │  │  ├─ Landmark.swift                # 地標定義（沿里程軸的靜態里程碑表）+ 已通過判定
│  │  │  ├─ SimulationRules.swift         # 推進「公式」單一真相（速率、里程→地標對應）— 線上/離線共用
│  │  │  ├─ SimulationEngine.swift        # 線上 tick：advance(state, dt) 套 SimulationRules
│  │  │  ├─ OfflineProgress.swift         # 離線結算：讀 lastActiveTimestamp、算 elapsed、套 ADR-005 規則
│  │  │  ├─ OfflineOutcome.swift          # 離線結算「結果」值型別（供 Scene 呈現：走了多遠、新過地標）
│  │  │  └─ TimeProvider.swift            # 可注入時鐘（protocol + System/Fixed/Manual 實作）
│  │  │
│  │  ├─ Persistence/                     # ← 新增
│  │  │  ├─ SaveStore.swift               # 讀寫 Application Support、atomic 寫入 + .bak 備份 + 回退
│  │  │  ├─ SavePaths.swift               # 路徑解析（可注入根目錄，測試用 tmp dir）
│  │  │  ├─ SaveSchema.swift              # 當前 schemaVersion 常數 + 版本化解碼入口
│  │  │  └─ Migrations/
│  │  │     ├─ Migration.swift            # 遷移器協定（fromVersion → toVersion，作用於 JSON）
│  │  │     └─ MigrationV1toV2.swift      # 假想 v1→v2 遷移（示範向後相容原則；見 §5.3）
│  │  │
│  │  ├─ Scene/                           # ← 修改：消費 GameState
│  │  │  ├─ GameScene.swift               # 掛 tick、把里程綁到世界捲動、回歸時播離線呈現
│  │  │  ├─ WorldScroll.swift             # ← 新增（純邏輯）：里程 distance → 世界捲動偏移/地標定位
│  │  │  └─ (CharacterNode / ParallaxBackground 沿用 Phase 1)
│  │  └─ ... (Support/Palette、Window/PetWindowConfig 沿用)
│  │
│  └─ FindYourWay/                        # executable 薄殼（修改）
│     └─ App/AppDelegate.swift            # 啟動時載檔→離線結算→掛 tick；終止/休眠前存檔（§7）
│
└─ Tests/
   └─ FindYourWayCoreTests/
      ├─ SimulationEngineTests.swift      # ← 新增
      ├─ OfflineProgressTests.swift       # ← 新增
      ├─ SaveStoreTests.swift             # ← 新增
      ├─ SaveMigrationTests.swift         # ← 新增
      ├─ GameStateCodableTests.swift      # ← 新增（round-trip / 欄位預設）
      ├─ WorldScrollTests.swift           # ← 新增（里程→捲動對應）
      └─ (Palette/WalkMotion/PetWindowConfig 沿用 Phase 1)
```

> **分層要點**：`SimulationRules` 是「推進公式的單一真相」，`SimulationEngine`（線上）與 `OfflineProgress`（離線）**都呼叫它**，保證兩路同一套數值（ADR-005 同速的工程保證）。

---

## 3. 各模組關鍵設計

### 3.1 `GameState`（純資料模型，Codable）

```swift
public struct GameState: Codable, Equatable {
    public var schemaVersion: Int          // = SaveSchema.currentVersion
    public var distance: Double            // 累積里程（點 or 抽象「里程單位」，粒度待 Fable，§7 產品參數）
    public var landmarksPassed: [String]   // 已通過地標 id（有序、去重、只增）
    public var lastActiveTimestamp: Double  // 上次活躍的真實時鐘（Unix 秒）— 由 TimeProvider 寫入
    public var growth: Double              // 成長量（Phase 2 先用連續量：如「旅程時數」或「里程換算」；等級呈現由 Scene 決定）
    // 只增不減原則：所有欄位的變更方向皆單調遞增或恆等，無任何遞減路徑（紅線一）。
}
```

- **Codable**：對映 `04` §5.2 的 JSON 結構。所有欄位給合理預設，利於新增欄位時向後相容（§5.3）。
- **值型別**：搭配主執行緒 tick，避免並行複雜度（`04` §6.5）。
- `distance` 的**單位與粒度**、`growth` 是否為顯性「等級」→ 產品參數，見 §7，Phase 2 先用連續量、不硬做等級數字。
- **不可變式（invariant）**：任何 mutation 後 `distance` 不得變小、`landmarksPassed` 不得移除元素——由 `SimulationRules` 保證，並由測試守。

### 3.2 `SimulationRules`（推進公式單一真相）

- 定義**唯一**的推進速率與里程→地標的對應，供線上/離線共用。
- 核心函式（純函式、確定性）：
  - `func distanceGained(overSeconds seconds: Double) -> Double`：`seconds × speed`（`seconds` 已由呼叫端夾為非負）。線上與離線都走這條 → **同速**（ADR-005）。
  - `func landmarks(crossedFrom old: Double, to new: Double) -> [Landmark]`：回傳 `(old, new]` 區間內新通過的地標（確定性、只看里程軸，不擲骰）。
- `speed` 常數集中在此檔（**單一數值來源**，方便 Fable 調參 §7）。

### 3.3 `SimulationEngine`（線上 tick）

- `static func advance(_ state: GameState, bySeconds dt: Double, rules: SimulationRules) -> (GameState, [Landmark])`
  - `dt <= 0` → 原樣返回（防負/零）。
  - 用 `rules.distanceGained` 累加 `distance`，用 `rules.landmarks(crossedFrom:to:)` 求新地標，合併進 `landmarksPassed`（去重、保序），更新 `growth`。
  - **不更新 `lastActiveTimestamp`**（時間戳由呼叫端在 tick 時以 `TimeProvider.now` 寫入，職責分離、易測）。
- `GameScene` 以低頻 tick（`04` §4.2：每 1～5 秒）呼叫 `advance(dt: 實際經過秒數)`；`dt` 用**真實時鐘差**而非固定值，降頻不失真。

### 3.4 `TimeProvider`（可注入時鐘）

```swift
public protocol TimeProvider { var now: Double { get } }   // Unix 秒
public struct SystemTimeProvider: TimeProvider { public var now: Double { Date().timeIntervalSince1970 } }
public struct FixedTimeProvider: TimeProvider { public var now: Double }              // 測試：固定值
public final class ManualTimeProvider: TimeProvider { public var now: Double; /* 可 advance(by:) */ }
```

- **全專案唯一取得「現在」的入口**。`Date()` 只允許出現在 `SystemTimeProvider`。
- 測試用 `Fixed`/`Manual` 精準控制 elapsed，驗證離線結算與時間戳邏輯，無需真的等時間。

### 3.5 `OfflineProgress`（離線結算，ADR-005 核心）

```swift
public enum OfflineProgress {
    public static let capSeconds: Double = 12 * 60 * 60   // ADR-005 上限 12h（集中常數，Fable 可調 §7）

    /// 讀 lastActiveTimestamp、以 now 算 elapsed、套 ADR-005 規則、用共用公式一次結算。
    public static func settle(_ state: GameState, now: Double, rules: SimulationRules) -> (GameState, OfflineOutcome)
}
```

規則（逐條對應 ADR-005 / `04` §4.3）：
1. `rawElapsed = now - state.lastActiveTimestamp`。
2. **`elapsed = min(max(rawElapsed, 0), capSeconds)`** —— `elapsed < 0` → 0（改系統時間往前不扣進度，紅線一）；超上限截斷 12h（避免數值失控）。
3. 用 `SimulationRules`（**與線上同一套**）一次算出 `elapsed` 期間的 `distance` 增量與新通過地標 → 同速（ADR-005）。
4. 更新 `state`（只增），`lastActiveTimestamp = now`。
5. 回傳 `OfflineOutcome`（`elapsedSecondsApplied`、`distanceGained`、`newLandmarks`、`wasCapped`）供 Scene 決定呈現。
6. **確定性**：全程無隨機、無「以結算當下時間為 seed」的擲骰（Phase 2 無事件）；相同 `(state, now)` 必得相同結果 → 可重現、可測。

> **防弊定位**：ADR-005 為寬鬆（純陪伴、無排行榜）。只做「負→0、超上限截斷」兩道，不做時鐘連續性追蹤 / 反回撥偵測（過度工程，且可能傷害誠實的離線使用者）。

### 3.6 `SaveStore` + `SavePaths`（存檔，ADR-007）

- 路徑：`~/Library/Application Support/FindYourWay/save.json`，備份 `save.bak.json`（`04` §5.1）。`SavePaths` 接受**可注入根目錄**（預設 `.applicationSupportDirectory`，測試傳 tmp dir）→ 讓 `SaveStore` 可在 headless 測試對真實檔案系統跑 round-trip，不污染使用者目錄。
- **寫入（save）**：
  1. 若現存 `save.json` 有效，先複製為 `save.bak.json`（保住上一份好檔）。
  2. `JSONEncoder` 編碼 → `Data.write(to:options: .atomic)`（`04` §5.1 原子寫入，避免寫一半壞檔）。
- **讀取（load）**：
  1. 讀 `save.json`；解碼成功 → 經 `SaveSchema` 版本檢查/遷移（§5.3）→ 回傳。
  2. `save.json` 不存在或解碼失敗 → 嘗試 `save.bak.json`（回退）。
  3. 兩者皆失敗 → 回傳 `nil`（呼叫端以新 `GameState` 起步，**不崩潰、不覆寫**）。
- **存檔時機**（`04` §5.3，executable 掛勾見 §7）：離線結算後、定期節流、`applicationWillTerminate`、進背景/休眠前。**tick 每次更新記憶體 `lastActiveTimestamp`，但寫盤節流**（省 IO / SSD）。

### 3.7 `SaveSchema` + `Migrations/`（版本化，ADR-007）

- `SaveSchema.currentVersion`（Phase 2 = 1）。
- **讀檔遷移**：解碼時先讀 `schemaVersion` 欄位（先淺解析 version，再決定用哪版結構 / 跑哪些遷移器）：
  - `version < current` → 依序跑 `Migrations`（v1→v2→…），每個遷移器作用於中介表示（`[String: Any]` JSON 物件或版本化 struct），升級後再解成當前 `GameState`。
  - `version == current` → 直接解。
  - `version > current`（使用者裝了舊版程式讀到新存檔）→ **安全降級**：不寫壞新格式，以唯讀/放棄寫入方式處理（`04` §5.2）。Phase 2 最小處理＝載入失敗回退 `.bak` 或新起步，並在日誌標記（不 crash）。
- **原則（`04` §5.2）**：只增欄位、給預設值，優先**向後相容**；破壞性改動才升版本。
- **`MigrationV1toV2` 為假想示範**：Phase 2 只有 v1，v2 尚不存在。此檔提供一個**可測的遷移範例骨架**（例如：假想 v2 把 `growth: Double` 拆為 `growthStages: [String]`，遷移器示範「給預設、不丟資料」），驗證遷移機制本身可運作，供 Phase 3+ 真正加欄位時有樣板。標為 **示範用**，不進入實際讀寫路徑直到 v2 真的存在。

### 3.8 Scene 層如何消費 `GameState`

- **世界捲動綁定里程（`WorldScroll`，純邏輯可測）**：`distance` → 背景 parallax 各層偏移 + 地標節點在畫面上的位置。`func scrollOffset(forDistance:layerFactor:) -> Double`、`func landmarkScreenX(landmarkDistance:currentDistance:) -> Double`。**角色錨定在畫面左側約 20–25%、原地走路（walk-in-place）**（ADR-009），**世界向左捲**來表現前進（放置類慣例），捲動量由 `distance` 驅動 → render 降頻/暫停不影響「走到哪」。此處即 ADR-009 的實現點：Phase 1 的「小人左右 roam」在此改為固定左側；`CharacterNode` 的螢幕 x 固定、`WalkMotion` 改驅動 `distance` 而非螢幕座標。
- **回歸呈現（離線回來）**：`AppDelegate` 啟動載檔後呼叫 `OfflineProgress.settle`，把 `OfflineOutcome` 交給 `GameScene`：
  - Phase 2 最小可行呈現 = **一段短捲動補間動畫**（世界快速捲過 `distanceGained` 的一段）+ **旅程日誌雛形**（一行文字/簡單列表：「你不在時走了 N，路過 ○○」）。呈現形式細節見 §7 產品參數。
  - **呈現只在有進展時出現**；`elapsed == 0`（剛關剛開 / 負 elapsed）則安靜恢復，不硬演。
- **tick 掛載**：`GameScene` 用低頻 `Timer`/`SKAction`（`04` §4.2，帶較大 `tolerance` 讓系統合併喚醒省電）呼叫 `SimulationEngine.advance`，並在 tick 時以 `TimeProvider.now` 更新記憶體 `lastActiveTimestamp`。

---

## 4. 心理學把關（準則一 — 六條紅線落地到本 Phase）

> 離線推進與呈現是**最靠近紅線的地方**（`02` §三 OQ-2、§7 判準）。以下為本 Phase 的**硬約束**，Scene 呈現與數值設計必須逐條守住，review 時逐項對照。

| 紅線 | 對本 Phase 的具體約束（數值 / 呈現） |
|------|--------------------------------------|
| 一：不懲罰離開、只增不減 | `GameState` 所有欄位**無遞減路徑**；`elapsed<0`→0（改時鐘不倒退）；回歸文案永遠是「走了更遠 / 在休息等你」，**禁止**「荒廢 / 落後 / 枯萎 / 生病」。 |
| 二：無 FOMO | 離線推進**無時效、無限定**；「回來還在、回來也走到」。上限 12h 只是**數值封頂**，**不得**呈現成「超過就浪費了，快回來」。`wasCapped` 用於內部截斷，**不對使用者顯示成損失**。 |
| 三：不催促打擾 | Phase 2 **不做任何通知/推播/紅點**。回歸呈現只在「使用者主動打開 App」時發生，是溫和的驚喜，非召回手段。 |
| 四：邀請非強迫 | 離線推進**零操作即完整**，使用者什麼都不做，回來就是往前。無任何「要回來領」的機制。 |
| 五：不看黏著 | 本 Phase 成功指標＝「關掉再開，走了一段路的**踏實/被陪伴感**成立」，**不**衡量開啟頻率/時長。 |
| 六：安心不看 | **在線與離線同速**（ADR-005）是這條的工程保證：掛前景不會更快，故無「該掛著顧」的壓力。`SimulationRules` 單一速率來源即保證此點——**禁止**任何「前景加速 / 前景額外獎勵」的分支。 |

- **數值設計原則**：速率要**慢到「離開一天回來是溫柔變化」**（`02` OQ-2 建議），非「錯過一天落後一大截」。具體速率待 Fable（§7），但無論定多少，**線上=離線**這條不可破。
- **呈現語氣**：旅程日誌/回歸文案走「風景換了一點、走過了○○」的敘事留白（`02` §5 敘事認同、§6 低喚醒），不量化施壓、不用驚嘆催促。

---

## 4b. 背景與可見捲動修正（2026-07-04 視覺驗收發現）

> **背景**：使用者跑 Phase 2 後回報兩問題：(1) 天空/草地色帶橫向錯位；(2) 看不出速率。
> **根因**：`ParallaxBackground` 對**滿版純色帶**套了不同 `layerFactor` 的橫向視差 → 兩帶各自左移不同量 → 錯位 + 右側露空。且純色帶捲動無參照物 → 無可視運動；加上真實速率為離線設計（1 單位/秒）現場近乎靜止。
> **嚴重度/路由**：影響當前 Phase 核心價值（表現「前進」）且阻塞 P1 手感判斷（Phase 3 前置）→ **緊急插入修改**，不延 Phase 4。

**修正要求**：
1. **天空/草地＝固定滿版填充**：不做橫向視差捲動（`layerFactor` 對純色填充無意義）。做成永遠覆蓋整個視窗、不留空缺（可用 `scaleMode=.resizeFill` 對齊、或 anchor 撐滿；晝夜色調 Phase 4）。→ 消除錯位。
2. **新增可捲動、可循環的佔位景物層**（讓運動看得見、有視差）：
   - 近景層（layerFactor ≈ 1.0）：一排簡單佔位景物（如草叢/石頭，深綠小方塊/圓）沿世界間距排列，依 `distance` 向左捲動、移出畫面後**循環回收 (wrap)** → 連續可見運動。
   - 遠景層（layerFactor ≈ 0.3）：幾個簡單丘陵剪影，捲動較慢 → 視差層次。
   - 這些是**佔位**（Phase 4 換正式美術）；純裝飾、不入 `GameState`、不記錄（同 Phase 3 §2.2 B 類精神）。
3. **可見散步速率（provisional，P1 起點）**：把 `SimulationRules.speed` 調成「悠閒但清楚可見」的散步（建議 ~12 單位/秒，1 單位≈1pt；現場看是緩慢平移、不焦躁、非靜止），並**同步放大 `Landmark`/事件間距**維持「約 1–2 小時一個地標」的節奏（例：間距由 10800 調到 ~86400）。速率與間距皆集中常數、**使用者反應後再調**。線上=離線同速不變（仍走 `SimulationRules` 單一來源）。
4. 迴歸：既有 56 測試不得回歸；離線結算數值測試若因 speed 常數改變需更新期望值，據實更新並說明。

> 呼應 `03_DESIGN_SYSTEM` §2.4（parallax 分層）與 §3.4（動效緩慢有機、不焦躁）。此為 Phase 2 視覺補正，非新機制。

## 5. 施工順序（逐步可驗，TDD）

> 每步先寫測試（紅）→ 實作（綠）→ 下一步。Simulation/Persistence 全程 headless，不啟動 NSApplication。

1. **`TimeProvider`**：protocol + System/Fixed/Manual。（最先，後續全靠它注入時間）
2. **`GameState` + Codable**：定義欄位、預設、round-trip 測試（§6 T5）。
3. **`SimulationRules` + `Landmark`**：速率常數、`distanceGained`、`landmarks(crossedFrom:to:)`；純函式測試。
4. **`SimulationEngine.advance`**：線上 tick 推進正確性、`dt<=0` 防護、地標去重保序（§6 T1）。
5. **`OfflineProgress.settle`**：elapsed 正常/負/超上限/確定性、與線上同速一致性（§6 T2）。**這是 Phase 2 的靈魂測試。**
6. **`SavePaths` + `SaveStore`**：可注入 tmp 根目錄；atomic 寫、round-trip、壞檔回退 `.bak`、雙壞→nil（§6 T3）。
7. **`SaveSchema` + `Migrations`**：版本讀取、v1→v2 假想遷移、version>current 安全降級（§6 T4）。
8. **`WorldScroll`**：里程→捲動偏移/地標定位純邏輯測試（§6 T6）。
9. **Scene/executable 整合**（難自動測，靠 §0 人工驗收）：`AppDelegate` 啟動載檔→`settle`→掛 tick；`GameScene` 綁 `WorldScroll` 世界捲動 + 回歸呈現雛形；存檔時機掛勾（terminate/sleep/節流）。
10. **`swift test` 全綠**（新測試 + Phase 1 不回歸）→ 人工驗收「關掉再開走了一段路」+ 跨日存續 → 更新 `PROGRESS_LOG` / `05_ROADMAP`。

---

## 6. TDD 測試計畫（本 Phase 重點，`Tests/FindYourWayCoreTests/`）

> 全部只依賴 `FindYourWayCore`，用 `TimeProvider` 注入時間，**不啟動 NSApplication / 不開視窗**。存檔測試用注入的 tmp 目錄，測完清理。

### T1 `SimulationEngineTests`（線上推進正確性）
- `advance(dt: 10)` 後 `distance` == 初值 + `rules.distanceGained(10)`。
- `dt <= 0`（0 與負值）→ state 不變。
- 跨越地標里程時，`landmarksPassed` 正確新增該地標、**去重**（重複經過不重複加）、**保序**。
- 多次小 `dt` 累加 == 單次大 `dt`（線上推進對 dt 切分無偏差，確保降頻不失真）。
- **只增不減**：任意序列 `advance` 後 `distance` 單調不減、`landmarksPassed` 不減。

### T2 `OfflineProgressTests`（離線結算 — 靈魂測試）
- **elapsed 正常**：`now - last = 3600` → `distance` 增量 == `rules.distanceGained(3600)`；`lastActiveTimestamp` 更新為 `now`。
- **elapsed 負值**（改系統時間往前，`now < last`）→ elapsed 視為 0，`distance` **不變、不倒退**（紅線一），時間戳更新為 now。
- **elapsed 超上限**：`now - last = 48h` → 只結算 `capSeconds`（12h）份量；`OfflineOutcome.wasCapped == true`。
- **確定性可重現**：相同 `(state, now)` 呼叫兩次，結果**逐欄位相等**（無隨機）。
- **在線=離線同速**：`OfflineProgress.settle(elapsed=T)` 的 `distanceGained` == `SimulationEngine.advance(dt=T)` 的增量（ADR-005 同速的迴歸鎖）。
- **邊界**：elapsed 恰為 0 / 恰為 capSeconds → 正確、無 off-by-one。

### T3 `SaveStoreTests`（存檔）
- **round-trip**：save→load 得到 `Equatable` 相等的 `GameState`。
- **atomic 寫入**：寫入後 `save.json` 存在且可解析（可加：寫入不留半檔——以「寫完即完整可解碼」斷言）。
- **壞檔回退 `.bak`**：手動把 `save.json` 寫成壞 JSON、`save.bak.json` 為好檔 → load 回退得到 `.bak` 的狀態。
- **雙壞 / 皆不存在** → load 回傳 `nil`（呼叫端可安全新起步），不丟例外。
- **備份生成**：對已有好檔再 save 一次 → `.bak` 內容 == 前一版。
- 用注入 tmp 目錄，`tearDown` 清理。

### T4 `SaveMigrationTests`（schema 遷移）
- **v1→v2 假想遷移**：餵一份 `schemaVersion: 1` 的 JSON → 經 `MigrationV1toV2` → 得到合法的 v2 結構，**舊資料不丟失、新欄位給預設**（向後相容原則）。
- **當前版本直解**：`schemaVersion == currentVersion` 不觸發遷移。
- **version > current 安全降級**：餵一份未來版本 JSON → 不 crash、依策略回退/新起步。
- **缺欄位向後相容**：舊 JSON 缺某新增欄位 → 解碼用預設值填補（`GameState` 預設）。

### T5 `GameStateCodableTests`
- 編碼 JSON 含 `schemaVersion`、欄位命名對映 `04` §5.2。
- 解碼缺省欄位→預設；round-trip 冪等。

### T6 `WorldScrollTests`
- `distance` 增加 → `scrollOffset` 單調變化、方向正確。
- 各 parallax 層 `layerFactor` 造成不同捲動量（遠景慢、近景快）。
- 地標螢幕位置隨 `currentDistance` 逼近而正確移入畫面。

---

## 7. 待決的產品參數（供 Fable 定案）

> 以下為**產品手感 / 數值**，非技術問題。工程上全部集中在 `SimulationRules` / `OfflineProgress` 的常數，改一處即可。Opus **不自行拍板**，列出供 Fable 定，並附建議傾向。

| # | 待決參數 | 影響 | Fable 定案（2026-07-04） |
|---|----------|------|--------------------------|
| P1 | **推進速率**（多快算「悠閒」）：每小時前進多少 `distance`？ | 直接決定「離開一天回來走多遠」的手感 | ✅ **provisional（Fable，使用者放手）**：以「**地標約每 3 小時的推進量出現一個**」為錨定速率（配合 P3 地標間距 = 1「旅程日」）。→ 離線上限 12h ≈ 回來看到走過約 3–4 個地標，是「一段路」但不爆量。集中在 `SimulationRules.speed` 一常數，**跑起來憑感覺再調**。 |
| P2 | **`distance` 單位與粒度** | 里程數字語感、地標間距 | ✅ **抽象「旅程單位 (journey unit)」**，非螢幕點。**預設不對使用者顯示原始數字**（`02` §3 弱化量化）——成長靠世界/地標/日誌呈現，數字若要，藏在 progressive disclosure 之後（`03` §3.3）。 |
| P3 | **地標密度與命名** | 旅程節奏、敘事留白 | ✅ **地標間距 ≈ 1 個「旅程日」的推進量**（相對 P1，故與 P1 絕對值解耦、均勻）。Phase 2 放 **3～5 個佔位地標**，名稱走**留白可投射的意象**（如「風起的埡口」「無名的河灣」），不把故事說死（`02` §5）。實際命名可再調。 |
| P4 | **離線結算上限** | 數值封頂 | ✅ **12h**（沿用 ADR-005，不微調）。集中在 `OfflineProgress.capSeconds`。 |
| P5 | **`growth` 是否顯性等級** | 成長呈現形式 | ✅ **Phase 2 用連續量、不做等級數字**。顯性等級/外觀變化留 Phase 3（`02` §3、`03` §3.3 具象成長優先於抽象數字）。 |
| P6 | **離線回歸呈現形式** | 回來的第一印象（最靠近紅線） | ✅ **定案（Fable）**：短捲動補間 **2.5 秒後自動淡出**（原「點一下略過」因 Phase 2 整窗點擊穿透無法做，改自動淡出——**更符合非侵入、無互動要求**，Fable 認可）；配 **一行溫柔旅程日誌**（「你不在時走過了○○」），敘事語氣、不量化、不催促。`wasCapped` 不呈現成損失（紅線二）。點擊略過待 Phase 4 互動上線再議。 |
| P7 | **tick 頻率與存檔節流間隔** | 省電 vs 即時性 | ✅ **provisional：tick 每 2 秒**（`04` §4.2 的 1–5s 區間、帶大 tolerance）；**存檔節流每 ~2 分鐘 + 關鍵時機**（離線結算後 / terminate / sleep）。**待 §8 R1 數據後可再收緊**。 |

> **定案摘要**：P2/P3/P4/P5/P7 由 Fable 依已定案的 `02`/`03`/`04`/ADR-005 鎖定（provisional，集中在少數常數，易調）。**P1 推進速率、P6 離線呈現**因最貼手感、最靠近心理學紅線，保留給使用者拍板後回填 `01_DECISIONS.md`，再開工 Phase 2 實作。

---

## 8. 省電策略（⏳ 待 Phase 1 R1 能耗實測數據回填）

> **本章為決策框架 + 待填空格，不編造數據。** `07_PHASE1_ACCEPTANCE` §C 的 R1 能耗基準（透明合成底噪 / 持續 render vs `isPaused` 對照）**尚未由使用者實測回填**（見 `PROGRESS_LOG`：Phase 1 程式+測試已過，GUI/能耗人工驗收待跑）。以下待 R1 數字到位後定案。

### 8.1 已可確定（不依賴 R1）
- **背景全停 tick、回前景用時間戳結算**（`04` §4.3/§6.1 第 4 點）：這是省電最大杠杆，Phase 2 直接落實——`OfflineProgress.settle` 就是為此存在。進背景/休眠只記 `lastActiveTimestamp`，不跑模擬。
- **低頻 tick + 大 `tolerance`**（`04` §6.1 第 9 點）：讓系統合併喚醒。
- **監聽 `NSWorkspace.willSleep/didWake` + 螢幕休眠**作為停/續與存檔觸發（`04` §6.1 第 10 點、§5.3）。

### 8.2 決策框架（待 R1 數據填入後定案）

| 若 R1 實測結果 | 則 Phase 2 省電策略 |
|----------------|---------------------|
| **透明合成底噪高**（掛機閒置 CPU/能耗仍明顯，非個位數% 以下、非 Low） | **必做「靜止即 `isPaused`」**：世界不捲動 / 使用者長時間閒置 / 螢幕休眠時 `scene.isPaused = true` 停到底（`04` §6.1 第 3 點、`06` §5）。世界捲動由 `distance` 驅動而非常轉，天然可在「無新進展要顯示」時停 render。 |
| **底噪低**（降幀後閒置即接近 0、Low） | 維持 Phase 1 的 `preferredFramesPerSecond=30` + 忙碌/閒置降至 ~10fps 即可（`04` §4.2），不必急做全暫停。 |

### 8.2b 暫停策略修正（2026-07-04 使用者回報「後面都不動了」）

> **Bug**：原 `checkIdleAndUpdatePauseState` 以 `CGEventSource.secondsSinceLastEventType`（鍵鼠閒置）判定，閒置 ≥60s 就 `isPaused=true`。但使用者只是**在看桌寵**（看 ≠ 輸入）→ 被誤判成「離開」→ 畫面凍結。**這把「正在被看」誤判成「離開」，違反桌寵本質**（`02` §2 社會臨場感：它要「持續、低調地活著」）。
>
> **根本原則（修正）**：**桌寵只要在畫面上、可能被看見，就必須是活的；省電只在「使用者確定看不到」時才做。** 鍵鼠閒置**不是**「看不到」的有效訊號（使用者常盯著不動的東西看），故**移除鍵鼠閒置暫停**。
>
> **修正後的暫停訊號（只保留「確定看不到」）**：
> | 訊號 | 動作 |
> |------|------|
> | 系統睡眠 `NSWorkspace.willSleep` / 喚醒 `didWake` | 暫停 / `resumeWithCatchUp`（既有，保留） |
> | **螢幕睡眠** `NSWorkspace.screensDidSleep` / `screensDidWake` | 暫停 / `resumeWithCatchUp`（**新增**：螢幕關了＝確定看不到） |
> | **使用者從選單列「隱藏桌寵」** | 暫停；「顯示」時 `resumeWithCatchUp`（**新增**：隱藏＝看不到） |
> | ~~鍵鼠閒置 ≥60s~~ | **移除**（看≠輸入，會凍結被看的桌寵） |
>
> **能耗取捨**：畫面可見時維持 render（~2.7% CPU/30fps，R1 基準可接受）；真正省電發生在螢幕/系統睡眠與隱藏時。這比「凍結被看的桌寵」正確得多——後者破壞整個陪伴體驗。若日後 R1 能耗仍嫌高，優化方向是「降 fps / 靜止時降頻」而非「輸入閒置暫停」。

### 8.3 R1 實測數據（2026-07-04 首次量測，Phase 1 基準）
- [x] 執行中平均 CPU%：**~2.7%**（30fps 持續 render + 走路動畫，`top` 量測；非掛機閒置，因 Phase 1 角色恆動）
- [x] 常駐 RAM：**~134 MB**（SpriteKit/Metal baseline，偏高但可接受）
- [ ] 能耗評級：______（尚未用 Xcode Energy Impact / powermetrics 正式評級，可後補）
- [ ] 持續 render vs `isPaused` 對照差異：______（Phase 2 做 isPaused 時一併量）
- [x] **結論**：**需要**在 Phase 2 做「靜止即 `isPaused`」。判定依據：2.7% CPU 對「整天常駐」非趨近 0（§8.2 上列情境），持續透明合成有可觀底噪。**注意**：此數據是「角色恆動」下的值；Phase 2 世界捲動由 `distance` 驅動後，真正的槓桿是「無新進展要顯示時停 render」，屆時應能大幅降低閒置能耗。
- [ ] 靜止判定訊號來源：世界是否在捲動 / 使用者閒置時間 / 螢幕休眠通知（`NSWorkspace` sleep/wake）—— Phase 2 實作時確認。

> **給 Phase 2 的行動**：§8.2 走「底噪高 → 必做靜止即 `isPaused`」這條。RAM 134MB 也列入觀察，Phase 2 檢查是否有可釋放資源。

> **施工提醒**：§8.2 兩條路都與 §3.8 的「世界捲動由 `distance` 驅動」相容——無論走哪條，render 都不該在「無新進展」時空轉。差別只在「是否連透明合成底噪也停掉」。故 Phase 2 可先把 Simulation/Persistence（不依賴 R1）做完並測綠，省電暫停策略待 R1 數字回填後接上，不阻塞主線。

---

## 9. 交付與 review

- 實作者交付：新測試全綠 + Phase 1 測試不回歸（`swift test`）；`swift run` 可見「世界隨里程捲動」；關掉再開（可用調 `lastActiveTimestamp` 或 `ManualTimeProvider` 模擬跨時）能看到「走了一段路」+ 存檔跨重開存續；存檔檔案出現在 Application Support。
- Fable review：對照 §0 DoD、§4 心理學紅線逐條、§6 測試涵蓋、分層對齊 `04` §3.2（Simulation/Persistence 無 SpriteKit import）、無規格外功能（無事件/旅伴/通知）。
- **R1 依賴**：§8 省電暫停策略待使用者跑完 `07` R1 並回填 §8.3 後，再決定是否納入本 Phase 收尾。
- 通過後更新 `PROGRESS_LOG.md` 與 `05_ROADMAP.md`（勾選 Phase 2），進 Phase 3。

---

*本文件為 Phase 2 建置規格草稿，待 Fable review 定案。API 片段為示意，實作以官方文件為準；§8 標記 ⏳ 者不得在 R1 數據回填前當作既定事實。*
