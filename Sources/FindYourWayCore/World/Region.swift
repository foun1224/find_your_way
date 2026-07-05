import Foundation

/// Region skeleton（`16_STAGE_A_SPEC.md` §2.3b，Stage B 擴充見 `18_STAGE_B_SPEC.md` §2，
/// Stage C 擴充見 `19_STAGE_C_SPEC.md` §2，美術大改版第 2 波擴充見
/// `21_ASSET_OVERHAUL_PLAN.md` §2/§4）：薄骨架，為地域美術預留掛點。
/// `riverlands`/`highlands`/`coastalReach` 尚無美術，保留骨架供未來地域擴充；
/// **目前上線的序列是 13 地域循環（全部 layered 新格式）**：
/// `meadowOrigin → village3 → kingdom → hotspringVillage → harbor → snowMountain →
/// steampunkCity → futureCity → skyVillage → mountainPalace → magicCity → holyCity →
/// skyCity`。
///
/// **舊格式地域移除（使用者決定，2026-07-05）**：meadowOrigin(grassland)/kingdom/
/// village3/skyVillage/skyCity 這 5 個舊「單 backdrop」地域會讓角色看起來「浮在半空」
/// （只渲染 far 一層、far 自己畫的前景地平線落在薄地面條上方；layered 地域有 mid/fore
/// 蓋住就沒此問題），已從 `cycle` 移除。**enum case 保留**（同 seaCity/riverlands 休眠
/// 模式，`meadowOrigin` 仍當 `assetFolder` fallback 預設 + debug override 用）。
///
/// **skyVillage 重新排回循環（接手任務，2026-07-05，五張舊地域重製收尾）**：
/// `design/sky_village_layered.png`（浮空天空村：漂浮小島小屋/風車/繩橋/瀑布）補了
/// layered 格式美術，`skyVillage` 改指到新資源夾 `"sky_village_v2"`（取代舊
/// `"sky_village"` 單張背景）。加入 `layeredRegions`，重新排回 `cycle`（`futureCity`
/// 之後、`mountainPalace` 之前，作為進入浮空天界群島序列的入口）。至此 5 張舊地域
/// （meadowOrigin/kingdom/village3/skyCity/skyVillage）全數補上 layered 美術、重新排回
/// 循環，`cycle` 由 12 地域擴為 13 地域。
///
/// **meadowOrigin 重新排回循環（接手任務，2026-07-05）**：`design/village_layered.png`
/// 補了 layered 格式的歐式中世紀奇幻村莊美術（`21` §8A 洋紅去背 + 真多層視差管線），
/// `meadowOrigin` 改指到新資源夾 `"meadow_village"`（取代舊 `"grassland"` 單張背景），
/// 加入 `layeredRegions`，重新排回 `cycle` 最前面（開場地域）。
///
/// **kingdom/village3 重新排回循環（再接手任務，2026-07-05）**：`design/city_layered_1.png`
/// （歐式白金王國首都）補了 layered 格式美術，`kingdom` 改指到新資源夾 `"kingdom_city"`
/// （取代舊 `"kingdom"` 單張背景）；`design/village3_layered.png`（森林樹屋村落）補了
/// layered 格式美術，`village3` 改指到新資源夾 `"tree_village"`（取代舊 `"village_3"`
/// 單張背景）。兩者皆加入 `layeredRegions`，重新排回 `cycle`（緊接開場 `meadowOrigin`
/// 之後：`meadowOrigin → village3 → kingdom → ……`）。skyVillage/skyCity 仍是舊格式、
/// 仍休眠，待補上 layered 美術才能重新排回。
///
/// **skyCity 重新排回循環（再接手任務，2026-07-05）**：`design/sky_layered.png`（白金浮空
/// 天空之城）補了 layered 格式美術，`skyCity` 改指到新資源夾 `"sky_city_v2"`（取代舊
/// `"sky_city"` 單張背景）。加入 `layeredRegions`，重新排回 `cycle` 最尾端（壓軸地域，
/// `…… → holyCity → skyCity`）。skyVillage 仍是舊格式、仍休眠，待補上 layered 美術才能
/// 重新排回。
/// 純函式、確定性，可測。
public enum RegionType: Equatable, CaseIterable {
    case meadowOrigin
    case riverlands
    case highlands
    case coastalReach
    /// 王國首都（接手任務，2026-07-05：`design/city_layered_1.png` 補上 layered 格式的
    /// 歐式白金王國首都美術——尖塔/拱橋/雪山遠景/天使雕像/紋章大門/華麗宅邸/噴泉，取代舊
    /// `"kingdom"` 單張 backdrop），遠景含天空、中景/前景/道具皆洋紅底去背成透明
    /// （`isLayered`），地面平台不去背。重新排回循環，緊接開場 `meadowOrigin`/`village3`
    /// 之後（`meadowOrigin → village3 → kingdom → ……`）。
    case kingdom
    /// 海城（`design/sea_city.png`，Stage C 舊格式地域）：已被 `harbor` 取代排出 8 地域循環
    /// （第 3 波，`21` §2），case 保留（休眠、不刪）供未來重啟或参考，`assetFolder`/
    /// `PropScatter`/`RegionNpcScatter` 對應槽位表原樣保留，只是不再被 `cycle` 選到。
    case seaCity
    /// 森林樹屋村落（接手任務，2026-07-05：`design/village3_layered.png` 補上 layered 格式
    /// 美術——巨木/樹屋/繩橋/瀑布/苔蘚屋頂農舍/市集攤位，取代舊 `"village_3"` 單張
    /// backdrop），遠景含天空、中景/前景/道具皆洋紅底去背成透明（`isLayered`），地面平台
    /// 不去背。重新排回循環，緊接開場 `meadowOrigin` 之後（`meadowOrigin → village3 →
    /// kingdom → ……`）。
    case village3
    /// 浮空天空村（接手任務，2026-07-05：`design/sky_village_layered.png` 補上 layered
    /// 格式美術——漂浮小島小屋/風車/繩橋/瀑布，中景浮空平台以繩橋相連，前景小屋/市集攤位/
    /// 大樹/石橋/水井/路燈，取代舊 `"sky_village"` 單張 backdrop），遠景含天空、中景/前景/
    /// 道具皆洋紅底去背成透明（`isLayered`），地面平台不去背（含平台邊緣垂掛藤蔓）。重新
    /// 排回循環（`futureCity` 之後、`mountainPalace` 之前，作為進入浮空天界群島序列的
    /// 入口）。
    case skyVillage
    /// 白金浮空天空之城（接手任務，2026-07-05：`design/sky_layered.png` 補上 layered 格式
    /// 美術——漂浮宮殿島/瀑布/飛船/牌樓拱門/停泊飛船碼頭/水晶，取代舊 `"sky_city"` 單張
    /// backdrop），遠景含天空、中景/前景/道具皆洋紅底去背成透明（`isLayered`），地面平台
    /// 不去背。重新排回循環最尾端（壓軸地域，`…… → holyCity → skyCity`）。
    case skyCity
    /// 海港（`design/harbor_test.png`，`20_ASSET_SHEET_SPEC.md` §8A「洋紅去背 + 真多層視差」
    /// 美術流程驗證地域，已驗證通過）：只有遠景含天空，中景/前景/道具皆洋紅底去背成透明，
    /// 疊出真正的多層視差（`isLayered`）。取代 `seaCity` 排進循環（`cycle`）。
    case harbor
    /// 溫泉山村（`design/hotspring_village.png`，接手任務：把 harbor 驗證過的「洋紅去背 +
    /// 真多層視差」管線推廣到第二個 layered 地域）：日式溫泉山村，遠景含天空、中景/前景/
    /// 道具皆洋紅底去背成透明（`isLayered`），地面平台不去背。排進循環，銜接村莊 B 與海港
    /// 之間（森林村落 → 溫泉山村 → 海港，山村↔山谷↔海港的地形過渡自然）。
    case hotspringVillage
    /// 仙俠山宮（`design/mountain_palace.png`，接手任務：把 hotspring 驗證過的「洋紅去背 +
    /// 真多層視差」管線推廣到第三個 layered 地域）：飄浮雲海間的仙俠宮闕，遠景含天空、
    /// 中景/前景/道具皆洋紅底去背成透明（`isLayered`），地面平台不去背。排進循環，銜接
    /// 天空村莊與天空魔法城之間（同屬「天界」奇幻序列，天空村莊 → 仙俠山宮 → 天空魔法城，
    /// 由飄浮平台迴廊過渡到仙俠宮闕、再到魔法水晶城，奇幻濃度依序遞增）。
    case mountainPalace
    /// 雪山王國（`design/snow_mountain.png`，接手任務：把 hotspring/mountain_palace 驗證過的
    /// 「洋紅去背 + 真多層視差」管線推廣到第四個 layered 地域）：歐式中世紀奇幻雪山王國，
    /// 石造拱門城牆/藍色紋章旗/雪中廢墟塔樓/吊橋/火把，遠景含天空、中景/前景/道具皆洋紅底
    /// 去背成透明（`isLayered`），地面平台不去背。排進循環，銜接海港與天空村莊之間
    /// （海港 → 雪山王國 → 天空村莊，由現實海港過渡到中世紀奇幻雪山、再銜接飄浮天界序列）。
    case snowMountain
    /// 蒸氣龐克飛船城（`design/steampunk_city.png`，接手任務：把 holy_city 驗證過的
    /// 「洋紅去背 + 真多層視差」管線推廣到第七個 layered 地域）：黃銅飛船城，飛船/鐘塔/
    /// 煙囪/蒸汽火車頭/瓦斯燈/齒輪/黃銅儀表/望遠鏡/十字旗幟，暖黃銅金工業色調，遠景含
    /// 天空、中景/前景/道具皆洋紅底去背成透明（`isLayered`），地面平台不去背。排進循環，
    /// 銜接雪山王國與天空村莊之間（雪山王國 → 蒸氣龐克飛船城 → 天空村莊，工業飛船城作為
    /// 銜接中世紀奇幻雪山與飄浮天界序列之間的過渡——齒輪與蒸汽動力把旅人送上天空）。
    case steampunkCity
    /// 賽博龐克霓虹夜城（`design/future_city.png`，接手任務：把 steampunk_city 驗證過的
    /// 「洋紅去背 + 真多層視差」管線推廣到第八個 layered 地域）：懸浮載具/霓虹全息廣告牌/
    /// 懸浮平台/全息地球儀/水晶/霓虹櫻花樹/咖啡廳與大門招牌，冷紫藍霓虹夜色調，遠景含
    /// 天空、中景/前景/道具皆洋紅底去背成透明（`isLayered`），地面平台不去背。排進循環，
    /// 銜接蒸氣龐克飛船城與天空村莊之間（蒸氣龐克飛船城 → 賽博龐克霓虹夜城 → 天空村莊，
    /// 兩座科技感城市相鄰成群，再過渡到飄浮天界序列作為寧靜的收尾對比）。
    case futureCity
    /// 浮空魔法之城（`design/magic_city.png`，接手任務：把 hotspring/mountain_palace 驗證過的
    /// 「洋紅去背 + 真多層視差」管線推廣到第五個 layered 地域）：漂浮魔法之城，穹頂尖塔/
    /// 水晶噴泉/符文法陣/藍金紋章，遠景含天空、中景/前景/道具皆洋紅底去背成透明
    /// （`isLayered`），地面平台不去背。排進循環，銜接仙俠山宮與天空魔法城之間
    /// （仙俠山宮 → 浮空魔法之城 → 天空魔法城，天界奇幻濃度依序遞增到最高點）。
    case magicCity
    /// 聖光之城（`design/holy_city.png`，接手任務：把 magic_city 驗證過的「洋紅去背 +
    /// 真多層視差」管線推廣到第六個 layered 地域）：歐式高奇幻聖光之城，白金聖堂/
    /// 天使雕像/鐘塔拱門/十字紋章旗/玫瑰花窗/噴泉/燭台，遠景含天空、中景/前景/道具皆
    /// 洋紅底去背成透明（`isLayered`），地面平台不去背。排進循環，銜接浮空魔法之城與
    /// 天空魔法城之間（浮空魔法之城 → 聖光之城 → 天空魔法城，天界奇幻＋聖光神聖感
    /// 依序遞增到最高點，收束整個「天界」序列）。
    case holyCity

