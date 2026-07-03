# 路線圖 (Roadmap)

> 分階段推進。每階段都必須「先文件、後實作」。里程碑完成後更新 `PROGRESS_LOG.md`。
>
> **測試紀律（專案級）**：每個 Phase 的交付都必須含測試，`swift test` 全綠才算完成。難測的 UI/runtime 靠「抽出純邏輯到可測 library」覆蓋（見 `06_PHASE1_SPEC` §2/§5b）；Simulation/Persistence（Phase 2+）為 TDD 主場。

## Phase 0 — 地基與規格 (Foundation & Specs) ◀ 目前所在
目標：把「先文字後實作」的地基打好，讓任何 session 能接手。
- [x] 憲法 `00_CONSTITUTION.md`
- [x] 決策 `01_DECISIONS.md`
- [x] 路線圖 `05_ROADMAP.md`
- [x] 進度日誌 `PROGRESS_LOG.md`
- [x] 心理學基礎 `02_PSYCHOLOGY_FOUNDATION.md`（Opus 草擬 → Fable Accepted）
- [x] 設計系統 `03_DESIGN_SYSTEM.md`（Opus 草擬 → Fable Accepted）
- [x] 技術架構 `04_ARCHITECTURE.md`（Opus 草擬 → Fable Accepted）
- [x] OQ-1~4 全數定案（ADR-004~008）並回填 `01_DECISIONS.md`

**Phase 0 完成 ✅** — 地基與規格齊備，可進 Phase 1。

## Phase 1 — 會走路的空殼 (Walking Skeleton)
目標：桌面上出現一個透明懸浮視窗，裡面一個像素方格人物在橫向走動。
- [ ] Xcode 專案骨架（Swift + SpriteKit + AppKit）
- [ ] 透明無邊框置頂視窗 + 點擊穿透
- [ ] 一個像素方格 sprite 的走路循環動畫（佔位美術）
- [ ] 橫向捲軸背景（單層佔位）
- 驗收：啟動後桌面右下角有個小人在走，不擋操作。

## Phase 2 — 時間感與旅程 (Time & Journey) ✅ 程式碼完成（56/56 綠，待 GUI 驗收）
目標：讓「放置＝前行」成立。
- [x] 時間推進系統（在線 + 離線推進，ADR-005；三路統一 capped 補算）
- [x] 里程/距離感（世界捲動 WorldScroll、5 個佔位地標、ADR-009 固定左側）
- [x] 存檔持久化（Codable+JSON、atomic+.bak、schema 遷移，ADR-007）
- [x] 併入：極簡選單列「結束」、省電 isPaused、離線回歸呈現（2.5s 淡出 + 旅程日誌）
- 驗收：關掉再開，人物「走了一段路」的感覺成立。 ← **待使用者 GUI 驗收**

## Phase 3 — 成長與偶發事件 (Growth & Encounters)
目標：純放置下的正回饋，用旅程事件營造，而非任務。
- [ ] 偶發事件系統（風景、休息、小相遇）
- [ ] 成長表現（外觀/等級/旅程日誌，依設計系統）
- 驗收：長時間掛著會「遇到事情、慢慢變化」。

## Phase 4 — 陪伴的質感 (Companionship Polish)
目標：把療癒感做到位（色彩、光影、聲音、微互動）。
- [ ] 色彩/光影隨時間（晝夜、天氣）
- [ ] 微互動（點擊回應等，依 OQ-3）
- [ ] 美術從像素方格升級為正式像素美術

## Phase 5 — 打包與長駐 (Ship & Live)
- [ ] 開機自啟、選單列常駐、偏好設定
- [ ] 打包與簽章（App Bundle）

> 各 Phase 進入前，先補齊該 Phase 的細部規格文件。
