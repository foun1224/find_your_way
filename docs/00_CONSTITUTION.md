# Find Your Way — 專案憲法 (Constitution)

> 本文件是整個專案的最高準則。任何規劃、設計、實作若與本文件衝突，以本文件為準。
> 修改本文件需明確記錄於 `PROGRESS_LOG.md` 並說明理由。

## 一、專案願景 (Vision)

**Find Your Way** 是一款 macOS 原生桌面軟體，形式為**桌寵式懸浮陪伴**：
一個中古世紀風格的 2D 橫向捲軸放置類冒險，人物在透明懸浮視窗中自主走動、冒險、成長。

核心情感目標：**「有人陪你走人生這場冒險，過程中一起成長與學習。」**
不是遊戲的征服感，而是**低負擔的陪伴感**與**默默前行的療癒感**。

靈感來源：Ghibli 風格的旅人翻山越嶺影像（使用者提供），
與桌寵（desktop pet）的常駐陪伴機制結合。

---

## 二、三條不可打破的準則 (The Three Inviolable Principles)

### 準則一：心理學為本 (Psychology-First)
**任何機制與設計，都必須有對應的心理學 / 色彩學 / UI-UX 理論基礎。**
- 沒有理論依據的機制不得進入實作。
- 每一個設計決策，都要能回答：「這背後的理論是什麼？它如何服務『陪伴 × 成長』的情感目標？」
- 理論依據集中記錄於 `02_PSYCHOLOGY_FOUNDATION.md`，並在各設計文件中反向引用。

### 準則二：先文字，後實作 (Document-Before-Build)
**所有規劃與實作，都必須先有文字記錄，才能動手實作。**
- 目的：確保任何一個 session 壞掉時，另一個 session 能無縫接手。
- 每個功能在實作前，必須在 `docs/` 下有對應規格文件。
- 每次工作階段結束前，必須更新 `PROGRESS_LOG.md`（做了什麼、決定了什麼、下一步是什麼）。
- 實作與文件不同步，視為 bug。

### 準則三：分層協作、節省 token (Delegate-to-Save-Tokens)
**角色分工固定如下：**
- **Fable（我）**：專案負責人。負責整體規劃、設計、決策、review。不親自寫大量實作碼。
- **Opus**：較小範圍的規劃 / 深度規格草擬。產出後由 Fable review。
- **Sonnet / Codex**：實際實作。依照已定案的規格施工，由 Fable review。
- 原則：能委派就委派；Fable 的 token 用於「決策與把關」，不用於「產出草稿與碼」。

---

## 三、定案的基礎決策 (Locked Decisions)

| 項目 | 決定 | 記錄於 |
|------|------|--------|
| 存在形式 | 桌寵式懸浮視窗（透明、無邊框、可置頂） | ADR-002 |
| 技術棧 | Swift + SpriteKit（macOS 原生） | ADR-001 |
| 成長模型 | 純放置陪伴（零負擔、療癒取向） | ADR-003 |
| 美術 | 像素風（pixel art），初期以像素方格佔位 | 03_DESIGN_SYSTEM |

詳見 `01_DECISIONS.md`。

---

## 四、文件地圖 (Document Map)

```
docs/
  00_CONSTITUTION.md          ← 本文件（最高準則）
  01_DECISIONS.md             ← 架構決策記錄 (ADR)
  02_PSYCHOLOGY_FOUNDATION.md ← 心理學/色彩學/UX 理論基礎（機制的依據來源）
  03_DESIGN_SYSTEM.md         ← 設計系統：色彩、UI/UX、像素美術規範
  04_ARCHITECTURE.md          ← 技術架構：Swift/SpriteKit、視窗、存檔
  05_ROADMAP.md               ← 分階段里程碑
  PROGRESS_LOG.md             ← 逐 session 進度日誌（接手用）
```

**接手一個新 session 時的閱讀順序：**
`PROGRESS_LOG.md`（最新狀態）→ `00_CONSTITUTION.md` → 對應功能的規格文件。
