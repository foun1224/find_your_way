# CLAUDE.md — 專案接手指南

> 新 session 接手？先讀這裡。完整文檔在 `docs/`。

## 核心三準則（不可打破）

1. **心理學為本** — 任何機制/設計都要有心理學、色彩學、UX 理論依據
2. **先文字後實作** — 一切先寫進 `docs/`，確保任何 session 壞掉能無縫接手
3. **分層協作省 token** — 規劃/review 與實作分工

## 快速上手

```bash
swift build         # 建置
swift test          # 測試（純邏輯層，headless）
bash scripts/build_app.sh && open FindYourWay.app   # 打包並執行
```

## 專案狀態

**當前**: Phase 4c 完成（晝夜光影 + 天氣），4d 進行中（點角色微互動）  
**測試**: 151/151 綠 ✅  
**下一步**: 詳見 `docs/PROGRESS_LOG.md`

## 文檔速查

| 必讀 | 內容 |
|------|------|
| **PROGRESS_LOG.md** | 逐 session 進度、最新狀態、下一步 |
| **00_CONSTITUTION.md** | 項目憲法 + 願景 |
| **05_ROADMAP.md** | 六階段路線圖 |

| 深入 | 內容 |
|------|------|
| **01_DECISIONS.md** | 架構決策 (ADR) |
| **02_PSYCHOLOGY_FOUNDATION.md** | 心理學/色彩學/UX 基礎 |
| **03_DESIGN_SYSTEM.md** | 色彩系統 + 像素規範 |
| **04_ARCHITECTURE.md** | 技術架構 |

| Phase 規格 | 狀態 |
|-----------|------|
| **06_PHASE1_SPEC.md** + 07_ACCEPTANCE | 完成 + 驗收 ✅ |
| **08_PHASE2_SPEC.md** | 完成 + 驗收 ✅ |
| **09_PHASE3_SPEC.md** | 完成（驗收待補）⏳ |
| **12_PHASE4_SPEC.md** | 進行中（驗收待補）⏳ |
| **10_PHASE5_SPEC.md** | 規格就緒（驗收待補）⏳ |

## 關鍵環節

### 添加新功能
1. 先在 `docs/` 中寫規格（§ 樣式見 Phase spec）
2. 寫通過測試 (swift test 全綠)
3. 功能完成後寫 Acceptance 清單
4. 用戶人工驗收 (GUI + 能耗)

### 代碼風格
- Swift，SPM 專案（Package.swift）
- 無第三方依賴（pure stdlib + AppKit/SpriteKit）
- 模擬優先，UI 層單薄

### 環境變數（QA）
```bash
FYW_DEBUG_SECONDS_INTO_DAY=<秒數>   # 模擬時間
FYW_DEBUG_WEATHER=<晴/陰/雨>         # 強制天氣
```

## 方法論參考

詳見用戶記憶系統 `methodology_teaching.md`：
- 情境優先於通用方案
- 批量平行工具調用
- 上下文完整性檢查
- 最小化行動

## 聯繫

Sean Chen

---

*Last updated: 2026-07-04 by autonomous improvement loop*
