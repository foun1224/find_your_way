# 進度日誌 (Progress Log)

> **接手新 session 請先讀這裡。** 每個工作階段結束前追加一則。
> 格式：日期 / 誰做的 / 做了什麼 / 決定了什麼 / 下一步。最新在最上面。

---

## 2026-07-05 — Session 2 — 地域大擴充：新提示詞 6 地域 → 15 地域循環

承新美術流程（洋紅去背 + 真多層視差 layered），使用者陸續用 `docs/20` §8A 新提示詞（磁紅 mid/fore、只有遠景含天空且需可無縫循環）重生一批地域，分享連結逐張下載驗證整合。每張皆「機械整合委派 Sonnet subagent 照前一個 layered 地域模板做 → 我親自雙鏡截圖驗收（`FYW_DEBUG_REGION` + crop.py 全螢幕裁切）」。

**本 session 新增 6 個 layered 地域（皆零洋紅、雙鏡通過、各自 commit）**：
- hotspring_village 溫泉村（日式暖夕陽）、snow_mountain 雪山石門（歐系中世紀奇幻，14_STORYLINE 地標）、mountain_palace 仙俠山宮（東方奇幻天空仙境）、magic_city 浮空魔法都城（高奇幻空靈）、holy_city 神聖城市（聖光聖域）、steampunk_city 蒸氣龐克飛船城（暖黃銅工業）、future_city 賽博龐克霓虹夜城（喚醒度最高）。

**調性決策**：使用者先選「維持 A（中世紀奇幻一致）」跳過 steampunk/future，隨後改口「工業龐克可以」「賽博也要」→ 最終 **genre 全開**。排序讓兩座熱鬧科技城（steampunk→future）相鄰、後段空靈聖域（mountainPalace→magicCity→holyCity→skyCity）保持 calm crescendo 收尾。

**15 地域循環**：`meadowOrigin → village2 → valley → kingdom → village3 → hotspringVillage → harbor → snowMountain → steampunkCity → futureCity → skyVillage → mountainPalace → magicCity → holyCity → skyCity ↺`

**順帶修 bug**：`GameScene.debugRegionOverride()` switch 漏了新地域 → `FYW_DEBUG_REGION` 落回預設地域（截圖驗收才抓到）。已補齊全部新地域 case。

**技術注記**：future_city 美術調色盤本身含洋紅粉紫霓虹，靠 `chroma_key_flood_color` 從邊緣 flood-fill 只去背景相連洋紅、不吃內部霓虹（threshold=60 保留）；逐張黑白合成目視確認招牌無破洞。

**體檢＋淘汰（使用者走一輪 montage 後）**：15 地域逐張全解析度雙鏡複檢 → 淘汰 **village_2**（天空太空/中前景稀疏）、**valley**（灰褪色/低對比）兩張舊格式弱圖。移除 enum/cycle/assetFolder/debugOverride/scatter slots/測試（保留 design png 與素材夾、slice_assets.py 留置）。其餘 5 舊格式（grassland/kingdom/village3/skyVillage/skyCity）品質站得住續留。**→ 13 地域循環**：`meadowOrigin→kingdom→village3→hotspringVillage→harbor→snowMountain→steampunkCity→futureCity→skyVillage→mountainPalace→magicCity→holyCity→skyCity`。

**標籤補丁痕根治**：新增 `patch_label_box_sky`（方框四邊反距離加權內插填洞，天空漸層平滑重建）取代單列重複，只套 far 層（8 layered + kingdom/grassland/new_region 泛用切法的 far 分支），mid/fore 不動（去背後透明不可見 + 避免內插污染洋紅去背）。天空區標籤方塊隱形、village_3 森林區塊痕融成樹冠。

**主角升級**：`design/main_role_walk_v2.png`（8 走路 + 4 待機）取代舊 3 姿勢/舊 walk。`slice_main_role_walk_v2` 深藍底去背 + **一致腳基準**（全幀最低不透明列取最小值當共用著地線、8 幀同高 bottomPad=0、只 autocrop 左右上 → 腳貼地零抖動）+ 去陰影。走路覆蓋 char_hero/right_0..7（drop-in 無 Swift 改）；待機 char_hero/idle_0..3（CharacterNode idle 接線待後續）。

**「浮起來」根因 + 舊格式地域移除**：使用者實走發現角色浮空。根因＝舊格式單-backdrop 地域（meadowOrigin/kingdom/village3/skyVillage/skyCity）只渲染 far 一層、far 自畫前景地平線落在薄 40px 地面條上方（layered 有 mid/fore 蓋住就沒事）。使用者決定「舊的先移除、用新的」→ cycle 移除該 5 個、**enum case 保留**（休眠模式，meadowOrigin 仍當 fallback 預設，槽位/override 原樣留），待重生 layered 版加回。**→ 8 地域全 layered 循環**：`hotspringVillage→harbor→snowMountain→steampunkCity→futureCity→mountainPalace→magicCity→holyCity`。實機 harbor 驗收角色穩踩碼頭無浮空。

