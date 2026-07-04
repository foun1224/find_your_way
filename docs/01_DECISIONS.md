# 架構決策記錄 (Architecture Decision Records)

> 每筆 ADR 一旦定案，非有重大理由不更動。變更需在此追加新 ADR 並標記舊 ADR 為 Superseded。

格式：Context（背景）→ Decision（決定）→ Rationale（理由）→ Consequences（後果/取捨）。

---

## ADR-001：技術棧採用 Swift + SpriteKit

- **狀態**：Accepted (2026-07-03)
- **Context**：需要一個整天常駐桌面、透明懸浮、有 2D 動畫的 macOS 軟體。候選：Electron+Phaser、Tauri+Web、Swift+SpriteKit。
- **Decision**：採用 **Swift + SpriteKit**，視窗層用 AppKit（NSWindow）。
- **Rationale**：
  - 常駐軟體對「效能與省電」極敏感，原生方案 CPU/RAM/電耗最低。
  - SpriteKit 原生支援 2D sprite 動畫、粒子、貼圖圖集，貼合像素風放置遊戲。
  - 透明無邊框置頂視窗在 AppKit 有成熟做法（NSWindow 設定）。
  - 使用者希望未來能自行維護，單一原生技術棧比 web+殼的雙層架構單純。
- **Consequences**：
  - (取捨) 僅限 macOS。可接受，需求即為 Mac 桌面軟體。
  - (取捨) 需使用 Xcode / Swift 工具鏈；實作委派 Sonnet/Codex。
  - AI 協助的參考資料較 web 生態少，但 SpriteKit/AppKit 屬成熟 API，可控。

---

## ADR-002：存在形式為桌寵式懸浮視窗

- **狀態**：Accepted (2026-07-03)
- **Context**：三種形式 — 懸浮桌寵、獨立小視窗、全螢幕桌布。
- **Decision**：**桌寵式懸浮視窗**：透明背景、無邊框、可置頂、可穿透（非互動區點擊穿透到桌面）。
- **Rationale**：最貼合「有人陪在身旁」的情感目標（準則一：陪伴感 / 社會臨場感 social presence）。
- **Consequences**：
  - 視窗管理較複雜（透明、hit-testing、多螢幕、Spaces）。需在 `04_ARCHITECTURE.md` 專章處理。
  - UI 需極度克制，不可遮擋使用者工作（見設計系統：非侵入原則）。

---

## ADR-003：成長模型為純放置陪伴

- **狀態**：Accepted (2026-07-03)
- **Context**：成長來源候選 — 純放置、連結真實習慣、知識學習、情緒陪伴。使用者選擇「純放置陪伴」。
- **Decision**：**純放置陪伴**。人物自主冒險、隨時間推進、自然成長，使用者零強制負擔。
- **Rationale**：
  - 使用者明確要「低負擔、療癒」。零任務壓力符合此定位。
  - 心理學：低壓陪伴 / 環境掌控感 / 漸進成就（見 `02_PSYCHOLOGY_FOUNDATION.md`）。
- **Consequences**：
  - 不做強制打卡 / 待辦綁定 / 學習測驗（避免製造負擔與愧疚感）。
  - 「成長」的正回饋須靠**時間感、旅程感、偶發事件**營造，而非任務完成度。
  - (保留) 未來若使用者想加入輕量「陪伴式互動」，須以「邀請非強迫」為前提，另立 ADR。

---

## ADR-004：旅伴採「相遇式引入」(OQ-1)

- **狀態**：Accepted (2026-07-03) — 使用者拍板
- **Context**：靈感圖為兩人同行，情感核心是「有人陪你走」。心理學（社會臨場感 §2）與設計（§4 OQ-1）皆傾向要有旅伴；分叉在「旅伴如何出現」。
- **Decision**：**單人啟程，旅途中「相遇」旅伴後同行**（設計文件的 C 節奏 + B 視覺）。
- **Rationale**：把「陪伴」變成被賺得的高光時刻 (peak event)，最動人；且工程可分期，Phase 1 只需單人骨架。
- **Consequences**：
  - Phase 1–2 單人；旅伴作為 Phase 3 偶發高光事件引入，之後常態同行。
  - 構圖須用大小/前後/明度確立主從（角色陶紅最暖最前，旅伴稍退），避免雙焦點。
  - 需在 Phase 3 前補「相遇事件」的敘事與觸發規格。

## ADR-005：離線推進「有、慢、無損、同速」(OQ-2)

- **狀態**：Accepted (2026-07-03) — Fable 依規格收斂建議鎖定
- **Decision**：**採時間戳差值結算**。離開期間角色仍前行；**在線與離線同速**；只增不減（無損）；結算**上限 12 小時**；防作弊寬鬆（`elapsed<0`→0，超上限截斷）。
- **Rationale**：放置類「默默前行」的靈魂（ADR-003）。同速＝不懲罰「不掛著」（紅線六）；上限避免數值失控；純陪伴無競爭故寬鬆防弊即可。
- **Consequences**：回歸時以短動畫/旅程日誌呈現「你不在時走了多遠、路過哪裡」。技術見 `04` §4.3。

