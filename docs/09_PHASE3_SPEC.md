# Phase 3 建置規格 — 成長與偶發事件（Growth & Encounters）

> 狀態：**工程結構已審閱 (Accepted)** — Fable review 通過（2026-07-04）。
>
> **Fable review 註記**：核心設計採納且高度讚許 —— 事件掛里程軸（確定性取代變動比率）、A/B 事件分野（「隨機與持久不得共存」）、禁止清單、`wasCapped` 不吞事件、離線事件複用 `OfflineProgress.settle`、相遇為 peak event 但守 §3.4 無 jolt、成長階段純函式衍生不持久化。全部逐條符合 `02` §7 倫理界線。
>
> **已鎖定的設計原則（不依賴節奏，Fable 定案）**：E3 旅伴沉默留白/僅肢體語言/不命名；E4 不引入常駐等級數字、用章節名取代 Lv.N；E5 先走 authored 固定事件表（弱隨機池若用僅限同類變體、bucket-seed 非牆鐘）。皆與 Opus 傾向一致。
>
> **待 P1 手感驗證後才定的（§9）**：E1 事件密度、E2 相遇里程點、E6 事件內容清單、E7 成長門檻/外觀 —— 全部相對 P1 速率，須 Phase 2 GUI 驗收確認 P1 後才回填、才進 §7 第 9 步整合。§7 前 8 步（純邏輯 + 測試）在 P1 確認後即可開工。
>
> **依準則二「先文字後實作」。** 延續 `08_PHASE2_SPEC.md` 的 SPM 分層與既有模組（`GameState` / `SimulationRules` / `SimulationEngine` / `OfflineProgress` / `WorldScroll` / `SaveStore` / schema 版本化）。
>
> **目標一句話（承 `05_ROADMAP` Phase 3）**：純放置下的正回饋，用旅程**事件**與**顯性成長**營造，而非任務——長時間掛著會「遇到事情、慢慢變化」。
>
> **依據**：`05_ROADMAP` Phase 3；`02_PSYCHOLOGY_FOUNDATION` **§7 間歇性正增強的倫理界線（療癒 vs 剝削判準表）+ 六條紅線 + §5 敘事認同**；`01_DECISIONS` **ADR-004（旅伴相遇式引入）**、ADR-003（純放置）、ADR-005（離線同速無損）、ADR-006（互動嚴格零功利）、ADR-007（存檔版本化）；`03_DESIGN_SYSTEM` §3.3（具象成長 > 抽象數字）、§4 OQ-1（主從構圖）。
>
> **本 Phase 是全專案最靠近成癮式設計的地方。** 引入「事件」＝引入「意外的美好」，這正是變動比率增強（variable-ratio）最容易被反射性塞進來的縫隙。**本規格的核心工作，是讓每一個機制都能逐條對照 `02` §7 判準表，證明自己站在「療癒」側、不在「剝削」側。** §2.1 為此專章。

---

## 0. 驗收標準（Definition of Done）

1. **「遇到事情」成立**：長時間掛著（或模擬跨時後開啟），角色會在旅途中**遇到事件**（風景、休息、小相遇），並在某里程**相遇旅伴**後同行。事件呈現為溫和驚喜，**錯過無損**（離線期間發生的事件會被完整補上、可回顧）。
2. **「慢慢變化」成立**：隨旅程累積，出現**顯性成長**——角色外觀漸變 / 旅程章節感 / 旅程日誌累積。成長**只增不減**、是「同一個它長大」（`02` §4 依附一致性），非換一隻。
3. **事件系統守紅線（本 Phase 最高優先）**：事件觸發為**確定性 / 里程軸弱隨機**，逐條通過 `02` §7 判準表（見 §2.1）；**無**變動比率誘導查看、**無** FOMO、**無**功利獎勵（ADR-006）、**無**「盯著才觸發」機制（紅線六）。
4. **離線相容且可重現**：離線期間發生的事件，沿用 ADR-005 的確定性結算——**以里程/時間為 seed 的確定性推演**，**禁止**「以結算當下時間擲骰」。相同 `(state, now)` 必得相同事件序列（迴歸鎖，§2.3）。
5. **旅伴相遇為 peak event**：單人啟程 → 某里程相遇 → 之後常態同行。`companionJoined` 旗標**單調**（一旦相遇永不回退，紅線一）。相遇作為 peak-end 的高光時刻呈現（`02` §7）。
6. **存檔版本化升版**：新增欄位 → `SaveSchema.currentVersion` 由 **1 → 2**，補**真實** `MigrationV1toV2`（取代 Phase 2 的假想示範），舊存檔（v1）能無損遷移、新欄位給預設（`02` §4 存檔即依附載體，不得毀損）。
7. **`swift test` 全綠**：新測試（§5）全部通過；**Phase 1/2 既有測試不回歸**（目前 56/56）。
8. **分層對齊**：事件觸發判定、相遇判定、成長階段計算皆為**純函式**，放 `FindYourWayCore`，**不 import SpriteKit / AppKit**；Scene 層只「讀狀態來畫」。

> **Phase 3 不做**：正式像素美術（外觀漸變 Phase 3 用**佔位**表達，正式美術 Phase 4）、對話系統與餵食（ADR-006 排除）、點角色互動（Phase 4）、通知/推播（永不做召回式，紅線三）、色彩晝夜/天氣系統（Phase 4）。