- 測試 **328/328 綠**。
**待使用者**：① 重生 5 個舊地域為 layered 格式（磁紅 mid/fore + far 壓低地平線）加回 cycle；② 8 地域 GUI 實走體感；③ CharacterNode idle 接線（4 待機幀已切好待用）；④ future_city 喚醒度最高、mountain_palace 仙俠味去留（已留備註）。

---

## 2026-07-05 — 陪伴弧 P1–P4（準則一核心）+ 雙鏡工作法 + 美術新流程

**工作法定調（記憶 [[dual-lens-review-policy]]）**：每次產出都過「心理學(Fable)×design-engineer(Emil review-animations 技能,`.agents/`)」雙鏡、實際看不嘴上說。衝突時心理學/非侵入優先。

**陪伴弧（設計 `docs/22_COMPANIONSHIP_DESIGN.md`）**——主角獨行後陪的是使用者;解「社會臨場×Calm Tech非侵入」張力(陪伴＝可得+覺察+共存,非活動+要求)。全用良性訊號、**零窺視工作內容**(只讀 CGEventSource 閒置秒數)、無聲不彈窗、無健康說教、distance不變式、reduce-motion。
- **P1 在場與歸來**：歸來的溫暖(螢幕喚醒/長閒置→活動)、陪你歇(閒置180s,活的姿態非凍幀,只凍displayedDistance)。PresenceSchedule純函式。
- **P2 共時深化**：深夜陪伴(真實時刻,絕不勸睡—寫進測試 testNoLateNightLineMentionsSleepOrHealth)、關係性時刻(里程90000稀疏)。RelationalMilestones/LateNightPresence純函式。
- **P3 靜定的錨**：休息呼吸共調(歇時呼吸切10s慢版≈6次/分,餘光可跟隨的節拍器)。BreathingProfile純函式。裁決:只用長歇非短看(churn)。
- **P4 專注時退場**：連續活動>270s判心流→純減法暫停toast+收看你,休息(28s)恢復。FocusState純函式,與P1c分層。
- 每階雙鏡通過才提交。**308測試綠**。**待使用者live體感校準**(振幅/門檻/語氣—感受型只有活過才知,已抽常數易調)。

**美術新流程(治本,承使用者「改提示詞不要code workaround」指正)**：`docs/20`提示改「只有遠景含天空,中景/前景畫洋紅#FF00FF底可去背」→切圖洋紅chroma-key+de-fringe+邊緣羽化無縫(不鏡射)→真多層視差(RegionType.isLayered)。harbor已驗證取代sea_city進循環。主角走路換8幀真循環(main_role_walk,速度改固定0.9s/循環)。分享連結圖:curl public_content URL 直接下載。
- **其餘7地域待使用者用新提示(洋紅格式)重生→我接成真視差layered**(現為舊格式單backdrop)。

---

## 2026-07-05 — Session 1（夜間自主）— 美術大改版 Wave 1–3

使用者重整全套素材（8 地域 + 主角 + 20 種居民，皆 1536×1024 照 `20` 規格）就寢，授權自主執行+自我驗證。計畫見 `21_ASSET_OVERHAUL_PLAN.md`。
- **Wave1（1e5c36d）**：主角改 `main_role`（綠斗篷遊俠，右3+前3幀、真走路循環）、旅伴改 `resource_v2` 女冒險者（8幀）、grassland 取代 meadow。**Fable 自驗抓修殘留幀 bug**（舊 right_3/4 混入）+ slice_assets 重切前清 numbered 幀。
- **Wave2（ea212bf）**：重切 kingdom(新1536×1024) + 切 valley/village_2/village_3/sky_village/sky_city → **8 地域循環** `[grassland,village2,valley,kingdom,village3,seaCity,skyVillage,skyCity]`，blend 通用。
- **Wave3（7acfa2b）**：切 17 種居民 NPC→共享 `npc/`，`KingdomNpcScatter`→`RegionNpcScatter` 泛用化、依 `21`§3 分地域配置。
- **design 素材入版控（791042b）**：全套原始圖供 slice 重建；廢 kingdom_characters。
- 測試 **249/249 綠**。自我驗證＝build/test + 直讀切圖（螢幕整夜睡、無法截圖）：主角/旅伴/8地域far/多個道具/NPC 皆直讀確認乾淨、暖調無黑暗、高品質。

**待使用者醒來**：GUI 實看（新主角在各地域走路、滿街 NPC）；螢幕醒時 Fable 補截圖。
**已知小瑕（可優化）**：部分地域 far 左上角標籤補丁殘跡（同既有取捨）；主角 3 姿勢走路仍非真左右交替（可改用 resource_v2 男完整走路幀）；stale `regions/meadow` 已清。
**Wave 4（延後，需使用者視覺確認+設計決策）**：sky_city 夜間版(`sky_city_magic_night.png`)聯動晝夜（風險：與晝夜 tint 疊加恐雙重變暗，須實看調校）；resource_v2 補充道具；主角男/女可選。

---

## 2026-07-04 — Session 1（續）— Stage B 王國地域 + 動畫 a11y 審視

