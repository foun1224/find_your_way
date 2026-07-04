# 相遇卡擴充 — Encounter Cards（Fable curated · Accepted）

> 狀態：**已 curate 採納 (Accepted)** — Fable review 通過（2026-07-04）。52 張全數併入卡組。
>
> **Fable curate 決定**：語氣、留白、紅線全數符合，52 張全採納。
> - 「他」稱謂：理想上為留白最大化該去性別化（旅伴可投射為任何人，`14` §4.1），但為與既有 24 張母本一致、不因小失大，**本批先保留「他」**；記為**未來 polish**：一次性統一把所有 companion 卡（新+舊）去性別化（如省略主詞/「身邊的人」）。
> - 秋收/青梅/文化卡：意象各異、留白得宜，全保留。
> - `region` 傾向欄：Stage A 先忽略（EncounterCard 模型不含 region），Stage B+ 分地域時再取用。
>
> ---
>
> 原狀態：草擬待審 (Draft for Review)。承 `16_STAGE_A_SPEC.md` §2（資料模型/選卡）+ §3（既有 24 張＝語氣母本）。
> **目的**：為「無邊世界」擴充相遇卡池，讓長時間旅程不重樣。本份 **52 張全新卡**，與既有 24 張不重複意象、不重複 `09` §10 story beats（野花坡／溪邊歇腳／鳥停石上／雲影掠過／夜裡生火）。
>
> **語氣依據**（照既有 24 張）：短句、留白、視覺為主、溫暖、無驚嘆、無施壓、無情節動詞（不用「必須／危險／終於／趕」）；零功利（不提獎勵／進度／收集／數值）；無黑暗／威脅／急迫／孤單低潮；禁用「失落的／沉睡的／最後的」等暗示威脅修辭。繁體中文。
>
> **格式**：`id`（英文小寫底線）、`category`（flora/fauna/food/scenery/culture/companion）、`seasons`（spring/summer/autumn/winter 任意組合，`any` = 空 seasons，任何季節）、`logText`（留白一句）。`region` 為**可選傾向註記**（供 Fable 日後分地域用，不確定即 any；Stage A 全在草原/村莊 Region 0，多數標 any 或偏村鎮/田野）。
>
> **合併方式**：Fable review／curate 後，可直接把 `id / category / seasons / logText` 併入 `EncounterDeck.swift` 的 `all` 卡組，系統不改（`15` 內容/工程解耦）。`region` 欄 Stage A 可先忽略，Stage B+ 分地域時再取用。

---

## 1. 通用卡（任何季節，`seasons = any`）— 18 張

> companion 佔多數：情誼是核心，且這些「一起走的小事」即使獨行也成立、有旅伴時更自然（避免與 `09` §10 相遇機制衝突，皆非「相遇前/後」的節點式敘事，只是路上的普適小事）。

| id | category | seasons | region | logText |
|---|---|---|---|---|
| walk_shoulder_rest | companion | any | any | 走累了，你們肩並肩坐了一會兒，誰都沒開口。 |
| pebble_handed | companion | any | any | 他撿到一顆圓圓的石子，遞給你，你收進了口袋。 |
| wait_for_laces | companion | any | any | 你停下來繫鞋帶，他也停下，等你。 |
| last_ration_shared | companion | any | any | 分著吃最後一塊乾糧，誰也沒提剩得少。 |
| same_step_rhythm | companion | any | any | 你們並排走著，腳步不知不覺踩成了同一個節奏。 |
| tugged_sleeve | companion | any | any | 他先看見了什麼，沒說話，只是拉了拉你的袖子。 |
| bare_feet_airing | companion | any | any | 歇腳時，你們把靴子脫了，晾晾走了一天的腳。 |
| side_path | scenery | any | 偏村鎮 | 一條小路從大路岔開，通向不知道哪裡，你們看了它一眼。 |
| puddles_after_rain | scenery | any | any | 雨後路上幾個小水窪，各自映著一小塊天。 |
| big_tree_flat_stone | scenery | any | any | 路口一棵大樹，樹下一塊給人歇腳的平石。 |
| cat_on_wall | fauna | any | 偏村鎮 | 一隻貓從牆頭看你們經過，尾巴尖動了動。 |
| rustle_in_grass | fauna | any | any | 草叢裡有窸窣的聲音，你們放輕腳步，沒去驚動它。 |
| flower_in_wall_crack | flora | any | any | 石牆的縫裡鑽出一叢草，開著小小的花。 |
| dried_fruit_offered | food | any | 偏村鎮 | 有人在門口曬果乾，招手讓你們各嚐了一顆。 |
| sweet_roadside_water | food | any | any | 路邊的水很甜，你們把水囊都灌滿了。 |
| distant_singing | culture | any | any | 遠處有人在唱歌，聽不真切，只覺得日子很慢。 |
| worn_doorstep | culture | any | 偏村鎮 | 路過一戶人家，門前的石階被踩得凹了下去。 |
| laundry_in_wind | culture | any | 偏村鎮 | 牆邊晾著誰家的衣服，在風裡輕輕地晃。 |