    /// 美術大改版第 2 波上線序列（`21` §2，第 3 波以 harbor 取代 seaCity；接手任務新增
    /// hotspringVillage、mountainPalace、再新增 snowMountain、magicCity、holyCity、
    /// 再新增 steampunkCity、再新增 futureCity；後續接手任務移除 village2/valley；
    /// 再接手任務把 meadowOrigin 重新指回 layered 美術、排回循環最前面當開場地域；
    /// 再接手任務把 kingdom/village3 重新指回 layered 美術、排回循環緊接開場之後；
    /// 再接手任務把 skyVillage 重新指回 layered 美術、排回循環 futureCity 之後）：
    /// 13 地域循環，旅程節奏由近人到奇幻——
    /// 草原（開場）→ 森林樹屋村落 → 王國首都 → 溫泉山村 → 海港 → 雪山王國 →
    /// 蒸氣龐克飛船城 → 賽博龐克霓虹夜城 → 浮空天空村 → 仙俠山宮 → 浮空魔法之城 →
    /// 聖光之城 → 白金浮空天空之城（壓軸）→（回到草原）。兩座科技感城市（蒸氣龐克飛船城、
    /// 賽博龐克霓虹夜城）相鄰成群，之後進入飄浮天界序列（浮空天空村起），一路遞增到
    /// 白金浮空天空之城作為整趟旅程的壓軸終章。
    /// `seaCity` 保留 case（休眠，不再進入循環，供未來重啟或参考）。其餘骨架 case
    /// （riverlands/highlands/coastalReach）保留給未來地域，暫不進入 `at(bandIndex:)` 的循環。
    private static let cycle: [RegionType] = [
        .meadowOrigin, .village3, .kingdom, .hotspringVillage, .harbor, .snowMountain, .steampunkCity, .futureCity, .skyVillage, .mountainPalace, .magicCity, .holyCity, .skyCity,
    ]