- **Stage B（0574cb8）**：使用者提供 `design/kingdom.png`（中古王國首都素材）→ 接成第二地域。slice_assets 切王國 bg(far/mid/fore/ground)+props；Region meadow↔kingdom 交替(regionLength 172800)+blend(atDistance) crossfade 純函式；ParallaxBackground.buildRegion+GameScene 地域編排(crossfade 合成不透空)；FYW_DEBUG_REGION。Fable 截圖驗收：王國畫面與草原風格一致、邊界 50/50 crossfade。234 綠。
- **動畫 a11y（81f79c5）**：使用者分享 Emil Kowalski `review-animations` 技能（裝於 `.agents/`，gitignore）→ 審視所有動畫、守 §3.4 calm 定位。真修：**reduce-motion 覆蓋補全**（呼吸/暖心/看你/相遇/離線捲動在減少動態時去位移保 opacity）+ 2 處 timingMode。判刻意保留者附理由。
- **待人工驗收**：reduce-motion 開關下角色行為（呼吸停/暖心只剩光暈/離線瞬移）；王國畫面 live。
- **Stage B+ 後續（可選）**：王國 NPC（士兵/公主當城中行人）、王國/城市風味相遇卡（需 EncounterDeck 加 region 過濾）、石城夜間燈光。

---

## 2026-07-04 — Session 1（續）— Phase 4 後：心理學迭代 + 無邊世界 + 拖曳

六階段完成後的深化（皆 Fable 截圖/真機驗收、里程碑自動提交）：
- **Polish**：切圖去斑（角色+道具）、遠中景接縫柔化、走路改乾淨 2 拍（臨時；真左右交替待重生素材）。
- **P1+P2 心理學微行為**（`13_PSYCH_AUDIT`）：主角待機呼吸 + 偶爾看向你（front 幀 + HeroRestSchedule）+ 游標靠近回應（ProximityAwareness）。修正「主角比旅伴呆板」。distance 不變式保留。
- **晝夜光影+天氣（4c）**：DayNightCycle/Weather 純函式 overlay；Fable 抓修 alpha 相乘 bug + 調強設計值。
- **故事線（14）+ 無邊世界（15）**：使用者要「廣大無邊境、不會有終幕」的溫柔中古魔幻（無黑暗勢力）。推翻石門終幕，改 Region Band 沿里程無限展開；Encounter Card 為最小內容單位；無邊≠無盡刷的紅線劃分。
- **Stage A（16）無邊 MVP**：Season 純函式+四季色調 overlay（綁里程）、EncounterDeck 相遇卡系統（不持久不收集）。**卡組 24→76 張**（`17`，Opus 草擬 Fable curate）。companion 卡去性別化 + 相遇前不出 companion 閘門。
- **拖曳（ADR-011）**：抓角色拖曳移動桌寵 + 記住位置（UserDefaults）+ 螢幕夾取純函式；短按仍暖心。
- 測試 226 綠。commit 多筆（…b6639d9 Stage A / 1d011b5 卡擴充 / 769681d companion polish）。

**待使用者**：拖曳手感回饋；**Stage B 需新地域美術**（使用者用 ChatGPT 生新地形素材表 → 接第二地域）；/Applications 目前是拖曳版，「全功能版（拖曳+四季+76卡+微行為）」待使用者說要就更新安裝。
**未來 polish**：真左右交替走路素材、companion 卡母本 24 張也去性別化、季節色調明顯度可調、P3 可回顧旅程日誌（`13` 高價值高成本）。

---

## 2026-07-04 — Session 1（續）— Phase 4a/4b/4c（像素美術 + 晝夜天氣）

使用者用 ChatGPT 產出像素素材表（`design/assets/asset_sheet.png`：兩角色4向走路+道具+分層背景，側面橫向捲軸）。分期整合，每期 Fable 親自 build+截圖驗收（Sonnet 施工、Fable 抓 bug 修）：
- **4a（710f5e5）**：slice_assets.py 純標準庫切圖 + ArtCatalog + 背景三層 panorama + 主角走路。Fable 抓「背景全黑」＝panorama 誤用 wrappedX scatter → 修為 panoramaTileXs 無縫平鋪 + 迴歸測試。
- **4b（72ce94d）**：旅伴 sprite 同行（構圖主從）+ 15 道具 + 地面 scatter + 地標 signpost。
- **4c（d4fbfeb）**：晝夜光影(DayNightCycle)+天氣(Weather 晴/陰/雨+雨絲)+reduce-motion 控制+QA env。Fable 抓兩 bug：overlay color alpha 相乘變透明→改不透明 color；設計 alpha 太低→真機校準調強。夜藍/黃金暖/雨皆正確。
- 測試 151/151 綠。**已知小瑕疵**：遠/中景 panorama 交界一條淡水平接縫（各為獨立小場景），留 polish。
- **下一步：4d 點角色微互動（Phase 4 最後一項）** → 之後 Phase 4 完成，全專案僅剩 polish。QA env：`FYW_DEBUG_SECONDS_INTO_DAY` / `FYW_DEBUG_WEATHER`。

---

## 2026-07-04 — Session 1（續）— Phase 2 實作交付 + Fable review