> **⚠️ 前置依賴（施工前必須滿足，見 §8）**：Phase 2 手感（**P1 推進速率**）需先由**使用者 GUI 驗收確認**。Phase 3 的事件密度、旅伴相遇里程、成長階段門檻**全部相對於 P1 速率**定義，P1 未經人驗證前，這些數值只能是 provisional，不得硬編定案。

---

## 1. 設計總綱：事件與成長如何服務「陪伴 × 成長 × 療癒」

| Phase 3 機制 | 服務的情感目標 | 理論依據（`02`） | 落地 |
|---|---|---|---|
| 偶發事件（風景/休息/小相遇） | 陪伴（旅程有生機）、療癒（soft fascination） | §2 社會臨場感、§6 ART 低喚醒 | §2 |
| 旅伴相遇 + 同行 | **陪伴（核心）** | §2 擬社會關係、§4 依附、ADR-004 | §3 |
| 顯性成長（外觀/章節/日誌） | 成長（累積可見） | §3 漸進成就、§5 敘事認同 | §4 |
| 事件的倫理界線 | 療癒（守住不剝削） | **§7 間歇增強判準表** | §2.1 |

**一條總線（承 `02`）**：本專案追求**高愉悅 × 低喚醒的安在感**，不是高喚醒的成就感。事件是「值得偶爾一看的旅程風景」，不是「不看會錯過的獎勵」。成長是「回頭發現走了好遠」，不是「升級的快感刺激」。

---

## 2. 偶發事件系統（核心，最需心理學把關）

### 2.1 觸發哲學：確定性 / 里程軸弱隨機（逐條通過 `02` §7 判準表）

**根本設計決定：事件掛在「里程軸 (distance axis)」上，而非「時間擲骰」上。**

Phase 2 的地標（`Landmark`）已經示範了正確範式：地標是沿 `distance` 軸的**靜態里程碑**，用 `SimulationRules.landmarks(crossedFrom:to:)` 以**純函式、只看里程、不擲骰**的方式判定「通過了哪些」。**Phase 3 的里程事件，是這個範式的直接延伸**——事件也掛在里程軸上，角色前進到事件的里程就「遇到」它。

這個決定的意義：**「遇到事件」= 「走到了那裡」**，而不是「擲骰中了」。它把變動比率增強從根本上換成了**固定比率 / 確定性推進**——你走得夠遠就一定遇到，走多遠決定於時間（同速、無損、離線也走），與「你看不看」「你多常開」完全無關。

**逐條對照 `02` §7 判準表**（本 Phase 的核心防線，review 時逐格對照）：

| `02` §7 面向 | ✅ 療癒取向（本設計採用） | ❌ 剝削取向（本設計禁用） | Phase 3 的具體落地 |
|---|---|---|---|
| 意外驚喜的**目的** | 讓旅程有新鮮感、值得偶爾一看 | 為了拉高開啟頻率 / 停留時長 | 事件掛里程軸；事件密度以「豐富旅程」為準（§2.5 E1），**不以拉高開啟率為 KPI**（紅線五） |
| 獎勵**可預期性** | 溫和意外，但不製造「不看會錯過」 | 刻意不可預測以誘發強迫查看 | 事件在里程軸上是**確定的**；即使用弱隨機做「內容變化」，也以**里程 bucket 為 seed**（§2.3），**非以牆鐘擲骰**——同一段路你何時看都是同一批事件 |
| 錯過的**後果** | 錯過也不損失，回來一樣美好 | 錯過就永久失去（FOMO） | 離線期間經過的事件，結算時**完整補上並記入日誌**（§2.4）；沒有任何「限時 / 只出現一次不看就消失」的事件 |
| 對**離開**的態度 | 鼓勵使用者去過生活 | 用機制懲罰 / 挽留離開者 | 離線同速（ADR-005）＝離開時事件照樣發生；**無**任何「回來才觸發 / 在線加速觸發」分支（紅線六） |
| 成功**指標** | 使用者感到平靜、被陪伴 | 日活 / 時長 / 連續天數 | 本 Phase 成功＝「掛著會遇到溫柔的事、慢慢變化」的**被陪伴感**，**不**衡量開啟頻率/時長（紅線五） |

**明確禁止清單（施工時最易反射性越線，逐項否決）**：
- ❌ **以結算當下時間 / `now` 為 seed 擲骰決定「這次有沒有事件」**——這是變動比率的技術本體，直接踩 §7。事件必須是里程區間的**純函式**。
- ❌ **限時 / 限定 / 稀有掉落 / 開箱**——踩紅線二 FOMO。
- ❌ **事件給任何功利回報**（資源、加速、解鎖進度）——踩 ADR-006 嚴格零功利；事件**只給情感/敘事回饋**。
- ❌ **「在前景/盯著看才觸發或才觸發得更好」**——踩紅線六安心不看。
- ❌ **連續登入獎勵 / 每日事件 / streak**——踩紅線一。
- ❌ **用事件當召回鉤子推播通知**——踩紅線三。

> **一句話判準**：問「這個事件的設計，是為了讓旅程更值得偶爾一看，還是為了讓人更常來看？」——只有前者可進實作。

