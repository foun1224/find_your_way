# Find Your Way

一款 **macOS 原生桌寵式懸浮陪伴軟體**：中古世紀像素風、2D 橫向捲軸放置類冒險。
一個旅人在透明懸浮視窗中自主走動、翻山越嶺、默默前行 —— 靈感來自 Ghibli 風格的翻山旅途。

> 核心情感目標：**「有人陪你走人生這場冒險，過程中一起成長與學習。」**
> 追求低負擔的**陪伴感與療癒感**，不是遊戲的征服感。

## 設計準則（不可打破）

1. **心理學為本** — 任何機制/設計都要有心理學、色彩學、UI/UX 理論依據。
2. **先文字後實作** — 一切先寫進 `docs/`，確保任何 session 壞掉能無縫接手。
3. **分層協作省 token** — 規劃/review 與實作分工。

## 技術棧

Swift + SpriteKit + AppKit（透明無邊框置頂懸浮視窗）。SPM 專案。最低 macOS 13。
決策理由見 `docs/01_DECISIONS.md`（ADR）。

## 開發

```bash
swift build      # 建置
swift test       # 執行測試（純邏輯層，headless）
swift run        # 啟動桌寵（Ctrl-C 結束）

bash scripts/build_app.sh && open FindYourWay.app   # 打包並執行 .app
```

## 文件地圖（`docs/`）

| 文件 | 內容 |
|------|------|
| `PROGRESS_LOG.md` | **接手先讀這裡** — 逐 session 進度、最新狀態、下一步 |
| `00_CONSTITUTION.md` | 專案憲法：願景 + 三大準則 + 定案決策 |
| `01_DECISIONS.md` | 架構決策記錄（ADR） |
| `02_PSYCHOLOGY_FOUNDATION.md` | 心理學/色彩學/UX 理論根基 |
| `03_DESIGN_SYSTEM.md` | 色彩系統、像素美術規範、Calm Technology UI 原則 |
| `04_ARCHITECTURE.md` | 技術架構：透明視窗、模擬/存檔、省電 |
| `05_ROADMAP.md` | 六階段路線圖（含測試紀律） |
| `06_PHASE1_SPEC.md` | Phase 1「會走路的空殼」建置規格 |
| `07_PHASE1_ACCEPTANCE.md` | Phase 1 人工驗收指南（GUI + 能耗） |
| `08_PHASE2_SPEC.md` | Phase 2「時間感與旅程」規格（推進/離線/存檔） |

## 現況

Phase 1（會走路的空殼）程式碼完成、`swift test` 全綠；待 GUI/能耗人工驗收。
Phase 2 規格就緒。詳見 `docs/PROGRESS_LOG.md`。