**Sonnet 交付 Phase 2**：Simulation（TimeProvider/GameState/SimulationRules/SimulationEngine/OfflineProgress）+ Persistence（SaveStore/SavePaths/SaveSchema/Migrations）+ Scene（WorldScroll/改 WalkMotion 語意為里程/固定左側 CharacterNode/GameScene 消費 GameState + 離線回歸呈現）+ 選單列結束 + isPaused 省電。`swift test` **55/55 綠**（Phase 1 舊 19 不回歸 + 新 36）。離線結算端到端驗證（改時間戳 5h→distance≈18000、過地標）。

**Fable review**（獨立重跑 build+55/55 綠，逐檔審核心）：
- ✅ `OfflineProgress`/`SimulationRules` 正確；**「線上=離線同速」迴歸鎖測試**確實斷言 online gain==offline gain（ADR-005/紅線六鎖死）。負值→0、超上限截斷、邊界正確。
- ✅ `SaveStore` 資料安全（只在現存有效時才覆蓋 .bak、未來版本視同壞檔回退）；AppDelegate 首啟 `lastActiveTimestamp=now` 避免 1970 bug；選單列「結束」(Cmd-Q) 解決「關不掉」；WorldScroll/ADR-009 固定左側正確。
- ✅ P6 離線呈現改「自動 2.5 秒淡出」（原點擊略過因整窗穿透無法做）—— Fable 認可（更非侵入），已更新 `08` §7 P6。
- 🐞→✅ **正確性不一致已修並驗證**：`resumeWithCatchUp()` 複用 `OfflineProgress.settle`（capped）、清 `lastUpdateTime`、`performTick` clamp dt 到 12h 安全網；三路（離線啟動/閒置恢復/睡眠喚醒）統一。新增 24h gap 等價測試。Fable 獨立重跑 **56/56 綠**。

**Phase 2 程式碼 + 測試：✅ 完成並通過 Fable review。**

**待人工驗收（GUI，只有使用者能做）**
1. 關掉再開 → 看「你不在時走了一段路 + 路過地標」的回歸呈現（2.5s 捲動補間 + 旅程日誌）觀感、語氣是否夠溫柔。可用「把 save.json 的 `lastActiveTimestamp` 改早幾小時」或關久一點再開來觸發。
2. 固定左側 + 世界捲動觀感（背景是滿版純色，捲動位移不明顯，需 Phase 4 真美術有紋理才看得出視差 —— 已知限制）。
3. 選單列 🚶 →「結束」是否正常關閉、「顯示/隱藏」是否正常。
4. 閒置 60 秒後 isPaused 前後 CPU 對照（補 `08` §8.3 尚缺欄位）。

**下一步**：使用者 GUI 驗收 Phase 2 → 通過後可 git commit（Phase 1+2 檢查點，待授權）。

---

## 2026-07-04 — Session 1（續）— Phase 2 視覺驗收（使用者截圖）+ 背景修正

**使用者截圖回報**：✅ 透明懸浮視窗成立（看得到終端在後、無邊框）；🐞 (1) 天空/草地色帶橫向錯位；(2) 看不出速率。
**根因**：`ParallaxBackground` 對滿版純色帶套不同 layerFactor（0.1/0.4）→ 兩帶各自左移不同量 → 錯位+露空；純色帶捲動無參照物＋speed=1（離線設計）→ 現場近乎靜止。
**Fable 處置（triage：影響當前 phase 核心價值 + 阻塞 P1 手感判斷 → 緊急插修，不延 Phase 4）**：規格加 `08` §4b。
**已完成並提交（faf940a）**：
- 天空/草地固定滿版（消錯位）；WorldScroll.wrappedX 純函式驅動可循環景物：遠景丘陵（慢）+ 近景松影綠草叢 + 山徑赭路面（快）。
- speed 1→12、Landmark 間距 10800→86400（~2h/地標）。Palette 加 Pine Shadow/Trail Ochre。
- Fable 兩輪截圖驗證：對齊 ✓、近景景物對比可見 ✓。測試 63/63 綠。
- **git**：e9f348e（Phase 0-2）、faf940a（視覺修正）。使用者已授權自動 commit。

**下一步**：使用者 live 跑判斷 speed=12 散步手感（P1）→ 確認後定 Phase 3 里程數值、開工 Phase 3。**小可調點**：角色目前站草地、路面在其下方；若要「走在路上」可微調角色 y（留待使用者反應）。

---

## 2026-07-04 — Session 1（續）— Phase 4a 完成（像素美術整合）

- 使用者用 ChatGPT 產出像素素材表（兩角色4向走路+道具+分層背景，側面橫向捲軸）。
- Sonnet 建 slice_assets.py（純標準庫切圖/去背）+ ArtCatalog + 整合背景三層 + 主角走路 5 幀。
- **Fable 抓渲染 bug**：背景全黑 → 定位為 panorama 誤用 wrappedX scatter（distance>0 時整片露空透出深色桌面）→ 委派修為 WorldScroll.panoramaTileXs 無縫平鋪 + 5 條覆蓋迴歸測試。
- **Fable 親自 build+截圖驗收通過**：遠山城堡/中景村莊教堂/地面三層視差 + 金髮旅人走動，含 distance>0 正常。131/131 綠。提交 710f5e5。
- **已知小瑕疵（留 polish）**：遠景/中景兩條 panorama 交界有一條淡水平接縫（各為獨立小場景非無縫延伸），4b/polish 再處理。
- **剩餘 Phase 4**：4b 旅伴 sprite + 道具/地標視覺；4c 晝夜光影 + 天氣；4d 點角色微互動。

