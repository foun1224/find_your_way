# Phase 4 建置規格 — 陪伴的質感（Companionship Polish）

> 狀態：**Accepted**（Fable 定案，2026-07-04）。依準則二「先文字後實作」。
> **目標**：把佔位色塊 → 正式像素美術（使用者提供的素材），並加晝夜光影 / 天氣 / 點角色微互動，讓畫面從「能動」變「療癒、耐看、會呼吸」。
> **前置**：Phase 1–3+5 完成（126 測試綠、可安裝）。核心邏輯不動，本階段主要是**呈現層 + 資源整合**。

## 0. 美術來源與 ADR-009 確認
- **美術來源**：使用者用 ChatGPT 產出的像素素材表 `design/assets/asset_sheet.png`（1536×1024）。內容：兩角色（金髮藍衫+木杖主角 / 藍衫紅披風旅伴）各 4 向走路循環；道具（箱/桶/路標/提燈/柵欄/乾草堆/乾草車/花/石/灌木/草）；分層背景（遠景山+城堡 / 中景村莊教堂 / 近景道具 / 地面平台）。
- **ADR-009 確認**：素材為 **2D 橫向捲軸分層 + 向右/向左走路** → 與既有側面橫向捲軸架構完全一致，**視角不變**（角色固定左側、朝右、世界左捲；用「向右」走路循環）。

## 1. 資源切圖管線（無 PIL → 純標準庫）
- 建 `scripts/slice_assets.py`（純 Python PNG 讀寫）：解碼 PNG → RGBA 陣列 → 處理 → 編碼。功能：
  1. **裁切 (crop)**：依設定的區域座標切出子圖。
  2. **去背 (chroma-key)**：近黑底（亮度 < 門檻）像素轉透明；邊緣柔化避免鋸齒黑邊。
  3. **自動裁邊 (autocrop)**：去背後裁到非透明的 bounding box。
  4. **列切格 (segment row)**：一排走路 frame 依「透明間隙」自動切成等數個 frame（角色列）。
- **切圖設定表**（region 座標）：由施工者 Read `asset_sheet.png` 校準各區 y/x 範圍（角色 4 排×N格、道具、背景 4 條）。座標寫進設定、可微調。
- 產出到 `Resources/art/`：`char_hero/{right,left,front,back}_0..n.png`、`char_companion/...`、`props/{crate,barrel,sign,lantern,fence,haystack,haycart,flower,rock,bush,grass}.png`、`bg/{far,mid,near,ground}.png`。
- **原則**：`asset_sheet.png` 是唯一真相來源；切圖是可重跑的腳本（不手改產出 PNG）。像素貼圖一律 `filteringMode = .nearest`。

## 2. 整合到 SpriteKit（呈現層，取代佔位）
- **背景分層 (ParallaxBackground 改寫)**：`far/mid/ground` 為整條 panorama、依 `WorldScroll.scrollOffset` 用各自 layerFactor 捲動並水平 tile 循環（far 慢、ground 快）；`near` 層放道具剪影較快捲。取代現有純色帶。
- **角色動畫 (CharacterNode 改寫)**：用 `char_hero/right_*` 走路循環（`SKAction` texture animation，~6–8fps 對應 `03` §2.3），固定左側 walk-in-place。移除色塊。
- **旅伴 (CompanionNode 改寫)**：相遇後用 `char_companion/right_*` 同行，構圖主從（略小/略後，`09` §3.3）。
- **道具/地標**：`props/*` 作為近景 / 地標視覺（如 haycart、church 用中景既有、signpost 當地標標記）。地標名 toast 保留。
- **驗收**：`swift run` 看到真美術的旅人走在有村莊/山/城堡的分層世界，不再是色塊。

## 3. 晝夜光影（`03` §1.4）
- 全域色調 overlay（一層覆蓋全畫面的 `SKSpriteNode`，blend）：依真實時間映射色溫 —— 黎明暖 / 白日中性 / 黃金時刻暖峰 / 夜月光藍（不純黑、留暖光點）。分鐘級平滑漸變。
- 受 `gameScene.motionEnabled`（reduce motion）控制：關閉時停用漸變、維持白日中性。

## 4. 天氣（`03` §1.4，一律柔化不施壓）
- 晴 / 陰（降飽和抬暗部）/ 雨（冷偏藍 + 緩慢粒子）。低頻、確定性或極輕隨機（屬 Phase 3 §2.2 B 類氛圍、不入狀態、錯過無損）。受 reduce motion 控制（關粒子）。

## 5. 點角色微互動（ADR-006 嚴格零功利）
- 動態點擊穿透（`04` §2.5 策略 B）：游標在角色不透明像素上 → 視窗吃點擊；點角色 → 暖心回應（看向你/揮手/短暫開心），**純情感、不給資源/不加速/不解鎖**。游標移到角色上變手型（signifier）。
- **風險 R3**（`04`）：全域滑鼠監聽 vs 沙盒——本專案 ad-hoc 自用非沙盒，可行；仍實測。

## 6. 施工分期（先大視覺升級，逐步可驗）
- **4a**：切圖管線 + 背景分層 + 主角走路動畫（最大升級，先做）。
- **4b**：旅伴 sprite + 道具/地標視覺。
- **4c**：晝夜光影 + 天氣。
- **4d**：點角色微互動。
- 每期 `swift run` 人工看、Fable 截圖驗收；`swift test` 既有不回歸（純美術/呈現改動測試少，可測的切圖幾何/色調映射抽純函式）。

## 7. 風險
- AI 素材切圖：走路 frame 若有輕微不連貫 → 可挑穩定 frame 子集。解析度 1536×1024（角色 frame ~85px）縮到小視窗 OK。
- 去背門檻需視 asset 調（近黑底但角色有暗部靴/描邊，門檻要保守 + 只去「連通到邊界的背景」以免挖到角色暗部）。
- 晝夜/天氣 overlay 不可壓過像素美術的辨識度（`03` 非侵入、低喚醒）。

> 施工依 §6 分期委派；4a 先行。