### 2.2 事件分類：狀態事件 vs 氛圍事件（關鍵架構分野）

為了同時滿足「豐富」與「確定性可重現」，把事件切成**兩類、兩種生命週期**：

| 類別 | 例子 | 觸發 | 是否入 `GameState` | 是否入日誌 | 離線是否補算 | 功利回報 |
|---|---|---|---|---|---|---|
| **A. 里程事件 (Milestone Event)** | 相遇旅伴、翻過某個埡口的「風景高光」、一次「休息紮營」 | **里程軸確定性**（純函式，同地標） | ✅ 記 `eventsEncountered`（只增去重） | ✅ | ✅ **完整補算** | ❌ 純情感/敘事 |
| **B. 氛圍微事件 (Ambient Micro-event)** | 一隻鳥飛過、角色停下看雲、伸個懶腰、路邊野花 | **在線 render 層**（可依畫面時間/隨機挑動畫，純裝飾） | ❌ 不入狀態 | ❌ 不記錄 | ❌ 不需補算（本就不持久） | ❌ 純裝飾 |

**為什麼這樣切（這是本 Phase 最重要的架構決定）**：
- **A 類**會影響持久狀態與日誌，因此**必須確定性、可重現、離線可補算**——它們是「旅程的節點」，走 §2.3/§2.4 的里程軸機制。
- **B 類**純粹是「角色活著」的臨場感表現（`02` §2 社會臨場感），**不碰 `GameState`、不記錄、不給任何回報**，所以它**可以**用在線隨機挑選動畫而**不引入任何確定性/離線問題**——因為它從不被結算、從不被回顧、錯過就錯過且**毫無損失**（連紀錄都沒有，天然守 §7「錯過無損」）。
- 這個分野讓我們「魚與熊掌兼得」：持久的東西全確定性（可測、可重現、離線相容），隨機的東西全是無足輕重的裝飾（不觸犯任何紅線）。

> **施工紅線**：B 類氛圍微事件**嚴禁**寫入 `GameState`、嚴禁記日誌、嚴禁給任何回報。一旦某個「隨機」的東西被持久化或被回顧，它就必須升級為 A 類、改走里程軸確定性。**「隨機」與「持久」不得共存。**

### 2.3 里程事件的觸發：純函式，可選的「里程 bucket seed」弱隨機

**主方案（推薦，最安全）：authored 固定事件表。** 如同 `Landmark.all`，里程事件也是一張**沿里程排序的靜態表** `JourneyEvent.all`，用純函式判定通過區間：

```swift
// SimulationRules 擴充（與 landmarks(crossedFrom:to:) 完全同構）
public func events(crossedFrom old: Double, to new: Double) -> [JourneyEvent] {
    guard new > old else { return [] }
    return JourneyEvent.all.filter { $0.distance > old && $0.distance <= new }
}
```

- 完全確定性、只看里程、不擲骰——**繼承地標已驗證的正確範式**。
- 事件內容（風景/休息/相遇）由 authored 表寫死，`留白可投射`的敘事語氣（`02` §5，同地標命名原則）。

**可選方案（弱隨機「內容變化」，供 Fable 定 §2.5 E5）**：若希望長旅程的事件不完全是固定腳本，可加一層**確定性 PRNG**，**以里程 bucket 索引為 seed**（**絕非牆鐘**）從事件池挑選：

```
bucketIndex = floor(distance / bucketSize)          // 里程分桶，確定性
eventForBucket(n) = pool[ hash(worldSeed, n) % pool.count ]   // 同一 bucket 永遠同一事件
```

- `worldSeed` 為**存檔內的固定常數**（存檔建立時寫入一次、永不變），或直接用固定編譯常數。
- 關鍵：**seed 只依賴 bucket 索引（里程的函式），不依賴 `now`**。→ 同一段路、任何時候結算（在線逐次 / 離線一次），挑出的事件**完全相同** → 滿足 §7「不製造不看會錯過」+ 離線可重現。
- 這仍**不是**變動比率：使用者無法透過「多開幾次 / 多看」改變事件，唯一變數是「走多遠」，而走多遠只由時間決定。

> **Opus 傾向**：Phase 3 **先走主方案（authored 固定表）**——最安全、最好把握敘事留白分寸、最易測。弱隨機池作為 §2.5 E5 分叉留給 Fable，若要引入也僅用於 B 類氛圍或「同類事件的變體挑選」，不改變「哪裡有事件」這件確定的事。

### 2.4 離線期間的事件：與 ADR-005 確定性結算相容

Phase 2 的 `OfflineProgress.settle` 目前**無隨機**，只算 `distance` 增量與 `landmarks(crossedFrom:to:)`。Phase 3 的里程事件**沿用同一條路徑**，零破壞地擴充：

```swift
// OfflineProgress.settle 內，SimulationEngine.advance 之後：
// 除了 crossed landmarks，同時收集 crossed events（同一區間、同一純函式範式）
let crossedEvents = rules.events(crossedFrom: oldDistance, to: newDistance)
// 併入 state.eventsEncountered（去重、保序、只增），併入 OfflineOutcome.newEvents
```