**4b 完成（提交 72ce94d）**：旅伴 sprite 走路（取代卡其色塊、構圖主從略小略後）+ 15 道具切圖 + 地面 scatter 8 種 + 地標 signpost sprite。137/137 綠。Fable 截圖驗收：主角+旅伴同行、路標「一座舊石橋」、道具散佈皆正確。→ 接 4c 晝夜光影+天氣。

---

## 2026-07-04 — Session 1（續）— Phase 5 啟動（使用者選擇先出貨）

使用者看完 Phase 4/5 細節後選 **Phase 5 先出貨**（無美術新變數、可立即動工，裝起來日常用幾天再帶手感做 Phase 4）。
委派 Opus 草擬 `10_PHASE5_SPEC.md`（自啟/選單列/偏好設定/打包簽章）。Phase 4 暫緩。
- **使用者拍板簽章＝ad-hoc 自用不公證**（ADR-008 更新）。
- Fable review 通過 `10` 規格、§10 待決全定案（ad-hoc/佔位icon/狀態卡三行/純AppKit/不記位置/不放音量）。
- **R1（ad-hoc × SMAppService 自啟）最高驗證**；fallback：自啟卡關→系統設定手動加登入項，不阻擋其餘交付。
- 委派 Sonnet 實作 Phase 5（偏好資料層 TDD/狀態卡片/偏好視窗 SwiftUI/LoginItemService/螢幕重錨定/打包 SIGN_MODE=adhoc）。
- **完成並提交（94284ac）**：Fable 獨立驗證 126/126 綠、親自打包驗 **ad-hoc 簽章通過**（codesign --verify --deep --strict）、讀核心（StatusCardText 克制無裸數字、LoginItemService status 真相來源）皆正確。Sonnet 未 live 呼叫 register()（不動使用者登入項，判斷正確）。
- 寫 `11_INSTALL_GUIDE.md` 安裝驗收指南。**待使用者：build_app.sh → /Applications → 首次開啟 → 開自啟 → 重開機驗 R1**（fallback：系統設定手動加登入項）。

**Phase 5 ✅ 程式碼完成。專案：Phase 0–3 + 5 全部完成（佔位美術），可安裝常駐。僅 Phase 4（質感/正式美術）待做。**

**2026-07-04 安裝後 bug 修正**：使用者回報「後面都不動了」→ 診斷為省電邏輯以鍵鼠閒置≥60s 暫停，凍結了「正在被看」的桌寵（看≠輸入，搞反本質）。修正：移除鍵鼠閒置暫停，暫停只在系統睡眠/螢幕睡眠/選單列隱藏（`08` §8.2b）。126/126 綠，提交 160d499。**✅ 使用者重裝驗證「可以了」——不再凍結、持續行走。**（「一開始跑很快」＝離線回歸動畫，設計內、可調緩。）
（附註：安裝指令勿加行內註解——使用者 zsh 未把 `#` 當註解，害 mv 吃到註解字。`11_INSTALL_GUIDE` 指令已為乾淨多行。）

**專案狀態：Phase 0–3 + 5 完成且實機可用（佔位美術、不凍結）。** 尚待：R1 開機自啟需重開機驗（可選）；Phase 4（正式美術/晝夜/天氣/微互動，需美術路線決策）。
**git**：e9f348e/faf940a/a8bddea/963f3f1/29edeb1/94284ac/fc25a63/160d499。

---

## 2026-07-04 — Session 1（續）— Phase 3 完成（review + 真機驗證 + 提交 963f3f1）

**兩修正完成並驗證**：schemaVersion 戳版本（save 時 currentVersion）+ 章節轉場 toast（chaptersCrossed 純函式，離線=線上迴歸鎖）。106/106 綠。
**Fable 真機端到端驗證**：寫 v1 舊存檔（無新欄位、schemaVersion:1）+ 時間戳 6h 前 → 啟動 → 存檔變 **schemaVersion:2**（遷移+戳版）、`companionJoined:true`（離線跨 237600 相遇）、`eventsEncountered:[野花坡,溪邊,石上鳥,相遇]`、3 地標、distance 259207。舊資料保留。
**畫面驗證（Fable 截圖）**：離線回來顯示相遇旅程日誌文案；CompanionNode（卡其小方塊）在主角左後方同行，構圖主從成立。
**git**：963f3f1（Phase 3）。累計 commit：e9f348e / faf940a / a8bddea / 963f3f1。

**Phase 3 ✅ 完成。專案里程碑：Phase 0–3 全部完成、106 測試綠、真機驗證。**