    fileprivate static func at(bandIndex: Int) -> RegionType {
        let count = cycle.count
        let normalized = ((bandIndex % count) + count) % count
        return cycle[normalized]
    }

    /// 地域對應的美術資源夾名稱（`Resources/art/regions/<name>/`，`18` §1 / `19` §1 /
    /// `21` §4）：`ParallaxBackground`/`PropScatter` 依此挑該地域的背景/地面/道具。
    /// 尚無美術的骨架地域（riverlands/highlands/coastalReach）暫時歸類回 grassland 資源夾；
    /// `Region.at` 目前不會選到它們（`cycle` 不含這三個），這裡只是保底、避免未來誤用時
    /// 找不到資源夾。
    ///
    /// **美術大改版第 1 波**（`21_ASSET_OVERHAUL_PLAN.md` §4）：`meadowOrigin` 曾改指到
    /// `"grassland"`（舊「單 backdrop」草原美術）。**接手任務（2026-07-05）**：改指到新
    /// layered 資源夾 `"meadow_village"`（`design/village_layered.png` 切出，
    /// `scripts/slice_assets.py` 的 `slice_meadow_village_bg`/`slice_meadow_village_props`），
    /// 讓開場地域也有 mid/fore 真多層視差，角色不再浮空。
    ///
    /// **再接手任務（2026-07-05）**：`kingdom` 改指到新 layered 資源夾 `"kingdom_city"`
    /// （`design/city_layered_1.png` 切出，取代舊 `"kingdom"` 單張背景）；`village3` 改指到
    /// 新 layered 資源夾 `"tree_village"`（`design/village3_layered.png` 切出，取代舊
    /// `"village_3"` 單張背景）。`riverlands`/`highlands`/`coastalReach` 骨架 case 仍暫時
    /// 歸類回 `"grassland"`（尚無專屬美術）。`RegionType` 的 case 名稱本身保留 `meadowOrigin`/
    /// `kingdom`/`village3`（沿用既有測試/呼叫端命名，不做無謂 churn），只換它們指向的資源夾。
    public var assetFolder: String {
        switch self {
        case .kingdom: return "kingdom_city"
        case .seaCity: return "sea_city"
        case .meadowOrigin: return "meadow_village"
        case .riverlands, .highlands, .coastalReach: return "grassland"
        case .village3: return "tree_village"
        case .skyVillage: return "sky_village_v2"
        case .skyCity: return "sky_city_v2"
        case .harbor: return "harbor"
        case .hotspringVillage: return "hotspring_village"
        case .mountainPalace: return "mountain_palace"
        case .snowMountain: return "snow_mountain"
        case .steampunkCity: return "steampunk_city"
        case .futureCity: return "future_city"
        case .magicCity: return "magic_city"
        case .holyCity: return "holy_city"
        }
    }