- **確定性保證**：`elapsed` 由 `min(max(now - lastActive, 0), capSeconds)` 夾定（ADR-005 不變），`distance` 增量是 `elapsed × speed` 的純函式，事件是 `(oldDistance, newDistance]` 的純函式 → **相同 `(state, now)` 必得相同事件序列**。
- **不擲骰**：全程無 `now`-seeded 隨機（§2.1 禁止清單第一條的工程落地）。
- **與線上一致（迴歸鎖）**：離線一次結算 `elapsed=T` 經過的事件，必須 == 線上逐 tick 走完同樣 `distance` 經過的事件（§5 T2 測試守住，同 Phase 2 的「在線=離線同速」迴歸鎖精神）。
- **`wasCapped` 的事件語意**：若離線超過 12h 上限被截斷，只結算 12h 份量的里程與其區間內的事件；**未走到的里程與其事件不會消失**——它們還在里程軸上，下次繼續走就會遇到（**天然守紅線二**：不是「錯過了」，是「還沒走到」）。`wasCapped` **不得**呈現成「你錯過了 N 個事件」。
- **旅伴相遇的離線相容**：相遇是一個里程事件（§3），若使用者離線期間跨越相遇里程，結算時 `companionJoined` 置 true、`newEvents` 含相遇事件 → 回歸呈現時把相遇當 peak 補演（§3.4）。

### 2.5 事件的存檔（延續 `GameState` / schema 版本化）

`GameState` 新增欄位（延續 Phase 2 的手動 Codable + `decodeIfPresent` 向後相容範式）：

```swift
public struct GameState: Codable, Equatable {
    // ... Phase 2 既有：schemaVersion / distance / landmarksPassed / lastActiveTimestamp / growth
    public var eventsEncountered: [String]   // 已遇里程事件 id，有序、去重、只增（同 landmarksPassed 範式）
    public var companionJoined: Bool         // 旅伴是否已相遇同行；單調 false→true，永不回退（紅線一）
    // growthStage 不持久化：由 growth/distance 純函式衍生（§4.2），避免狀態漂移
}
```

- **schemaVersion 1 → 2**：`SaveSchema.currentVersion = 2`。
- **`MigrationV1toV2` 改為真實遷移**（取代 Phase 2 的假想示範）：v1 存檔缺 `eventsEncountered` / `companionJoined` → 補預設（`[]` / `false`），舊資料（distance/landmarks/growth）原樣保留、不丟失。這正是 Phase 2 §3.7 埋的「示範骨架」轉正之處。
- **向後相容**：`GameState.init(from:)` 對新欄位用 `decodeIfPresent(...) ?? 預設`，v1 檔即使不經遷移器也能安全解出合理預設（雙保險，同 Phase 2 範式）。
- **只增不減不可變式擴充**：`eventsEncountered` 不得移除元素、`companionJoined` 不得由 true 轉 false——由 `SimulationEngine`/`OfflineProgress` 保證、測試守（§5）。

---

## 3. 旅伴相遇（ADR-004）

### 3.1 敘事與觸發

- **單人啟程**：Phase 1–2 已是單人；旅伴初始不存在（`companionJoined = false`）。
- **相遇**：旅伴是一個**特殊的里程事件**，掛在 `Companion.meetDistance`（§2.5 E2 待 Fable 定，相對 P1 速率）。角色前進到該里程 → 觸發相遇事件 → `companionJoined = true`（單調）。
- **之後同行**：`companionJoined == true` 後，Scene 層常態渲染旅伴跟隨角色（walk-in-place 同框）。
- **離線相容**：走 §2.4，離線跨越相遇里程一樣觸發，回歸時補演。
- **只發生一次**：相遇事件經 `eventsEncountered` 去重 + `companionJoined` 旗標雙重保證只觸發一次（§5 測試守）。

### 3.2 相遇作為 peak event（`02` §7 peak-end）

- **peak-end rule**（`02` §7 / `03` §3.3）：一段體驗的記憶由「高峰」與「結尾」主導。相遇應是**整段旅程目前為止的情感高峰**——單人走了一段路後「終於有人陪你走」，這是 ADR-004 的核心動人點（把陪伴變成**被賺得的**高光）。
- **呈現規格**（`03` §3.3 正向事件 + §3.4 動效）：
  - 暖陽金（`#F2C14E`）光暈 + **慢**放大 + 輕音，數秒即散——**但守 `03` §3.4「無突兀回饋」**：暖、慢、有機，**禁止** overshoot 彈跳 / 閃爆 / 螢幕震動（那是 dopamine-hit 遊戲語言，與低喚醒陪伴衝突）。相遇的高光是「溫暖地亮起來」，不是「爆一下」。
  - 相遇後在旅程日誌記一筆里程碑式的一行（敘事留白語氣）。
- **可回顧**：相遇之後可於旅程日誌回看（progressive disclosure），強化「這段旅程有個溫暖的轉折」的敘事認同（`02` §5）。

### 3.3 視覺構圖：大小/前後/明度確立主從（ADR-004 / `03` §4 OQ-1）

- **主從關係用構圖建立，不用顏色搶**（`03` §1.2 冷底暖點）：
  - **主角**：陶紅 `#C56A4E`，**最暖、最前（zPosition 較高）、最亮**——全畫面視線第一落點。
  - **旅伴**：略小 / 略後（zPosition 較低）/ 明度略降——在場但不搶焦點，避免雙焦點打架（ADR-004 Consequences）。
