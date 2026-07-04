# 安裝與驗收指南（Install & Acceptance）

> Phase 5 程式碼已完成（126/126 綠、ad-hoc 簽章驗過）。以下步驟只有你能做，照做即可。
> 每步結果可記到 `PROGRESS_LOG.md`。

## A. 打包並安裝

```bash
cd /Users/sean.chen/Desktop/project/find_your_way
bash scripts/build_app.sh              # 產出 ad-hoc 簽章的 FindYourWay.app（預設 SIGN_MODE=adhoc）
mv FindYourWay.app /Applications/       # 移進 /Applications（自啟穩定的前提，見 R2）
```

## B. 首次開啟（ad-hoc 簽章的一次性步驟）

自己 build 的 app 通常無 quarantine，可直接雙擊。若被 Gatekeeper 擋（「無法打開，因為來自未識別的開發者」）：
- **右鍵點 FindYourWay.app → 打開 → 再按「打開」**（只需一次，之後正常雙擊）。
- 或：系統設定 → 隱私權與安全性 → 找到被擋提示 → 「仍要打開」。
- 若真的有 quarantine：`xattr -dr com.apple.quarantine /Applications/FindYourWay.app`

## C. 逐項驗收

| # | 檢查 | 期望 |
|---|------|------|
| 1 | 選單列 | 出現 🚶 圖示（無 Dock 圖示）|
| 2 | 點開選單 | 有**狀態卡片**（如「才剛啟程 / 第一章 · 啟程」）+ 偏好設定… + 顯示/隱藏 + 結束 |
| 3 | 桌寵 | 右下角小人 + 世界捲動照常 |
| 4 | 偏好設定… | 開得起來、能點 toggle、能關；關於顯示版本 0.5.0 |
| 5 | 降低動態 | 切換 toggle（目前無晝夜/粒子可見效果，Phase 4 才接上；先確認能存）|
| 6 | 顯示/隱藏 | 能把桌寵收起再叫回 |
| 7 | 結束 | 能正常關閉 |

## D. 開機自啟驗收（R1 — 本階段最高風險）

> **這是 ad-hoc 簽章唯一的真未知：能不能跟 SMAppService 自啟共存。只有重開機驗得了。**

1. 偏好設定 → 開「登入時啟動」。
   - 若跳「需要允許」→ 到系統設定 → 一般 → 登入項目，允許 FindYourWay。
2. **登出再登入（或重開機）** → 看 FindYourWay 是否自動出現在選單列。
3. 回報結果：
   - ✅ **自動啟動** → R1 通過，ad-hoc 自啟成立，Phase 5 完全驗收完成。
   - ❌ **沒自啟 / register 報錯** → 走 **fallback**：系統設定 → 一般 → 登入項目 → 按「＋」手動加入 `/Applications/FindYourWay.app`（一樣能自啟、免費、不需改簽章）。回報我，我更新文件記錄此為 ad-hoc 的已知限制。

## E. 常駐體感（可選，幾天）

裝好後日常掛著用幾天，順便累積 Phase 4 的手感：事件夠不夠、相遇時機、節奏、CPU/能耗是否維持 Low（活動監視器看）。這些真實體驗會讓 Phase 4（美術/質感）做得更準。

---

**回報重點**：C 各項是否正常、**D 的自啟是否成功（或走了 fallback）**。之後就剩 Phase 4（正式美術/晝夜/天氣/點角色微互動）——那需要先決定美術路線。
