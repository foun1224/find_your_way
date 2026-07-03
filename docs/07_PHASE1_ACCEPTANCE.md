# Phase 1 人工驗收指南（Human Acceptance Runbook）

> 程式碼與測試部分已由 Fable review 通過（`swift test` 19/19 綠、座標 bug 已修）。
> 以下項目**只有在真實畫面上才能確認**，需使用者親自跑一次。照做即可，每項打勾記到 `PROGRESS_LOG.md`。

---

## A. 啟動 App

兩種方式擇一（在專案根目錄 `/Users/sean.chen/Desktop/project/find_your_way`）：

```bash
# 方式一：開發模式直接跑（Ctrl-C 結束）
swift run

# 方式二：跑打包好的 .app（雙擊或指令）
bash scripts/build_app.sh && open FindYourWay.app
# 結束：pkill -f FindYourWay
```

> App 是 agent 型（無 Dock 圖示），Phase 1 也還沒有選單列，所以**結束要用 Ctrl-C 或 `pkill -f FindYourWay`**。

---

## B. 逐項驗收（對照 `06_PHASE1_SPEC` §0）

| # | 檢查項 | 期望 | 通過? |
|---|--------|------|:---:|
| 1 | **位置** | 桌面**右下角**出現一小塊畫面（約 320×180，距右下各 24pt） | ☐ |
| 2 | **透明** | 只看到「上藍下綠色帶 + 陶紅方塊」，**看不到視窗邊框/標題列/陰影方框**，方塊周圍是你的桌布透出來（非黑底/白底） | ☐ |
| 3 | **小人走動** | 陶紅 32×32 方塊在色帶上**水平來回走**，速度悠閒（約 2.5 秒走到邊），有輕微上下步伐感 | ☐ |
| 4 | **在草地上** | 方塊站在下半綠色帶區、完整在畫面內（不會半個跑出去） | ☐ |
| 5 | **點擊穿透** | 點在這塊畫面（含方塊）任何地方，都**穿透到底下的桌面/App**，不擋操作、不接管點擊 | ☐ |
| 6 | **不搶焦點** | 啟動當下，你正在用的 App **不會被踢到背景**、游標焦點不跳走 | ☐ |
| 7 | **置頂** | 切換到別的視窗時，這塊小畫面**仍浮在最上層** | ☐ |
| 8 | **跨 Spaces (R4)** | 用觸控板三指左右切 Space / 進全螢幕 App，小畫面**跟著出現**、無明顯閃爍或位移異常 | ☐ |
| 9 | **層級禮貌 (R7)** | 小畫面**不會蓋到系統選單列/Dock/通知**等不該蓋的地方 | ☐ |

> 任一項不如預期，記下現象到 `PROGRESS_LOG.md`，回報 Fable 安排修正。

---

## C. R1 能耗基準（核心賣點，必做一次）

「省電」是本專案選原生的核心理由（ADR-001）。這是第一次量測，建立基準。

**方式一：Xcode Energy Impact（最直覺）**
1. 用 Xcode 開專案（`open Package.swift` 由 Xcode 開），Run。
2. 掛機 **5–10 分鐘**不動，看 Debug navigator 的 **Energy Impact**。
3. 記錄評級（目標：**Low**）。

**方式二：`powermetrics`（指令，需 sudo）**
```bash
# 先啟動 App，找到 PID
pgrep -f FindYourWay
# 量測 CPU / 能耗（取樣 5 次、每次 2 秒）
sudo powermetrics --samplers cpu_power -n 5 -i 2000 | grep -iE "package power|CPU"
# 或用 top 看 CPU%
top -pid $(pgrep -f FindYourWay) -l 5 -stats pid,cpu,mem
```

**對照實驗（驗證 R1 假設）**：
- 目前 `preferredFramesPerSecond=30` 持續 render。
- 記錄「持續 render」的 CPU%/能耗，作為基準。
- **判讀**：若掛機閒置時 CPU 仍有明顯佔用（非個位數%以下）或能耗非 Low → 代表透明合成/持續 render 有底噪，**Phase 2 需優先做「靜止即 `isPaused=true` 停到底」的省電策略**（`04` §6、`06` §5）。

**把結果記到 `PROGRESS_LOG.md`**：平均 CPU%、常駐 RAM、能耗評級、以及是否需要 Phase 2 優先處理省電。

---

## D. 驗收通過後

- 在 `PROGRESS_LOG.md` 記錄 B/C 結果 → 更新 `05_ROADMAP.md` 勾選 Phase 1。
- Fable 依 R1 數據撰寫 **Phase 2 規格**（時間推進 / 離線結算 / 存檔 + 省電策略，TDD 主場）。
- （可選）此時是第一個適合 **git commit** 的檢查點：「Phase 1: walking skeleton」。需你授權才提交。