- **同行動態**：旅伴 walk-in-place 與主角同步；回應性微行為（`02` §4 依附回應性）——主角休息時旅伴停下、偶爾看向主角。這服務「有人與你同行」的社會臨場感（`02` §2）。

### 3.4 「留白給投射 vs 角色生命力」的張力（`02` OQ-1、§5）——設計分寸建議

這是 `02` §5「給 review 者的重點提示」明列的最須把關張力之一。Opus 的分寸建議（**供 Fable 定 §2.5 E3，不自行拍板**）：

| 維度 | 傾向 | 理由 |
|---|---|---|
| 語言 | **沉默旅伴，無對話** | ADR-006 排除對話系統；`02` §5「沉默的陪伴更留白、更好投射」；避免「已讀不回」社交壓力（`02` OQ-3） |
| 個性表達 | **僅肢體語言 / 微行為**（看向你、停步、伸懶腰） | 有「生命力」（`02` §2 臨場感）但不塞背景故事——過度具體的角色設定會擠掉使用者的投射空間（`02` §5 敘事留白） |
| 命名/身世 | **不命名、不給身世** | 留白最大化；旅伴是「陪你走的那個存在」，其意義由使用者填入（`02` §5 療癒來自使用者自己賦意） |
| 一致性 | 相遇後**一直是它**、外觀連續 | `02` §4 依附之一致性——不換角、不劇變 |

> **分寸原則一句話**：旅伴要「**像活的、會回應你，但不多話、不搶戲**」——足以承載陪伴感（不是背景板），又克制到讓使用者把它讀成「我的旅伴」（不是「編劇安排的 NPC」）。**這條張力無法一次調準，需在 GUI 上反覆手感校準**，故列為 Fable/使用者拍板項。

---

## 4. 顯性成長表現（Phase 2 只做連續量，Phase 3 開始顯性）

### 4.1 方針：具象成長優先於抽象數字（`03` §3.3）

Phase 2 只有連續 `growth` 量、不做等級。Phase 3 讓成長**看得見**，但嚴守 `03` §3.3「用世界的變化說話，用數字說話是最後手段」：

| 要表達的成長 | 主要視覺語言（glanceable、具象、克制） | 次要（progressive disclosure 展開） | 依據 |
|---|---|---|---|
| 「走了多遠 / 成長階段」 | **角色外觀漸變**（Phase 3 佔位：姿態/色澤微變、拾得一根旅杖等；正式美術 Phase 4）＋**背景地貌推進** | hover 顯示章節名 / 稱號 | `03` §3.3 具象 > 數字；`02` §4「同一個它長大」 |
| 「旅程的故事」 | **旅程日誌 / 章節感**：地標、事件、相遇累積成可瀏覽的時間軸 | 點開日誌時間軸 | `02` §5 敘事認同；`03` §3.2 progressive disclosure |
| 「當下狀態」 | 角色姿態與微動作（散步/歇腳/看風景）＋（Phase 4 晝夜氛圍） | — | `03` §3.3 動作即狀態，零文字 |

- **禁止**（`03` §3.3）：常駐血條 / 經驗條 / 紅點 / 百分比 HUD / Lv 數字常駐——這些是任務型遊戲語言，與療癒定位相悖。
- **章節感**：把旅程切成「章」（相對里程 / 通過某地標為章界），日誌以章節組織。這服務 `02` §5 敘事認同（「把生命組織成有連續性的故事」）。

### 4.2 成長階段：純函式衍生，不持久化

```swift
// GrowthStage.swift（純邏輯，可測）
public enum GrowthStage {
    /// 由 distance（或 growth）以確定性門檻對應到成長階段索引/章節。
    /// 純函式、單調不減（distance 只增 → stage 只增），不持久化以避免狀態漂移。
    public static func stage(forDistance distance: Double) -> Int { /* 門檻表對應 */ }
    public static func chapterName(forDistance distance: Double) -> String { /* 留白意象命名 */ }
}
```

- **衍生而非儲存**：`growthStage` 由 `distance` 純函式算出，不存進 `GameState`（避免衍生欄位與 `distance` 漂移不一致）。
- **單調不減**：`distance` 只增 → stage 只增（紅線一，測試守）。
- 門檻表集中一處（同 `SimulationRules.speed` 的單一數值來源精神），相對 P1 速率定義（§8 依賴）。

### 4.3 是否引入「等級」數字？——Opus 傾向

**傾向：不引入常駐等級數字；用「章節名」取代「Lv.N」。** 理由：

- `03` §3.3 白紙黑字「具象成長 > 抽象數字」「數字是最後手段」「禁止常駐 Lv/百分比 HUD」。
- `02` §1 ⚠️「勝任感要去挑戰化」——不是「我升到 N 級」的成就感（高喚醒），而是「我們一起走了很遠」的累積感（低喚醒）。等級數字天然帶「衝下一級」的目標性驅力，與低喚醒安在感相悖。
- **若真要有數字**（`03` §3.3 保留「需要精確值的使用者仍能取得」）：藏在 progressive disclosure 之後（hover / 點開日誌才顯示章節序數或稱號），**不對所有人強制曝光、不常駐**。

