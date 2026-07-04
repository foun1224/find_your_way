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

## Phase 3 — 成長與偶發事件 (Growth & Encounters) ✅ 完成（106/106 綠，真機驗證）
目標：純放置下的正回饋，用旅程事件營造，而非任務。
- [x] 偶發事件系統（5 個里程事件，掛里程軸確定性、守 §7 倫理界線）
- [x] 旅伴相遇（meetDistance 237600、peak、單調、離線可相遇、CompanionNode 同行）
- [x] 成長表現（GrowthStage 章節純函式 + 跨章節旅程日誌 toast；顯性等級數字不做，E4）
- [x] schema 1→2（save 戳版本、v1 向後相容不丟資料）
- 驗收：長時間掛著會「遇到事情、慢慢變化」。 ← ✅ 真機驗證（離線 6h→相遇+事件+遷移）

## Phase 4 — 陪伴的質感 (Companionship Polish)
目標：把療癒感做到位（色彩、光影、聲音、微互動）。
- [ ] 色彩/光影隨時間（晝夜、天氣）
- [ ] 微互動（點擊回應等，依 OQ-3）
- [ ] 美術從像素方格升級為正式像素美術

## Phase 5 — 打包與長駐 (Ship & Live) ✅ 程式碼完成（126/126 綠，待安裝驗收）
- [x] 開機自啟（SMAppService）、選單列狀態卡片、偏好設定視窗（SwiftUI）
- [x] 打包與 ad-hoc 簽章（build_app.sh SIGN_MODE=adhoc，codesign 驗過）
- 待使用者：裝進 /Applications → 首次開啟 → 開自啟 → **重開機驗 R1**（安裝指南 `11_INSTALL_GUIDE.md`）

> 各 Phase 進入前，先補齊該 Phase 的細部規格文件。

---

## 里程碑：Phase 0–3 + 5 完成（僅 Phase 4 質感/正式美術待做）
核心陪伴循環 + 可安裝常駐皆成立，佔位美術。剩 Phase 4（正式像素美術/晝夜/天氣/點角色微互動）——需美術路線決策。