**下一步（給接手 session）**
1. 剩餘待人工驗收（GUI 主觀）：相遇 peak 暖金光的「慢而不閃」觀感、同行構圖美感、章節/事件 toast 節奏、閒置 isPaused CPU 下降。
2. **Phase 4（陪伴質感：正式像素美術 / 晝夜光影 / 天氣 / 點角色微互動 ADR-006）**：需先寫規格（先文字後實作）。美術資源是新變數——需與使用者確認美術路線（自繪像素 / 素材庫 / 委外）。
3. Phase 5（打包常駐：自啟 SMAppService / 完整選單列 / 簽章 Notarize）。
4. 里程碑自動 commit（使用者已授權）。

---

## 2026-07-04 — Session 1（續）— Phase 3 實作交付 + Fable review

**Sonnet 交付 Phase 3**：JourneyEvent(5事件)/Companion(meetDistance 237600)/GrowthStage/GameState 擴充/SimulationEngine.advance 4-tuple/OfflineProgress 事件補算/schema 1→2/CompanionNode/相遇 peak 呈現。`swift test` **97/97 綠**（+34）。

**Fable review**（獨立 build+97 綠，讀核心）：
- ✅ **T8 離線事件靈魂測試紮實**：線上逐tick(37s抖動) vs 一次settle 事件序列相等（迴歸鎖）、無 now-seed（不同牆鐘同結果）、wasCapped 用慢速rules讓cap落事件表中間、驗證超出事件此次不出現且繼續走終會遇到（紅線二）。Companion 純函式單調正確。
- 🔧 **送修 2 點**（Sonnet 誠實 flag）：(1) schemaVersion 永停 1＝欄位說謊 → save 時戳 currentVersion + 測試；migration 接 load 延後（additive 靠 decodeIfPresent 足夠，破壞性改動才接線——**已知架構決定**）。(2) 章節有邏輯無呈現＝死碼 → 用既有旅程日誌 toast 顯示章節轉場（非互動、屬 §4.1 章節感）。修正進行中。

---

## 2026-07-04 — Session 1（續）— P1 定案 + Phase 3 開工

- ✅ **使用者驗收「速度剛好」** → P1 `speed=12` 定案（ADR-010），地標間距 86400（~2h）定案。
- ✅ Phase 3 里程數值定案（相對 P1）：`meetDistance=237600`、5 個里程事件、章節門檻。
- ✅ **Fable 親自 authored 敘事內容**（`09` §10）：地標留白中文名、5 個事件文案、旅伴相遇文案（沉默同行）、3 章節名。把關「留白可投射、不施壓」語氣。
- 🔄 **委派 Sonnet 實作 Phase 3**（TDD）：JourneyEvent/events()/GameState 擴充/Companion/OfflineProgress 事件補算/GrowthStage/schema 1→2 真實遷移 + Scene 相遇 peak/CompanionNode/日誌章節。T7–T12，不回歸既有 63。

**下一步（給接手 session）**
1. 等 Sonnet 回報 → Fable 獨立 build+test + 逐檔審（尤其 T8 離線事件迴歸鎖、§7 倫理界線無 now-seeded 擲骰、相遇單調、schema 遷移不丟資料）。
2. 通過後親跑驗證（模擬離線跨 meetDistance → 相遇觸發、事件補算）+ 請使用者畫面驗收相遇 peak/同行構圖。
3. 里程碑自動 commit。

---

## 2026-07-04 — Session 1（續）— Phase 2 執行期驗證（Fable 親跑，使用者授權）

使用者授權「自己 run 起來驗證碼」。Fable 建 .app、實際啟動，端到端驗證 Phase 2 核心邏輯（非僅單元測試）：
- ✅ **首啟**：全新存檔 `distance:0`、`lastActiveTimestamp≈now`（避開 1970 bug）。CPU ~4%、RAM ~55MB（比 Phase 1 的 134MB 低）。
- ✅ **離線 6h**：時間戳改早 6h 重開 → `distance=21600.1`（≈6h×speed1.0）、通過 2 地標（windy_pass, nameless_bend）。線上=離線同速在真機成立。
- ✅ **12h 上限**：時間戳改早 24h → `distance` 精確截斷在 **43200（12h），非 86400**、通過 4 地標。ADR-005 cap 成立。
- ✅ App 啟動/存檔/關閉乾淨；已清理測試存檔與 .app。

**仍需人眼驗收（Fable 跑不出來的）**：透明外觀、點擊穿透、世界捲動/固定左側觀感、離線回歸動畫呈現、選單列視覺、閒置 60s 後 isPaused 的 CPU 下降對照（需掛機 60s）。**推進節奏 P1 手感**仍待使用者主觀感受確認。

---

## 2026-07-04 — Session 1（續）— Phase 3 規格草擬（利用等待期）