> 這是 §2.5 E4 分叉，最終由 Fable 拍板。Opus 立場偏「章節名 > 等級數字」。

---

## 5. 分層與可測（TDD 清單）

延續 `FindYourWayCore` 純邏輯可測原則：事件觸發判定、相遇判定、成長階段計算、離線事件補算 → 全純函式、**不 import SpriteKit**。

### 新增 / 修改測試

**T7 `JourneyEventTests`（里程事件觸發，純函式）**
- `events(crossedFrom:to:)` 回傳 `(old, new]` 區間內事件，**確定性、去重、保序**（同 T1 地標範式）。
- `new <= old` → 空。
- 事件表依里程排序不變式。
- （若採 §2.5 E5 弱隨機池）`eventForBucket(n)` 對同一 bucket 恆回同一事件；**不依賴 `now`**（餵不同「牆鐘」得同結果）。

**T8 `OfflineEventTests`（離線事件補算 — 靈魂測試，承 T2 精神）**
- **離線=線上事件一致**：`settle(elapsed=T)` 收集的 `newEvents` == 線上逐 tick 走完同 `distance` 收集的事件（迴歸鎖）。
- **確定性可重現**：相同 `(state, now)` 呼叫兩次，`newEvents` 逐元素相等（**無 `now`-seeded 隨機**）。
- **`wasCapped` 不吞事件**：超上限截斷只結算 12h 份量事件，未走到的事件不消失（下次繼續走會遇到）。
- **只增不減**：`eventsEncountered` 任意序列後單調不減、不移除。

**T9 `CompanionTests`（旅伴相遇判定）**
- 跨越 `meetDistance` → `companionJoined` 置 true、`newEvents`/`eventsEncountered` 含相遇事件。
- **只觸發一次**：多次結算 / 反覆跨越 → 相遇事件不重複入 `eventsEncountered`、`companionJoined` 保持 true。
- **單調**：`companionJoined` 一旦 true，後續任何 advance/settle 不得轉 false。
- **離線相遇**：離線跨越 `meetDistance` → 同樣觸發（走 T8 路徑）。

**T10 `GrowthStageTests`（成長階段，純函式）**
- 門檻對應正確（各門檻邊界無 off-by-one）。
- **單調**：`distance` 增 → `stage` 不減。
- `chapterName` 對應正確、確定性。

**T11 `SaveMigrationV2Tests`（schema 1→2 真實遷移，擴充 Phase 2 T4）**
- v1 存檔（無 `eventsEncountered`/`companionJoined`）→ 經 `MigrationV1toV2` → 得合法 v2，**舊資料不丟失、新欄位給預設**。
- `schemaVersion == 2` 直解不遷移。
- v1 檔即使不經遷移器，`decodeIfPresent` 也解出安全預設（向後相容雙保險）。
- `version > current` 安全降級（沿用 Phase 2）。

**T12 `GameStateCodableTests` 擴充**
- 新欄位 round-trip 冪等；缺新欄位 → 預設；`schemaVersion` 編碼為 2。

**迴歸**：Phase 1/2 既有 56 測試不回歸（特別是 T2 在線=離線同速的迴歸鎖，加入事件後仍須綠）。

---

## 6. 檔案結構（延續 `06`/`08` 的 SPM 分層）

```
FindYourWay/
├─ Sources/
│  ├─ FindYourWayCore/
│  │  ├─ Simulation/
│  │  │  ├─ GameState.swift              # 修改：+eventsEncountered +companionJoined（Codable 向後相容）
│  │  │  ├─ JourneyEvent.swift           # 新增：里程事件模型 + JourneyEvent.all 靜態表（純資料）
│  │  │  ├─ EventDeck.swift              # 新增（可選，§2.5 E5）：bucket-seed 弱隨機池，確定性挑選
│  │  │  ├─ Companion.swift              # 新增：meetDistance 常數 + 相遇判定（純函式）
│  │  │  ├─ GrowthStage.swift            # 新增：distance→階段/章節名 純函式（衍生，不持久化）
│  │  │  ├─ SimulationRules.swift        # 修改：+events(crossedFrom:to:)（同 landmarks 範式）
│  │  │  ├─ SimulationEngine.swift       # 修改：advance 併收集 crossed events + 相遇旗標
│  │  │  ├─ OfflineProgress.swift        # 修改：settle 併收集 crossed events（確定性補算）
│  │  │  ├─ OfflineOutcome.swift         # 修改：+newEvents +companionJustJoined（供 Scene 呈現）
│  │  │  └─ (Landmark/TimeProvider 沿用)
│  │  ├─ Persistence/
│  │  │  ├─ SaveSchema.swift             # 修改：currentVersion 1→2
│  │  │  └─ Migrations/MigrationV1toV2.swift  # 修改：假想示範 → 真實 v1→v2 遷移
│  │  ├─ Scene/
│  │  │  ├─ GameScene.swift              # 修改：事件呈現、相遇 peak 呈現、日誌/章節；消費 newEvents
│  │  │  ├─ CompanionNode.swift          # 新增：旅伴 sprite（構圖主從，佔位）
│  │  │  ├─ JourneyLog.swift             # 新增（可純邏輯部分）：日誌條目彙整（可測）
│  │  │  └─ (WorldScroll/CharacterNode/ParallaxBackground 沿用)
│  │  └─ ...（Support/Window 沿用）
│  └─ FindYourWay/                       # executable 薄殼：AppDelegate 傳 outcome.newEvents 給 Scene
└─ Tests/FindYourWayCoreTests/
   ├─ JourneyEventTests.swift            # 新增 T7
   ├─ OfflineEventTests.swift            # 新增 T8
   ├─ CompanionTests.swift              # 新增 T9
   ├─ GrowthStageTests.swift            # 新增 T10
   ├─ SaveMigrationV2Tests.swift        # 新增 T11（或擴充既有 SaveMigrationTests）
   └─ (GameStateCodableTests 擴充 T12；既有測試不回歸)
```