    /// 「真多層視差」地域集合（`20_ASSET_SHEET_SPEC.md` §8A 新美術流程）：這些地域的
    /// mid/fore 素材是**透明去背過的獨立物件層**（非各自含天空的完整場景），
    /// `ParallaxBackground.buildRegion` 才會真的疊出 far+mid+fore+ground 四層。其餘地域仍是
    /// 舊格式（mid/fore 各自畫了整片天空，直接疊圖會露出多條天空線），維持「只渲染
    /// far+ground」的過渡 workaround。目前有 `meadowOrigin`/`village3`/`kingdom`/`harbor`/
    /// `hotspringVillage`/`mountainPalace`/`snowMountain`/`steampunkCity`/`futureCity`/
    /// `skyVillage`/`magicCity`/`holyCity`/`skyCity`（皆已排進循環）。
    private static let layeredRegions: Set<RegionType> = [.meadowOrigin, .village3, .kingdom, .harbor, .hotspringVillage, .mountainPalace, .snowMountain, .steampunkCity, .futureCity, .skyVillage, .magicCity, .holyCity, .skyCity]

    /// 本地域是否用新版「真多層視差」美術格式（見 `layeredRegions` 說明）。
    public var isLayered: Bool { RegionType.layeredRegions.contains(self) }
}

