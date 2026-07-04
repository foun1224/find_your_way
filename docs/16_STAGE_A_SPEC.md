# Stage A 建置規格 — 無邊世界 MVP（四季 + 相遇卡）

> 狀態：**Accepted**（Fable 定案 + authored，2026-07-04）。實作依據。
> 承 `15_WORLD_STRUCTURE.md`。**目標**：在**現有草原素材**上，用「**四季色調循環 + 大量相遇卡**」兌現大半「永遠變化」的感覺——不需任何新美術。
> **守則**：無終幕、無黑暗、無壓力；無邊≠無盡刷（不做完成度/圖鑑/迷霧/周目/限時）；留白、低喚醒、零功利（ADR-006）；確定性（絕不牆鐘擲骰）。

## 0. Stage A 範圍
- **做**：(1) 季節系統（`Season = f(distance)` + 季節色調 overlay）；(2) 相遇卡系統（authored 卡組 + 確定性選卡 + 旅程日誌 toast，線上 + 離線回歸）；(3) Region skeleton 薄骨架（純函式，為 Stage B 美術預留，本階段不張揚）。
- **不做**（後續 Stage）：新地域美術、聚落/國家視覺、圖鑑（永不做）、對話。

## 1. 季節系統（Season）
### 1.1 純函式（放 FindYourWayCore，不 import SpriteKit，可測）
- `enum Season { spring, summer, autumn, winter }`
- `seasonLength: Double`（每季里程長，provisional = **86400**，≈2h travel @P1；一整年 = 4×= 345600 ≈ 8h）。相對 P1，可調。
- `Season.at(distance:) -> Season`：`index = floor(distance / seasonLength) mod 4`，`0→spring,1→summer,2→autumn,3→winter`（distance 0 從春天啟程）。
- `Season.tint(atDistance:) -> Palette.RGBA`：**相鄰季節在交界附近線性插值**（blend zone，同 `DayNightCycle` 範式，慢、無跳變）。回傳「不透明色 + overlay alpha」（GameScene 用不透明 color + node.alpha，**沿用 4c 的 alpha 教訓**：color 不帶自身 alpha 以免相乘變透明）。
- **確定性、只看 distance**：離線可重現、無牆鐘。

### 1.2 季節色調（authored，克制、可辨識、低喚醒 §6）
| 季 | 色 HEX | overlay alpha | 味道 |
|---|---|---|---|
| 春 Spring | `#9FD68A` 嫩綠 | 0.14 | 清新、剛醒、萬物初生 |
| 夏 Summer | `#F2CE73` 暖金 | 0.10 | 飽滿、日長、慵懶溫暖（tint 最淡，近基準） |
| 秋 Autumn | `#E0A257` 琥珀 | 0.18 | 溫暖、金黃、成熟安詳 |
| 冬 Winter | `#BFD2E6` 冷藍白 | 0.20 | 清冷、乾淨、靜（不蕭瑟——是「安靜的白」非「死寂」） |

- alpha 克制到「讀得出季節但角色/世界仍清楚」。與晝夜 tint、天氣 overlay **各自一層、疊加**（三條慢軸交織：晝夜綁現實時間 × 季節綁里程 × 天氣）。
- 受 `motionEnabled`（reduce motion）控制：關閉時季節維持中性（不漸變）。
- 冬天不製造「蕭瑟/死亡」壓力（守療癒）：是「安靜乾淨的白」，日誌語氣亦然。

## 2. 相遇卡系統（Encounter Card）
### 2.1 資料模型（純資料）
```
struct EncounterCard {
  let id: String
  let category: Category   // flora/fauna/food/scenery/culture/companion
  let seasons: [Season]    // 空 = 任何季節；否則只在這些季節出現
  let logText: String      // 留白日誌一句（Fable authored voice）
}
enum Category { flora, fauna, food, scenery, culture, companion }
```
### 2.2 選卡（純函式，確定性，`13`/`09` §2 範式）
- 沿里程軸每 **`cardSpacing`**（provisional = **28800**，≈40min travel）一個「卡槽」。`slotIndex = floor(distance / cardSpacing)`。
- `EncounterDeck.card(atSlot: Int, season: Season) -> EncounterCard?`：先以 `season` 過濾可出現的卡（含 seasons 為空的通用卡），再用 **`hash(worldSeed, slotIndex) % filtered.count`** 選一張（`worldSeed` 為固定編譯常數，**不依賴牆鐘**）。避免與「上一槽同 id」緊鄰重複（若撞則取次順位）。
- **相遇卡是 B 類氛圍（`15`）**：**不入 `GameState`、不持久化、不收集**（守紅線：無圖鑑/無完成度）。純確定性 → 離線回歸能重算出「你不在時路過的幾張卡」來顯示，但不儲存。
- **與既有 §10 story beats 並存**：既有地標/事件/相遇/章節（persistent story beats）不動、照常；相遇卡是疊加在其上的**無盡氛圍變化層**。

### 2.3 呈現
- **線上**：`GameScene` 每跨過一個卡槽 → 顯示該卡 logText 為旅程日誌 toast（沿用既有 toast 機制、錯開時間、克制）。
- **離線回歸**：settle 後，把離線里程區間內跨過的卡槽的卡，挑最後 1–2 張以「你不在時，路過了…」呈現（不洗版；不逐一列出、不做「錯過清單」）。
- **零功利**：卡只給情感/敘事，不給任何進度/資源（ADR-006）。

