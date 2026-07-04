import Foundation

/// Region skeleton（`16_STAGE_A_SPEC.md` §2.3b，Stage B 擴充見 `18_STAGE_B_SPEC.md` §2，
/// Stage C 擴充見 `19_STAGE_C_SPEC.md` §2）：薄骨架，為地域美術預留掛點。
/// `riverlands`/`highlands` 尚無美術，保留骨架供未來地域擴充；
/// **目前上線的序列是 `meadowOrigin` → `kingdom` → `seaCity` 三地域循環**。
/// 純函式、確定性，可測。
public enum RegionType: Equatable, CaseIterable {
    case meadowOrigin
    case riverlands
    case highlands
    case coastalReach
    case kingdom
    case seaCity

    /// Stage C 上線序列（`19` §2）：meadow → kingdom → seaCity 三個有美術的地域循環；
    /// 其餘骨架 case 保留給未來地域，暫不進入 `at(bandIndex:)` 的循環。
    /// `coastalReach` 骨架 case 沿用既有命名保留給未來地域，跟新上線的 `seaCity`（港口海城，
    /// 有實際美術）是兩個不同的 case，避免語意混淆、也不影響既有測試對骨架 case 的引用。
    private static let cycle: [RegionType] = [.meadowOrigin, .kingdom, .seaCity]

    fileprivate static func at(bandIndex: Int) -> RegionType {
        let count = cycle.count
        let normalized = ((bandIndex % count) + count) % count
        return cycle[normalized]
    }

    /// 地域對應的美術資源夾名稱（`Resources/art/regions/<name>/`，`18` §1 / `19` §1）：
    /// `ParallaxBackground`/`PropScatter` 依此挑該地域的背景/地面/道具。尚無美術的骨架地域
    /// （riverlands/highlands/coastalReach）暫時歸類回 meadow 資源夾；`Region.at` 目前不會選到
    /// 它們（`cycle` 只有 meadow/kingdom/seaCity），這裡只是保底、避免未來誤用時找不到資源夾。
    public var assetFolder: String {
        switch self {
        case .kingdom: return "kingdom"
        case .seaCity: return "sea_city"
        case .meadowOrigin, .riverlands, .highlands, .coastalReach: return "meadow"
        }
    }
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