**做了什麼**：委派 Opus 草擬 `09_PHASE3_SPEC.md`（事件/旅伴相遇/成長）；Fable review 通過工程結構，標為條件式 Accepted。
- **核心設計**：事件掛里程軸（確定性取代變動比率增強）、A/B 事件分野（隨機與持久不得共存）、離線事件複用 `OfflineProgress.settle`、相遇為 peak event（守無 jolt）、成長階段純函式衍生、schema 1→2 真實遷移。全逐條符合 `02` §7 倫理界線。
- **已鎖設計原則**：E3 旅伴沉默留白、E4 不用等級數字（章節名取代）、E5 authored 固定表。
- **待 P1 驗證後定**：E1 事件密度、E2 相遇里程、E6 事件內容、E7 成長門檻（全相對 P1 速率）。

**Phase 3 實作前置**：Phase 2 手感（P1 推進速率）須先經使用者 GUI 驗收；§7 前 8 步純邏輯可先做，第 9 步整合與里程數值待 P1 確認。

**下一步（給接手 session）**
1. 等使用者 GUI 驗收 Phase 2（關掉再開走了一段路 + 手感/推進節奏 P1 是否悠閒）——**唯一真正阻塞**。
2. 驗收 OK + P1 確認 → 可開工 Phase 3（先純邏輯 T7-T12，再整合）。
3. 規劃已到 Phase 3；不再超前規劃 Phase 4（真美術/晝夜/微互動），那依賴前面手感與美術資源。
4. git commit（Phase 1+2）待使用者授權。

---

## 2026-07-04 — Session 1（續）— Phase 1 人工驗收（使用者）

**使用者實測結果**
- ✅ 視覺/視窗行為全過：小人在畫面內走、透明背景（桌布透出非黑底）、點擊穿透、不搶焦點、置頂。
- 📊 **R1 能耗首測**：CPU **~2.7%** / RAM **~134MB**（30fps 持續 render，角色恆動）。已回填 `08` §8.3。
- 🐞 **驗收發現真實 gap**：App 無 Dock/無選單列 + 無邊框 + 點擊穿透 → **使用者無法關閉**（只能 pkill/Ctrl-C）。違反準則一（紅線四邀請非強迫 / SDT 自主：關不掉的陪伴＝侵入）。

**Fable 處置**
- 判定 R1 結論：Phase 2 **需做「靜止即 isPaused」省電**（2.7% 對常駐非趨近 0）。
- 修訂 `06_PHASE1_SPEC` §0/§8：Phase 1 追加**極簡選單列**（含「結束」+ 顯示/隱藏），從 Phase 5 提前最小集合。委派 Sonnet 實作中。

---

## 2026-07-03 — Session 1（續）— Phase 1 實作交付 + Fable review

**Sonnet 交付**：完整 SPM 專案（FindYourWayCore library + FindYourWay executable + tests）。`swift build` 綠、`swift test` 17/17 綠、`build_app.sh` 產出 `FindYourWay.app`（Info.plist 合法含 LSUIElement）。

**Fable review**（獨立重跑 build+test 通過，逐檔審）：
- ✅ `PetWindowConfig.Flags` 精確對應 `04` §2.2；`WalkMotion` 純邏輯正確；`Palette` HEX 解析正確；executable 薄殼組裝正確、無 scope creep。
- 🐞→✅ **座標系 bug 已修並確認**：範圍算式抽成純函式 `WalkMotion.horizontalRange(sceneWidth:characterSize:)`（左下慣例 0..width），`position.y` 改正值站草地上；新增 2 條守護測試。Fable 獨立重跑 `swift test` **19/19 綠**。

**Phase 1 程式碼 + 測試部分：✅ 完成並通過 Fable review。**

**待人工驗收（GUI + 能耗，只有使用者能做）**：見新文件 `07_PHASE1_ACCEPTANCE.md`（可照做的驗收指南）。項目：透明外觀/無黑底、點擊穿透、右下角定位、不搶焦點、置頂、跨 Spaces/全螢幕(R4)、層級禮貌(R7)、**R1 能耗基準**（掛機 5–10 分，含 isPaused 對照）。

**下一步**：使用者跑 `07` 驗收 → 記錄結果。此為適合首次 git commit 的檢查點（待授權）。

---

## 2026-07-03 — Session 1（續）— Phase 2 規格草擬（利用等待期）

**做了什麼**（趁使用者 GUI/能耗驗收的空檔，推進不依賴 R1 的文字規劃）
- 委派 Opus 草擬 `08_PHASE2_SPEC.md`；Fable review 通過工程結構，標為條件式 Accepted。
- 亮點：`SimulationRules` 單一速率來源（ADR-005 同速＝架構保證 + T2 迴歸鎖）、`TimeProvider`/`SavePaths` 可注入（headless 可測）、§4 六條紅線落地為硬約束、§8 省電對 R1 誠實留白。

**Phase 2 實作的兩個前置條件（Sonnet 尚不可開工）**
1. R1 能耗數據（使用者跑 `07` §C → 回填 `08` §8.3）。
2. 產品參數 P1~P7（`08` §7）：Fable 設 P2/P3/P4/P5/P7 預設；**P1 速率、P6 離線呈現待問使用者**後回填 `01_DECISIONS`。

**追加（Fable 定產品參數）**：`08` §7 的 P2/P3/P4/P5/P7 已由 Fable 依已定案文件鎖定（provisional）；僅 **P1 推進速率、P6 離線呈現**留給使用者拍板。

