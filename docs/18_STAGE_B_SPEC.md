# Stage B 建置規格 — 第二個地域（中古王國首都）

> 狀態：**Accepted**（Fable 定案，2026-07-04）。承 `15_WORLD_STRUCTURE.md`（Region Band + Blend Zone）。
> **目標**：使用者提供的 `design/kingdom.png`（中古王國首都素材）接成**第二個地域**——旅人走過草原後**走進王國首都**，背景/地面/道具隨地域切換、地域間平滑轉場。跑通「一地域一地域擴充」流程。

## 0. 素材來源
`design/kingdom.png`（1536×1024，格式同 asset_sheet.png）：
- **背景分層**：遠景（城堡群+山+雲）、中景（藍頂塔樓密城）、前景（旗幟石牆+燈柱+樹+門）、**地面平台（灰石板）**。
- **角色**：王國士兵 / 衛兵隊長 / 貴族公主（各 4 向）——**Stage B 先不用**（NPC 屬 Stage B+ follow-up，見 §5）。
- **道具**：藍旗幟、市集攤、木箱、燈柱、貨車、盆花、長椅、噴泉、天使雕像、路標、樹。

## 1. 切圖（延續 slice_assets.py）
- Read kingdom.png 校準座標，切出：
  - `Resources/art/regions/kingdom/bg/{far,mid,fore,ground}.png`（四條 panorama；ground 是灰石板）。
  - `Resources/art/regions/kingdom/props/{banner,market_stall,fountain,statue,cart,bench,potted_flower,lamppost,tree,signpost,crate}.png`（去背；命名依實際）。
- **既有草原素材同步「地域化」**：把現有 `Resources/art/bg/*`、道具視為 `regions/meadow/*`（可保留舊路徑相容 + 加 meadow region 對映，實作者定最省做法；重點是「每個地域一組背景/地面/道具」）。
- 沿用既有去背/despeckle/autocrop/panorama 淡出（mid 上緣）流程。

## 2. 地域系統（Region）擴充
- `RegionType` 加 `.kingdom`（已有 meadow/riverlands/highlands/coastalReach 骨架；本階段只實裝 meadow + kingdom 兩個有美術的）。
- **地域序列**（`Region.at(distance:)`）：Stage B 用 `[meadow, kingdom]` 交替（regionLength 每段）。**`regionLength` 調到可達**：建議 **172800**（≈4h travel），讓旅人約 4h 後走進王國、再 4h 回草原…（無盡交替，直到未來加更多地域）。
- 純函式、確定性，可測。

## 3. 背景/地面/道具 隨地域切換 + Blend Zone 轉場（核心）
- `ParallaxBackground` / `GameScene` 依 `Region.at(displayedDistance)` 載入**該地域的** far/mid/(fore)/ground 貼圖與道具。
- **Blend Zone（`15` 漸變重疊帶）**：地域邊界前後一段（建議 blend 寬 ~15000 units）內，**同時渲染「當前地域」與「下一地域」的背景層，依 blend 進度 crossfade alpha**（當前淡出、下一淡入），達成平滑轉場（無 jolt，`03` §3.4）。Blend 進度為 distance 的純函式、可測（`func blend(atDistance:) -> (from:RegionType, to:RegionType, t:Double)`）。
- Blend Zone 外只渲染當前地域。
- **地面**：草原是草+土、王國是灰石板——地面層一併隨地域/blend 切換。角色仍站地面頂線（groundDisplayHeight 不變）。
- **前景層 (fore)**：王國有前景旗幟石牆層（草原沒有）；實作者處理「有 fore 的地域多一層、沒有的略過」。
- **道具 scatter**：依當前地域選該地域的道具池（草原道具 vs 王國道具），沿用 PropScatter/wrappedX。Blend Zone 內道具切換可簡化（硬切或跟著淡）。

## 4. Debug / 驗收
- 加 `FYW_DEBUG_REGION`（`meadow`/`kingdom`）強制地域，方便 Fable 截圖王國（不必走 4h）。比照既有 `FYW_DEBUG_*`。
- 驗收：`swift run`/`.app` + `FYW_DEBUG_REGION=kingdom` → 看到旅人走在王國首都（城堡群/藍頂塔/石牆旗幟/石板地 + 王國道具）；不指定則 meadow↔kingdom 隨里程轉場。四季 tint/晝夜/相遇卡仍疊加運作。

## 5. 範圍與後續
- **Stage B 做**：kingdom 地域的背景/地面/道具切換 + blend 轉場 + region 系統。
- **Stage B+ follow-up（不在本次）**：王國 NPC（士兵/衛兵/公主當城中行人，站立/走過，增「走進活城市」感）；kingdom 專屬相遇卡（城市/王國風味，加進 EncounterDeck 標 region）；晝夜在石城的燈光。
- **不動**：模擬/存檔/走路/微行為/拖曳/相遇卡系統/四季系統本體（只是背景多了地域維度）。

## 6. TDD
- `RegionTests` 擴充：`at(distance:)` meadow↔kingdom 交替正確、邊界；`blend(atDistance:)` 在邊界前後 t 從 0→1、Blend Zone 外無 blend、確定性。
- 既有 226 測試不回歸。切圖/背景/道具視覺人工（Fable 截圖）驗收。

## 7. 誠實風險
- kingdom.png 素材與 meadow 的**風格/像素密度/分層高度**是否一致（`15` 標的最大未知數）——切圖後 Read 目視 + 遊戲內截圖確認接得起來、blend 不突兀。若地面高度/像素尺度差太多，需在切圖縮放時對齊 groundDisplayHeight 基準。
