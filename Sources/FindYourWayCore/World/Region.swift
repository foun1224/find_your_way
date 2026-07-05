import Foundation

/// Region skeleton（`16_STAGE_A_SPEC.md` §2.3b，Stage B 擴充見 `18_STAGE_B_SPEC.md` §2，
/// Stage C 擴充見 `19_STAGE_C_SPEC.md` §2，美術大改版第 2 波擴充見
/// `21_ASSET_OVERHAUL_PLAN.md` §2/§4）：薄骨架，為地域美術預留掛點。
/// `riverlands`/`highlands`/`coastalReach` 尚無美術，保留骨架供未來地域擴充；
/// **目前上線的序列是 12 地域循環**（`21` §2，第 3 波以 harbor 取代 seaCity；接手任務新增
/// hotspringVillage、mountainPalace、再新增 snowMountain、magicCity）：
/// `grassland → village2 → valley → kingdom → village3 → hotspringVillage → harbor →
/// snowMountain → skyVillage → mountainPalace → magicCity → skyCity`。
/// 純函式、確定性，可測。
public enum RegionType: Equatable, CaseIterable {
    case meadowOrigin
    case riverlands
    case highlands
    case coastalReach
    case kingdom
    /// 海城（`design/sea_city.png`，Stage C 舊格式地域）：已被 `harbor` 取代排出 8 地域循環
    /// （第 3 波，`21` §2），case 保留（休眠、不刪）供未來重啟或参考，`assetFolder`/
    /// `PropScatter`/`RegionNpcScatter` 對應槽位表原樣保留，只是不再被 `cycle` 選到。
    case seaCity
    /// 村莊 A（`design/village_2.png`，田園河谷村落：風車/石橋/市集），美術大改版第 2 波新增。
    case village2
    /// 山谷（`design/valley.png`，浮空峽谷奇幻科技風），美術大改版第 2 波新增。
    case valley
    /// 村莊 B（`design/village_3.png`，森林樹屋村落），美術大改版第 2 波新增。
    case village3
    /// 天空村莊（`design/sky_village.png`，浮空平台迴廊），美術大改版第 2 波新增。
    case skyVillage
    /// 天空魔法城（`design/sky_city_magic.png`，金色魔法水晶城），美術大改版第 2 波新增。
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
    /// 浮空魔法之城（`design/magic_city.png`，接手任務：把 hotspring/mountain_palace 驗證過的
    /// 「洋紅去背 + 真多層視差」管線推廣到第五個 layered 地域）：漂浮魔法之城，穹頂尖塔/
    /// 水晶噴泉/符文法陣/藍金紋章，遠景含天空、中景/前景/道具皆洋紅底去背成透明
    /// （`isLayered`），地面平台不去背。排進循環，銜接仙俠山宮與天空魔法城之間
    /// （仙俠山宮 → 浮空魔法之城 → 天空魔法城，天界奇幻濃度依序遞增到最高點）。
    case magicCity

    /// 美術大改版第 2 波上線序列（`21` §2，第 3 波以 harbor 取代 seaCity；接手任務新增
    /// hotspringVillage、mountainPalace、再新增 snowMountain、magicCity）：12 地域循環，
    /// 旅程節奏由近人到奇幻——草原 → 村莊A → 山谷 → 王國 → 村莊B → 溫泉山村 → 海港 →
    /// 雪山王國 → 天空村莊 → 仙俠山宮 → 浮空魔法之城 → 天空魔法城 →（回到草原）。
    /// `seaCity` 保留 case（休眠，不再進入循環，供未來重啟或参考）。其餘骨架 case
    /// （riverlands/highlands/coastalReach）保留給未來地域，暫不進入 `at(bandIndex:)` 的循環。
    private static let cycle: [RegionType] = [
        .meadowOrigin, .village2, .valley, .kingdom, .village3, .hotspringVillage, .harbor, .snowMountain, .skyVillage, .mountainPalace, .magicCity, .skyCity,
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
    /// **美術大改版第 1 波**（`21_ASSET_OVERHAUL_PLAN.md` §4）：`meadowOrigin` 改指到
    /// `"grassland"`（取代舊 `"meadow"` 資源夾，`design/grassland.png` 切出的新草原美術，
    /// `scripts/slice_assets.py` 的 `slice_grassland_props`）。`RegionType` 的 case 名稱本身
    /// 保留 `meadowOrigin`（沿用既有測試/呼叫端命名，不做無謂 churn），只換它指向的資源夾。
    public var assetFolder: String {
        switch self {
        case .kingdom: return "kingdom"
        case .seaCity: return "sea_city"
        case .meadowOrigin, .riverlands, .highlands, .coastalReach: return "grassland"
        case .village2: return "village_2"
        case .valley: return "valley"
        case .village3: return "village_3"
        case .skyVillage: return "sky_village"
        case .skyCity: return "sky_city"
        case .harbor: return "harbor"
        case .hotspringVillage: return "hotspring_village"
        case .mountainPalace: return "mountain_palace"
        case .snowMountain: return "snow_mountain"
        case .magicCity: return "magic_city"
        }
    }

    /// 「真多層視差」地域集合（`20_ASSET_SHEET_SPEC.md` §8A 新美術流程）：這些地域的
    /// mid/fore 素材是**透明去背過的獨立物件層**（非各自含天空的完整場景），
    /// `ParallaxBackground.buildRegion` 才會真的疊出 far+mid+fore+ground 四層。其餘地域仍是
    /// 舊格式（mid/fore 各自畫了整片天空，直接疊圖會露出多條天空線），維持「只渲染
    /// far+ground」的過渡 workaround。目前有 `harbor`/`hotspringVillage`/`mountainPalace`/
    /// `snowMountain`/`magicCity`（皆已排進循環）。
    private static let layeredRegions: Set<RegionType> = [.harbor, .hotspringVillage, .mountainPalace, .snowMountain, .magicCity]

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