---

## 2. 春 Spring — 9 張

| id | category | seasons | region | logText |
|---|---|---|---|---|
| new_grass_ridge | flora | spring | 偏田野 | 田埂上的野草冒了新綠，軟軟的一層。 |
| petals_on_shoulder | flora | spring | any | 一樹花開得滿，風一吹落了幾瓣在你們肩上。 |
| swallows_over_paddy | fauna | spring | 偏水岸 | 一群燕子低低地掠過水田。 |
| frogs_at_dusk | fauna | spring | 偏水岸 | 田裡有蛙聲，此起彼落，像在數著什麼。 |
| green_plums | food | spring | 偏村鎮 | 路邊有人賣剛摘的青梅，酸得你們瞇了眼。 |
| snowmelt_field | scenery | spring | 偏田野 | 融雪的田裡積了水，映著剛回暖的天。 |
| willow_buds | scenery | spring | 偏水岸 | 柳條垂到水面，剛抽出嫩黃的芽。 |
| sowing_seeds | culture | spring | 偏田野 | 村口有人在翻土播種，彎著腰，不慌不忙。 |
| flower_tucked_on_pack | companion | spring | any | 他摘了朵路邊的花，別在你的包上，什麼也沒說。 |

---

## 3. 夏 Summer — 9 張

| id | category | seasons | region | logText |
|---|---|---|---|---|
| heavy_green_shade | flora | summer | 偏森林 | 路兩旁的樹綠得發沉，把太陽篩成一地碎光。 |
| sunflowers_facing | flora | summer | 偏田野 | 向日葵整片朝著一個方向，你們也跟著看過去。 |
| dragonfly_on_tip | fauna | summer | 偏水岸 | 一隻蜻蜓停在草尖上，翅膀是透明的。 |
| fireflies | fauna | summer | any | 螢火蟲在草叢裡亮了一下，又暗了。 |
| watermelon_shared | food | summer | 偏村鎮 | 樹下有人切開一顆西瓜，分了你們一角。 |
| afternoon_shower | scenery | summer | any | 午後起了一陣雷雨，你們躲在屋簷下，看它下完。 |
| river_haze_evening | scenery | summer | 偏水岸 | 傍晚的河面浮著暑氣，蜻蜓貼著水飛。 |
| evening_fan | culture | summer | 偏村鎮 | 傍晚有人在門口搖著扇子乘涼，點頭跟你們打招呼。 |
| too_hot_to_move | companion | summer | any | 太熱了，你們找了棵樹，什麼也不做地坐了很久。 |

---

## 4. 秋 Autumn — 8 張

| id | category | seasons | region | logText |
|---|---|---|---|---|
| silver_grass | flora | autumn | 偏田野 | 路邊的芒草白了頭，風一過就伏成一片。 |
| squirrel_with_nut | fauna | autumn | 偏森林 | 松鼠抱著顆果子，見了你們就竄上樹。 |
| slower_cricket | fauna | autumn | any | 一隻蟋蟀在牆角叫，聲音比夏天慢了些。 |
| grain_drying | food | autumn | 偏村鎮 | 曬場上鋪滿了金黃的穀子，香味乾乾的。 |
| ripe_persimmons | scenery | autumn | 偏村鎮 | 柿子紅透了掛在枝上，葉子快落光了。 |
| orange_dusk_clouds | scenery | autumn | any | 起風的傍晚，天邊的雲被染成了橘紅。 |
| corn_under_eaves | culture | autumn | 偏村鎮 | 有人把玉米一串串地掛上了屋簷。 |
| leaf_kept | companion | autumn | any | 他撿起一片好看的葉子，夾進了行囊裡。 |