/// Region 選擇（純函式）：`bandIndex = floor(distance / regionLength)` + 確定性序列。
public enum Region {

    /// 每地域里程長（`18` §2）：172800（≈4h/地域），旅人約 4h 後走進王國、再 4h 回草原……無盡交替。
    public static let regionLength: Double = 172_800

    /// Blend Zone 總寬（`18` §3）：地域邊界前後各半（`blendWidth / 2`）內漸變 crossfade，
    /// 邊界本身恰為兩地域各半（t=0.5），無 jolt。
    public static let blendWidth: Double = 15_000

    /// `bandIndex = floor(distance / regionLength)`。
    public static func bandIndex(atDistance distance: Double) -> Int {
        Int(floor(distance / regionLength))
    }

    /// 依 distance 算出目前地域（確定性、只看 distance）。
    public static func at(distance: Double) -> RegionType {
        RegionType.at(bandIndex: bandIndex(atDistance: distance))
    }

    /// Blend Zone crossfade 進度（純函式，`18` §3）：地域邊界前後 `blendWidth / 2` 內，
    /// `from` 為邊界前地域、`to` 為邊界後地域、`t` 由 0（進入 zone）平滑升到 1（離開 zone）、
    /// 邊界本身恰為 t=0.5（兩地域各半，crossfade 對稱、無 jolt）。
    /// Zone 外回傳 `from == to == Region.at(distance:)`、`t == 0`（呼叫端只需渲染 `from`）。
    public struct Blend: Equatable {
        public let from: RegionType
        public let to: RegionType
        public let t: Double

        public init(from: RegionType, to: RegionType, t: Double) {
            self.from = from
            self.to = to
            self.t = t
        }
    }

    public static func blend(atDistance distance: Double) -> Blend {
        let halfWidth = blendWidth / 2.0
        let current = at(distance: distance)

        // 找出最接近的地域邊界（regionLength 的整數倍）；只有落在該邊界 ±halfWidth 內才算進入 Blend Zone。
        let nearestBoundaryIndex = (distance / regionLength).rounded()
        let boundaryDistance = nearestBoundaryIndex * regionLength

        // distance=0 是旅程起點，不存在「邊界前的地域」，不做 blend（`18` §3 Blend Zone 外無 blend）。
        guard boundaryDistance > 0 else {
            return Blend(from: current, to: current, t: 0)
        }

        let offset = distance - boundaryDistance
        guard abs(offset) <= halfWidth else {
            return Blend(from: current, to: current, t: 0)
        }

        let boundaryBandIndex = Int(nearestBoundaryIndex)
        let before = RegionType.at(bandIndex: boundaryBandIndex - 1)
        let after = RegionType.at(bandIndex: boundaryBandIndex)
        let t = max(0.0, min(1.0, (offset + halfWidth) / (2 * halfWidth)))
        return Blend(from: before, to: after, t: t)
    }
}