## ADR-006：互動「嚴格零功利」(OQ-3)

- **狀態**：Accepted (2026-07-03) — 使用者拍板
- **Decision**：互動只給**情感回饋、不給任何進度**。最小集合＝**點擊/靠近 → 角色暖心回應**（看向你、揮手、停步）；**不給資源、不加速、不解鎖**。signifier 用「角色生命反應」（游標變化 + 靠近微反應），**不掛常駐按鈕**。**初期排除餵食與對話系統**。
- **Rationale**：一旦互動有功利回報，就從「想互動」滑向「該互動」，踩紅線四（邀請非強迫）。守住「陪伴而非索求」。
- **Consequences**：
  - Phase 1 整窗點擊穿透即可（不需互動）；點擊回應屬 Phase 4，用動態 hit-test（`04` §2.5 策略 B）。
  - 命中區＝整個角色（Fitts's law）。餵食/對話若未來要做，須另立 ADR 並以「純享受、不做也無妨」為前提。

## ADR-007：存檔用 Codable + JSON 單檔 (OQ-4)

- **狀態**：Accepted (2026-07-03) — Fable 依規格收斂建議鎖定
- **Decision**：**Codable + JSON**，存 `~/Library/Application Support/FindYourWay/save.json`；**原子寫入 + `.bak` 備份 + `schemaVersion` 版本化遷移**。輕量偏好另存 UserDefaults。**單存檔**（重來＝刪檔）。
- **Rationale**：單玩家扁平狀態，JSON 可讀可遷移、可被其他 AI/人理解，最貼專案精神；存檔＝依附的物理載體（§4），故備份與版本化為必須。否決 Core Data/SwiftData（過度工程）。技術見 `04` §5。

## ADR-008：出貨先走 Developer ID，App Store 延後決定

- **狀態**：Accepted (2026-07-03) — Fable 鎖定
- **Decision**：**Phase 1–4 以 Developer ID + Notarization 為目標**（保留視窗/全域事件自由度）；是否上架 App Store 待 **Phase 5** 依實測沙盒限制再定。
- **Rationale**：點角色互動（策略 B）可能需全域滑鼠監聽，與 App Sandbox 有潛在衝突（`04` §7.5 / R3）；先不被沙盒綁死，出貨型態延後決策。

## ADR-009：呈現方式＝角色固定左側、世界捲動

- **狀態**：Accepted (2026-07-04) — 使用者拍板
- **Context**：Phase 1 初版小人在畫面中左右來回移動。使用者澄清期望的呈現。
- **Decision**：**角色固定在畫面左側、原地走路（walk-in-place）；以背景/世界向左捲動來表現「前進」。** 角色的螢幕水平位置恆定，不 roam。
- **Rationale**：
  - 放置類橫向捲軸的標準語言：主體定住、世界流動，最能表現「一直往前走的旅程」（敘事認同 `02` §5）。
  - 與 Phase 2 `WorldScroll` 模型一致：世界捲動由累積里程 `distance` 驅動，角色原地走 → render 降頻/暫停不影響「走到哪」。
- **Consequences**：
  - **於 Phase 2 實現，Phase 1 不翻工**（使用者確認）。Phase 1 現況「小人左右 roam」為過渡，Phase 2 `WorldScroll` 上線時一併改為「固定左側 + 世界捲動」。
  - `WalkMotion` 的水平「position」語意從「螢幕 x」改為「概念里程 `distance`」，用來驅動世界捲動，不再是角色螢幕座標。角色螢幕 x 固定（建議畫面左側約 20–25%）。
  - Phase 2 `WorldScroll`（`08` §3.8）依此：角色錨點左側固定，parallax 各層依 `distance` 向左捲動。
  - `03_DESIGN_SYSTEM` §2.4 圖層：角色層螢幕位置固定於左側。

## ADR-010：P1 推進速率定案 = 12，Phase 3 里程數值定案

- **狀態**：Accepted (2026-07-04) — 使用者 live 驗收「速度剛好」
- **Decision**：
  - **P1 推進速率 `SimulationRules.speed = 12`**（單位/秒，1 單位≈1pt）定案。悠閒可見的散步、低喚醒（`02` §6）。
  - **地標間距 86400**（≈2 小時/地標）定案。
  - **Phase 3 里程數值**（皆相對 P1，集中常數、可調）：旅伴相遇 `meetDistance = 237600`（≈5.5h travel，第 2–3 地標間，先單人鋪陳再相遇＝earned peak，ADR-004）；里程事件約每 ~1.5–2h 一個（稀疏，§9 E1）；章節門檻見 `09` §10。
- **Rationale**：P1 是 Phase 3 所有節奏的錨；使用者確認手感後即可定案下游數值。全為單一常數，日後可調。
- **Consequences**：`09_PHASE3_SPEC` §9 待決參數轉為定案（見該檔 §10 敘事內容附錄，由 Fable 親自 authored）。Phase 3 可開工。

---

## 待決策 (Open Questions)

> OQ-1~4 已全數定案（見 ADR-004~007）。目前無 open question。
> Phase 3 前需新增「相遇事件」敘事規格（承 ADR-004）。