---

## 5. 冬 Winter — 8 張

> 守 `16` §1.2：冬是「安靜乾淨的白」，非蕭瑟死寂。語氣皆暖、皆靜。

| id | category | seasons | region | logText |
|---|---|---|---|---|
| snow_on_rooftops | scenery | winter | 偏村鎮 | 屋頂積了薄薄一層白，煙囪冒著直直的煙。 |
| two_lines_of_footprints | scenery | winter | 偏田野 | 田野一片安靜的白，只有你們兩行腳印。 |
| winter_plum | flora | winter | any | 牆角一株梅開了，冷冷的，很香。 |
| sparrows_puffed | fauna | winter | any | 幾隻麻雀擠在光禿的枝上，蓬成小小的球。 |
| cat_in_winter_sun | fauna | winter | 偏村鎮 | 一隻貓縮在誰家的窗台上，曬那一點冬天的太陽。 |
| steaming_buns | food | winter | 偏村鎮 | 路過的攤子蒸著白胖的包子，熱氣糊了半條街。 |
| new_red_paper | culture | winter | 偏村鎮 | 家家門上換了新的紅紙，路過都覺得暖。 |
| scarf_pulled_up | companion | winter | any | 你們哈著白氣走，他把圍巾往上拉了拉。 |

---

## 6. 回報 Fable

**總張數**：**52 張**（全新，與既有 24 張及 `09` §10 story beats 皆不重複意象）。

**季節分布**：any 18 · spring 9 · summer 9 · autumn 8 · winter 8 → 四季各 ≥8 張專屬，達標。

**分類分布**（52）：companion 11 · scenery 11 · fauna 10 · culture 7 · flora 7 · food 6。companion 依要求最多，且全寫成「即使獨行也成立、有旅伴更自然」的普適小事，未觸及相遇機制的節點敘事。

**region 傾向**：多數 any 或偏村鎮/田野（貼合 Stage A 草原/村莊 Region 0）；另散標偏水岸/偏森林，供 Stage B+ 分地域取用。Stage A 可先忽略此欄。

**我自己覺得最好的幾張**：
- `two_lines_of_footprints`（冬）「田野一片安靜的白，只有你們兩行腳印。」——情誼＋冬之靜，一句就有兩個人。
- `tugged_sleeve`（any）「他先看見了什麼，沒說話，只是拉了拉你的袖子。」——沉默默契，最貼 `14` §4 的留白情誼。
- `too_hot_to_move`（夏）「太熱了，你們找了棵樹，什麼也不做地坐了很久。」——低喚醒、零功利、暖。
- `orange_dusk_clouds`（秋）「起風的傍晚，天邊的雲被染成了橘紅。」——純 soft fascination 自然一瞥。
- `flower_tucked_on_pack`（春）「他摘了朵路邊的花，別在你的包上，什麼也沒說。」——回應性微行為的溫柔。

**需 Fable 特別留意處（誠實標註）**：
1. **companion 卡的「他」稱謂**：既有母本 `companion_hums` 等用「他」，本份沿用。若 Fable 想更留白（旅伴不定性別），可考慮改為「旅伴/身邊的人」或省略主詞——留給 Fable 定調。
2. **意象邊界處**：`leaf_kept`（撿葉）與既有 `falling_leaves`（落葉）、`grain_drying`（曬穀）與既有 `ripe_field`（麥浪）／`roasted_chestnut` 皆屬秋收語彙，我已讓場景/動作各異，但若 Fable 覺得秋卡氣味太近，可 curate 掉一兩張（寧缺勿濫）。
3. **`green_plums`「酸得瞇了眼」**：是唯一帶輕微身體感受的味覺卡，語氣仍暖不施壓；若嫌偏「情節」可否決。
4. **文化卡刻意避開國名/百科**（`15` §4）：紅紙/玉米/扇子/曬衣皆為「風味印象的一瞥」，未寫是何節、何族、何地，留白給投射。若日後分地域，這些偏東亞農村風味卡建議歸入相應 RegionType，避免與未來異域地貌撞味。
5. 全份自查：無威脅/急迫/FOMO/功利/孤單低潮，無驚嘆號，無禁用修辭。冬卡守「安靜的白」。
