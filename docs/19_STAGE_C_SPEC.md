# Stage C 建置規格 — 王國素材更新 + 第三地域（港口海城）

> 狀態：**Accepted**（Fable 定案，2026-07-04）。承 `15_WORLD_STRUCTURE.md` / `18_STAGE_B_SPEC.md`。
> **觸發**：使用者更新 `design/kingdom.png`（更精緻、1774×887、**無角色列**）並新增 `design/sea_city.png`（1536×1024，港口海城，無角色列）。
> **目標**：(1) 用新 kingdom.png 重切王國環境（更精緻）；(2) 接 sea_city.png 為**第三地域**；(3) 保留王國市民 NPC（改用救回的舊角色素材）。跑通「三地域循環」。

## 0. 素材
| 檔 | 尺寸 | 用途 | 內容 |
|---|---|---|---|
| `design/kingdom.png`（新） | 1774×887 | 王國**環境**（重切） | 遠景城堡群+河+橋 / 中景城牆塔樓 / 前景旗幟石牆+燈柱+桶箱車花 / 地面平台石板 + 底部道具列 |
| `design/kingdom_characters.png`（救回） | 1536×1024 | 王國 **NPC 專用** | 舊版含角色列（士兵/衛兵/貴族）——NPC 切圖改指向此檔 |
| `design/sea_city.png`（新） | 1536×1024 | **第三地域「港口海城」** | 遠景海岸城+燈塔+帆船 / 中景港埠+大帆船 / 前景碼頭+大帆船+海港建築+旗幟 / 地面平台碼頭石 + 底部道具列 |

- 兩張新環境圖皆 **4 分層（遠/中/前/地面）+ 底部道具列**，格式同舊 Stage B，但**尺寸/佈局不同、座標須重新校準**（Read + 亮度掃描）。

## 1. 切圖（slice_assets.py 重構）
- **王國環境**：新 kingdom.png（1774×887）重新校準 → `regions/kingdom/bg/{far,mid,fore,ground}.png` + `regions/kingdom/props/*`（燈柱/旗幟/木箱/木桶/貨車/花箱/欄杆/石柱等，依 Read 實際）。
- **王國 NPC**：`KINGDOM_NPC_REGIONS` 改指向 `design/kingdom_characters.png`（1536×1024，舊座標可續用）→ `regions/kingdom/npc/{soldier,guard,noble}.png`。**NPC 功能保留**。
- **海城**：sea_city.png（1536×1024）校準 → `regions/sea_city/bg/{far,mid,fore,ground}.png` + `regions/sea_city/props/*`（燈柱/旗幟/木箱/木桶/繫纜柱/吊車/花箱麻袋/欄杆/石柱等）。海城**無角色列** → 無海城 NPC（本階段）。
- 沿用去背/despeckle（注意細桿件如燈柱/吊車/繫纜柱勿被去斑咬掉，比照 Stage B 教訓）/autocrop/panorama 淡出（mid 上緣）；細桿道具視需要 skip despeckle 或 keep_largest_component。
- **Read 目視每層/每道具確認乾淨**。

## 2. Region 系統擴充（三地域）
- `RegionType` 加 `.seaCity`（已有 meadow/kingdom）。
- **地域序列**：`[meadow, kingdom, seaCity]` 循環（`Region.at`：`bandIndex mod 3`）。regionLength 172800 不變（各≈4h；草原→王國→海城→草原…無盡）。
- `blend(atDistance:)` 已是「相鄰地域 crossfade」的通用純函式——確認三地域下每對相鄰邊界（meadow↔kingdom、kingdom↔seaCity、seaCity↔meadow）都正確。

## 3. 背景/地面/道具/NPC 隨地域（沿用 Stage B 機制）
- `ParallaxBackground.buildRegion` 依 RegionType 載該地域 bg/props/npc（王國有 NPC；海城、草原無）。
- 三地域各自 far/mid/(fore)/ground + 道具池；海城地面是碼頭石、王國石板、草原草土——隨地域/blend 切換，角色仍站 groundDisplayHeight 頂線（切圖縮放對齊基準）。
- `KingdomNpcScatter`（王國專用）不變；海城不放 NPC（`slots(for: .seaCity) = []`）。
- 四季 tint / 晝夜 / 天氣 / 相遇卡 overlay 照疊（海城的四季/晝夜也會套，合理）。

## 4. Debug / 驗收
- `FYW_DEBUG_REGION` 擴充：`meadow`/`kingdom`/`sea_city`（或 `seacity`）。
- 驗收：三地域各截圖（Fable）——王國更精緻、海城帆船碼頭、NPC 仍在王國、三地域邊界 blend 順。四季/晝夜/相遇卡仍運作。

## 5. TDD
- `RegionTests`：`at(distance:)` 三地域循環 + 邊界；`blend` 三對相鄰邊界正確、Blend Zone 外無 blend、確定性。
- `KingdomNpcScatterTests`：海城回傳空、王國照舊。
- 既有 239 測試不回歸。

## 6. 誠實風險
- 三張圖（新王國 / 舊角色 / 海城）**像素尺度/分層高度/地面基準**是否一致——切圖後 Read + 遊戲截圖確認接得起來、blend 不突兀、三地域地面高度對齊。新王國 1774×887 比例較扁，遠景/地面帶高度需重算。
- 舊角色素材（NPC）與新精緻王國環境的風格是否搭——Fable 截圖確認；若明顯違和，回報 Fable 決定（可暫關王國 NPC）。