> **分層要點**：`SimulationRules.events(crossedFrom:to:)` 與 `landmarks(crossedFrom:to:)` 同構、共用「里程區間純函式」範式；`SimulationEngine`（線上）與 `OfflineProgress`（離線）**都呼叫它**——這保證線上/離線事件同一套判定（ADR-005 同速的工程保證延伸到事件）。

---

## 7. 施工順序（逐步可驗，TDD）

> 每步先寫測試（紅）→ 實作（綠）。全程 headless，不啟動 NSApplication。

1. **`JourneyEvent` + `JourneyEvent.all`**：里程事件模型與靜態表（authored）。測 T7。
2. **`SimulationRules.events(crossedFrom:to:)`**：純函式判定（複製 landmarks 範式）。測 T7。
3. **`GameState` 擴充**：+`eventsEncountered` +`companionJoined`，Codable 向後相容。測 T12。
4. **`SimulationEngine.advance` 擴充**：併收集 crossed events、更新 `eventsEncountered`（去重保序只增）。測 T7 延伸 + 只增不減。
5. **`Companion`（meetDistance + 判定）**：相遇為特殊里程事件 → 置 `companionJoined`。測 T9。
6. **`OfflineProgress.settle` 擴充 + `OfflineOutcome` +`newEvents`/`companionJustJoined`**：離線確定性事件補算。測 T8（靈魂測試 + 迴歸鎖）。
7. **`GrowthStage`**：distance→階段/章節純函式。測 T10。
8. **`SaveSchema` 1→2 + 真實 `MigrationV1toV2`**：版本升級與遷移。測 T11。
9. **Scene/executable 整合**（難自動測，靠 §0 人工驗收）：`GameScene` 消費 `newEvents`（線上 tick + 回歸補演）、相遇 peak 呈現（暖光慢放大、無 jolt）、`CompanionNode` 構圖主從、旅程日誌/章節；`AppDelegate` 傳 `outcome.newEvents`。
10. **`swift test` 全綠**（新測試 + Phase 1/2 不回歸）→ 人工驗收「掛著會遇到事、相遇旅伴、慢慢變化」→ 更新 `PROGRESS_LOG` / `05_ROADMAP`。

---

## 8. 依賴提醒（施工前置條件）

- **⚠️ Phase 2 手感（P1 推進速率）需先經使用者 GUI 驗收確認。** `05_ROADMAP` 標記 Phase 2 為「程式碼完成（56/56 綠），**待 GUI 驗收**」。Phase 3 的**事件密度**（§2.5 E1）、**旅伴相遇里程**（E2）、**成長階段門檻**（§4.2）**全部相對於 P1 速率**定義——P1 未由人驗證「悠閒感」對不對之前，這些數值只能是 provisional，**不得硬編定案、不得開始 §7 第 9 步整合**。§7 前 8 步（純邏輯 + 測試）可先做，但事件/相遇/階段的**具體里程數值**待 P1 確認後回填。
- **Phase 2 的 GUI 驗收本身**（`07`/`08` §0）尚未由使用者完成回報；Phase 3 實作啟動前應確認 Phase 2「關掉再開走了一段路」成立、手感 OK。
- **schema 1→2 遷移**上線前，確認 Phase 2 存檔（v1）在真實使用者機器上能無損遷移（`02` §4 存檔即依附載體，最嚴重的體驗事故是資料遺失）。

---

## 9. 待決產品參數 / 設計分叉（供 Fable 定案，Opus 不拍板）

> 工程上這些多半集中在少數常數 / 一張 authored 表，改一處即可。Opus 附傾向，**定案權在 Fable**（部分最貼手感者可能需再向使用者確認，如 Phase 2 的 P1/P6）。

