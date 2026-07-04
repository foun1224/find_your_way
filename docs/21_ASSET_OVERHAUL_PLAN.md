# 美術大改版計畫 — Asset Overhaul（使用者重整素材，全面實作）

> 狀態：**Accepted（Fable 策展定案，2026-07-04）**。使用者重新整理 `design/` 全套地域+角色素材（皆 1536×1024、照 `20` 規格），要求全部整理與實作。本文件為策展地圖 + 分波執行計畫。

## 0. 素材盤點（design/）
### 地域（1536×1024，4 層+道具列，規格化）
| 檔 | biome | 備註 |
|---|---|---|
| grassland.png | 田園草原 | 取代現有 meadow（浮島/風車村/石屋市集，大升級） |
| kingdom.png | 中古王城 | 重生成標準尺寸（取代 Stage C 的 1774×887 版） |
| sea_city.png | 港口海城 | 沿用 |
| valley.png | 山谷 | 新 |
| village_2.png | 村莊 A | 新 |
| village_3.png | 村莊 B | 新 |
| sky_village.png | 天空村莊 | 新 |
| sky_city_magic.png | 天空魔法城 | 新；`_2` 為替代構圖、`_night` 為**夜間版** |

### 角色（去背深底，4 向：右/左/前/背）
| 檔 | 內容 | 用途 |
|---|---|---|
| main_role.png | 旅行者/遊俠（主角），4 向×3 姿勢 | **替換主角 hero** |
| resource_v2.png | 主角男/女（含待機/走路/跑步完整多幀）+ 道具 + 草原 bg | **女冒險者→旅伴**；走路幀備用；道具補充 |
| npc_1.png | 商人/農夫/孩童/樂手（4 向） | 通用居民 NPC |
| npc_2.png | 國王/王后/王子/公主/大臣/騎士/衛兵/商人 + 農夫/漁夫/麵包師/鐵匠/藥師/學者/樂師/旅人（4 向，共 16） | 分地域居民 NPC |

## 1. Fable 策展決定
- **主角 hero** = `main_role`（綠斗篷遊俠，與 NPC 同風格）。走路循環用其右向 3 姿勢（站/走/…）交替 → 比現行 2 幀大幅改善；若太僵，退用 `resource_v2` 男冒險者的完整走路幀。
- **旅伴 companion** = `resource_v2` 女冒險者（紅藍、完整走路幀），與男主角成「兩位旅人」對照、視覺可區分。（留白：仍不命名不給身世，ADR-004。）
- **天空城** = 用 `sky_city_magic`；`_night` 綁該地域夜間（與晝夜系統聯動，進階，可第 3 波再上）；`_2` 暫不用（或當 sky_village 的替代，先擱置）。
- **地面基準**：所有地域切圖對齊既有 `groundDisplayHeight=40`；角色/NPC 站頂線（沿用 Stage B/C 機制）。

## 2. 地域循環順序（無盡，旅程節奏由近人到奇幻）
`[grassland → village_2 → valley → kingdom → village_3 → sea_city → sky_village → sky_city_magic]`，`bandIndex mod 8`，regionLength 172800 不變。相鄰邊界 crossfade（`Region.blend` 通用，沿用）。

## 3. NPC → 地域 分配（社會臨場感 §2；純裝飾、確定性、零功利）
| 地域 | 居民 |
|---|---|
| grassland / village_2 / village_3 | 農夫、麵包師、孩童、商人、樂手 |
| kingdom | 國王、王后、公主、大臣、騎士、衛兵 |
| sea_city | 漁夫、商人、旅人 |
| valley | 藥師、學者、旅人 |
| sky_village / sky_city_magic | 學者、藥師、樂師（奇幻氛圍） |
- 泛用 `RegionNpcScatter`（把現行 `KingdomNpcScatter` 一般化為「每地域一組 NPC 型別+槽位」）。

## 4. 分波執行（每波：切圖→整合→測試→Fable 截圖驗收→提交）
- **第 1 波（先做，證明新美術管線）**：主角(main_role)+旅伴(女冒險者) 替換 + **真走路循環** + grassland 接為新草原（取代 meadow，region 序列先 grassland↔kingdom↔sea_city 沿用三地域，只換掉 meadow→grassland、hero/companion 換新）。→ 看到「新主角在新草原走路」。
- **第 2 波**：其餘地域切圖 + 接入（valley/village_2/village_3/sky_village/sky_city_magic），region 序列擴為 8 地域循環。
- **第 3 波**：`RegionNpcScatter` 一般化 + npc_1/npc_2 切圖 + 各地域居民分配。
- **第 4 波（進階，可選）**：sky_city 夜間版聯動晝夜；resource_v2 補充道具；主角男/女可選。

## 5. 切圖注意（承 Stage B/C 教訓）
- 每張 Read 校準層 y 帶（規格建議：遠 30–250 / 中 280–500 / 前 530–740 / 地面 760–875 / 道具 895–1015，但實際以 Read 掃描為準）。
- 細桿件（燈柱/旗桿/風車）用 `keep_largest_component_dilated` 防去斑咬斷。
- 角色 4 向×姿勢按標籤網格切；去背深底。
- 每層/每道具/每角色 Read 目視確認乾淨。

## 6. 不動
模擬/存檔/距離不變式/四季/晝夜/天氣/相遇卡/拖曳/平滑捲動/reduce-motion —— 這些是系統，美術只是換皮+加地域。既有測試不回歸。