**下一步（給接手 session）**
1. 等使用者回報 Phase 1 GUI/能耗驗收（唯一真正阻塞）。
2. 驗收 OK → 回填 `08` §8.3、與使用者確認 P1/P6 → 委派 Sonnet 實作 Phase 2（TDD）。
3. **已達計畫性等待點**：Phase 1 程式碼 + Phase 2 規格 + 產品參數皆就緒。不再往 Phase 3 超前規劃（會建在沙上）。後續 cron tick 若使用者仍未回應 → 維持等待、勿再生成，節省 token（準則三）。
4. 每 10 分鐘 cron loop (job 94cc6abf) 持續兜底。

---

## 2026-07-03 — Session 1（續）— OQ 定案 + Phase 1 規格 + 委派實作

**做了什麼**
- 使用者拍板 OQ-1（相遇式旅伴）、OQ-3（嚴格零功利互動）；Fable 依收斂建議鎖定 OQ-2/OQ-4/App Store。
- 回填 `01_DECISIONS.md`：新增 ADR-004~008，Open Questions 清空。
- 寫 `06_PHASE1_SPEC.md`（Fable 定案）：SPM(library+executable+test) 建置策略、逐檔要點、施工順序、R1 能耗基準、**測試紀律**（使用者要求：每 Phase 含測試，`swift test` 全綠）。
- 確認工具鏈：Xcode 16.2 / Swift 6.0.3 / macOS 26.5.1 / Apple Silicon。
- **委派 Sonnet 實作 Phase 1**（背景進行中，agentId 見 session）：照 06 規格建專案、build+test 跑綠、產出 .app。

**下一步（給接手 session）**
1. 等 Sonnet 回報 → Fable review：對照 `06` §0 驗收 + §5b 測試全綠 + 分層對齊 `04` + 無規格外功能。
2. 程式碼過關後，**透明外觀/穿透/右下角定位/能耗需使用者親自在畫面上驗收**（GUI 無法由 agent 自動確認）。可用 `/run` 或 `swift run`。
3. 驗收通過 → 更新本日誌與 `05_ROADMAP` 勾選 Phase 1 → 寫 Phase 2 規格（時間推進/離線結算/存檔，TDD 主場）。
4. 每 10 分鐘 cron loop (job 94cc6abf) 持續兜底。

---

## 2026-07-03 — Session 1（續）— 三份深度規格定案

**做了什麼**
- 三個 Opus 子代理平行產出深度規格，Fable 逐一 review 並定案（皆標記 Accepted）：
  - `02_PSYCHOLOGY_FOUNDATION.md` — 8 條理論 + 6 條反成癮/反愧疚紅線 + 療癒vs剝削判準表。
  - `04_ARCHITECTURE.md` — 透明 NSWindow/SKView 方案、模擬渲染解耦、時間戳離線結算、省電、Phase 1 施工順序附錄。
  - `03_DESIGN_SYSTEM.md` — Calm Technology 三戒律、「冷底暖點」色盤(HEX)、像素規格(32×32/走路4格/7層parallax)、WCAG。
- 三份規格的理論引用經 Fable 抽查皆真實可查，⚠️ 誠實標註到位，無杜撰。

**進行中 / 下一步**
- 三份規格對 OQ-1~4 的建議高度收斂。Fable 準備向使用者拍板兩個「產品意向」分叉（OQ-1 旅伴引入方式、OQ-3 互動範圍），其餘（OQ-2 離線推進、OQ-4 存檔、App Store 時程）由 Fable 依收斂建議鎖定。
- OQ 全數定案後 → 回填 `01_DECISIONS.md` → 進 Phase 1（會走路的空殼），委派 Sonnet/Codex 依 `04` 附錄 A 施工。
- 每 10 分鐘 cron loop (job 94cc6abf) 持續兜底推進。

---

## 2026-07-03 — Session 1（Fable，專案負責人）

**做了什麼**
- 與使用者確認三個定案決策：桌寵懸浮視窗 / Swift+SpriteKit / 純放置陪伴。
- 建立地基文件：`00_CONSTITUTION`、`01_DECISIONS`（ADR-001~003 + 4 個待決問題）、`05_ROADMAP`、本日誌。

**決定了什麼**
- 三條不可打破準則正式定案（心理學為本 / 先文字後實作 / 分層協作省 token）。
- 文件地圖與接手閱讀順序確立。

**進行中**
- 委派 Opus 平行草擬三份深度規格：`02_PSYCHOLOGY_FOUNDATION`、`03_DESIGN_SYSTEM`、`04_ARCHITECTURE`。
- 草稿完成後由 Fable review、定案，並回填 `01_DECISIONS` 的待決問題 (OQ-1~4)。

**下一步（給接手 session）**
1. 檢查三份規格草稿是否已產出於 `docs/`。
2. 若有草稿 → Fable review、修訂、標記為 Accepted。
3. 三份規格定案後 → 進入 Phase 1（Walking Skeleton），委派 Sonnet/Codex 建 Xcode 骨架。
4. 尚未定案前，**不得開始寫實作碼**（準則二）。