### 2.3b Region skeleton（薄，Stage B 用）
- `Region.at(distance:) -> RegionType`（純函式，`bandIndex=floor(distance/regionLength)` + 確定性序列）。Stage A 只需存在 + 可測，**不做視覺差異、不張揚 region 名**（現階段各地域仍是草原視覺，張揚會顯空）。為 Stage B 美術預留掛點。`regionLength` provisional = 345600（≈8h/地域，先設一個大值讓 Stage A 幾乎都在第一地域）。

## 3. 相遇卡組（Fable authored · 起手 deck，可隨時擴充）
> 語氣＝`09` §10 母本：短句、留白、視覺、無驚嘆、無施壓、溫暖。空 seasons = 任何季節。

### 3.1 通用（任何季節）
- `stone_on_path` / scenery / 「路上有塊被很多人踩過、踩得發亮的石頭。」
- `distant_bell` / culture / 「遠處傳來一下鐘聲，很輕，像誰在報時，又像沒有。」
- `resting_traveler` / culture / 「一個人靠在樹下打盹，你放輕了腳步。」
- `wind_direction` / scenery / 「風換了個方向。你也跟著側了側身。」
- `companion_hums` / companion / 「他哼了一小段調子，你沒聽過，但很好聽。」
- `share_water` / companion / 「你們分了同一壺水。剩下的路好像短了一點。」
- `old_milestone` / scenery / 「路邊一塊舊里程碑，字被磨平了，方向還在。」
- `kind_dog` / fauna / 「一隻狗跟了你們一小段，到牠家門口就停下了。」

### 3.2 春 Spring
- `first_buds` / flora / 「枝頭冒出第一點綠，小心翼翼的樣子。」
- `spring_stream` / scenery / 「雪水下山，溪聲比昨天響。」
- `nesting_birds` / fauna / 「兩隻鳥在銜草築巢，忙得沒空理你。」
- `warm_bread` / food / 「路過的村子在烤麵包，香味把你留了半刻。」

### 3.3 夏 Summer
- `cicada_noon` / fauna / 「午後的蟬聲很滿，滿到讓人想找棵樹坐下。」
- `ripe_field` / flora / 「一整片麥子熟了，風一過就是一片金色的浪。」
- `cold_well` / food / 「井水冰涼，有人遞了你一瓢。」
- `long_shadow_evening` / scenery / 「夏天的黃昏很長，影子拉得老遠。」

### 3.4 秋 Autumn
- `falling_leaves` / flora / 「葉子開始落了，踩上去有聲音。」
- `harvest_cart` / culture / 「一車剛收的果子經過，紅得發亮。」
- `roasted_chestnut` / food / 「街角在炒栗子，你買了一小袋，暖手。」
- `migrating_geese` / fauna / 「一行雁往南去，你抬頭看了很久。」

### 3.5 冬 Winter
- `first_snow` / scenery / 「今年的第一場雪，很輕，落在肩上就化了。」
- `frozen_pond` / scenery / 「池面結了薄冰，映著乾淨的天。」
- `warm_soup` / food / 「有人請你喝了碗熱湯，說了句你聽不懂但很暖的話。」
- `fox_in_snow` / fauna / 「一隻狐狸踩過雪地，回頭看了你一眼，走了。」

> 共 24 張起手。**擴充＝加卡即可，系統不改**（`15` 的內容/工程解耦紅利）。

## 4. 檔案 / 施工（延續既有 SPM 分層）
- 新增 `FindYourWayCore/World/Season.swift`（enum + at + tint 純函式）、`EncounterCard.swift`（模型 + Category）、`EncounterDeck.swift`（`all` 卡組 + `card(atSlot:season:)` 選卡純函式）、`Region.swift`（薄骨架）。
- `GameScene`：加 `seasonOverlay`（同 4c overlay 範式，不透明 color + node.alpha，疊在晝夜/天氣之外一層）；每幀依 `Season.tint(atDistance:displayedDistance)` 更新；每跨卡槽顯示相遇卡 toast；離線回歸摘要卡。受 motionEnabled 控制。
- **不動**：既有 story beats（09 §10 事件/地標/相遇/章節）、走路 2 拍、微行為、distance 不變式、背景平鋪。

## 5. TDD（純邏輯）
- `SeasonTests`：`at(distance:)` 四季邊界/循環/負值；`tint` 交界插值連續無跳變、季節中點色正確。
- `EncounterDeckTests`：`card(atSlot:season:)` 確定性（同輸入同卡）、季節過濾正確（冬不出夏卡）、不緊鄰重複、**不依賴牆鐘**（不同「現實時間」同 slot 同季得同卡）、空過濾防呆。
- `RegionTests`：`at(distance:)` 確定性、bandIndex 邊界。
- 既有 181 測試不回歸。

## 6. 驗收
- `swift test` 全綠（181 + 新）。`swift run` / `.app`：掛著看，**季節色調隨里程慢慢變**（春綠→夏金→秋琥珀→冬藍白）、**旅程日誌不時冒出多樣的相遇卡**（花鳥食物風土人文）。Fable 截圖驗收季節 tint；相遇卡文字節奏 live 感受。
- 無終幕、無壓力、無收集——只是一條越走越有風景的無邊路。