| # | 待決 | 影響 | Opus 傾向 |
|---|---|---|---|
| **E1** | **事件密度 / 頻率**：每「旅程日」遇幾個 A 類里程事件？ | 旅程節奏、是否「太滿變刷、太稀變空」 | **稀疏**：每旅程日 ≤ 1 個里程事件（甚至更疏），維持「偶遇」而非「刷」。相對 P1 速率定義，與地標密度（`08` P3）錯開或並置由 Fable 定。 |
| **E2** | **旅伴相遇里程點**：`Companion.meetDistance` 落在哪？ | 「單人鋪陳 → 相遇高光」的節奏 | **在第一章尾聲**（約第 2–3 個地標處）：先讓單人獨行「成立一段」再相遇，讓陪伴是「被賺得的」（ADR-004 peak）。太早＝沒鋪陳，太晚＝孤單太久。 |
| **E3** | **旅伴個性分寸**：沉默留白 vs 有名有個性？ | 陪伴感 vs 投射空間（`02` §5 張力） | **沉默、僅肢體語言、不命名、不給身世**（§3.4）。需 GUI 手感校準，可能需使用者確認。 |
| **E4** | **是否引入等級數字？** | 成長呈現形式 | **不引入常駐等級數字；用章節名取代 Lv.N**（§4.3）；若要數字，藏 progressive disclosure 之後。 |
| **E5** | **事件多樣性來源**：authored 固定表 vs bucket-seed 弱隨機池 | 長旅程是否「固定腳本」、敘事留白可控性 | **Phase 3 先 authored 固定表**（最安全、最好把握留白、最易測）；弱隨機池若引入，僅用於同類變體挑選、以 bucket 為 seed（非牆鐘），不改「哪裡有事件」的確定性。 |
| **E6** | **事件類型清單與情感/敘事內容**：風景/休息/小相遇具體有哪些、日誌文案 | 旅程的實際質感、敘事留白語氣 | 走 `02` §5 留白可投射意象（同地標命名「風起的埡口」風格）；**皆無功利回報**（ADR-006），只給情感/敘事。具體清單需 Fable/使用者共同填。 |
| **E7** | **成長階段門檻與外觀漸變的視覺表現** | 成長「看得見」的節奏；美術依賴 | 門檻相對 P1 定；外觀漸變 Phase 3 用**佔位**表達（姿態/色澤微變、拾旅杖佔位），**正式像素美術留 Phase 4**（`03` §2.2）。 |

---

## 10. 敘事內容（Fable authored，定案 · P1=12 / 間距 86400 已確認）

> 由 Fable 親自撰寫，把關「留白可投射、不施壓、不量化」的語氣（`02` §5 敘事認同）。
> 皆為 authored 固定表（§2.5 E5）。所有 `distance` 為單位（1 單位≈1pt，speed 12）。**純情感/敘事回饋、零功利**（ADR-006）。
> 名稱/文案可再微調，數值集中常數（`Landmark.all` / `JourneyEvent.all` / `Companion.meetDistance` / `GrowthStage` 門檻）。

### 10.1 地標顯示名（Landmark，改為留白中文；`Landmark.all` 五個，間距 86400）
| distance | id | 顯示名 |
|---|---|---|
| 86400 | windy_pass | 風起的埡口 |
| 172800 | nameless_bend | 無名的河灣 |
| 259200 | old_bridge | 一座舊石橋 |
| 345600 | misty_forest_edge | 霧起的林邊 |
| 432000 | first_snowline | 遠山的第一道雪線 |

### 10.2 里程事件（`JourneyEvent.all`，A 類，稀疏 ~每 1.5–2h，純情感/敘事）
| distance | id | 類型 | 旅程日誌文案（留白語氣） |
|---|---|---|---|
| 43200 | wildflower_slope | 風景高光 | 「路過一片開得正好的野花坡。」 |
| 129600 | streamside_rest | 紮營/休息 | 「在溪邊歇了歇腳，水很涼。」 |
| 216000 | bird_on_stone | 小相遇 | 「一隻鳥停在石上，看了你一會兒，才飛走。」 |
| 302400 | cloud_shadows | 風景高光 | 「雲影慢慢掠過整片草原。」 |
| 388800 | small_campfire | 紮營 | 「夜裡生了一小堆火，聽了一會兒柴響。」 |

### 10.3 旅伴相遇（`Companion.meetDistance = 237600`，特殊里程事件，peak）
- **觸發**：跨越 237600（第 2–3 地標之間，約 5.5h travel）→ `companionJoined = true`（單調）。
- **日誌文案**：「在岔路口，有個人也正要往同一個方向。你們沒說話，卻自然地一起走了。」
- **呈現**：暖陽金 `#F2C14E` 光暈 + 慢放大，數秒即散（`03` §3.4 無 jolt——溫暖亮起，不是爆一下）。之後 `CompanionNode` 常態同行（沉默、僅肢體語言、不命名、E3）。

### 10.4 章節（`GrowthStage.chapterName`，具象成長，非等級數字 E4）
| 起始 distance | 章節名 |
|---|---|
| 0 | 第一章 · 啟程 |
| 237600 | 第二章 · 有人同行（相遇後） |
| 432000 | 第三章 · 遠方的雪 |

- 章節僅在 progressive disclosure（hover/點日誌）顯示，**不常駐 HUD**（`03` §3.3）。外觀漸變 Phase 3 用佔位（如相遇後旅伴在場、姿態微變），正式美術 Phase 4。

> **定案摘要**：§9 待決 E1（稀疏，5 個里程事件）、E2（meetDistance 237600）、E4（章節名非等級）、E6（上表文案）、E7（章節門檻）皆定案；E3（沉默留白）、E5（authored 表）沿用已鎖。全部單一常數/表，可調。

---

*本文件 §1–§9 為 Phase 3 建置規格；§10 為 Fable authored 敘事內容（定案）。P1=12 已由使用者驗收，Phase 3 可開工。*
