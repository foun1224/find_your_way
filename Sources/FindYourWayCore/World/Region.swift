import Foundation

/// Region skeleton（`16_STAGE_A_SPEC.md` §2.3b）：薄骨架，為 Stage B 美術預留掛點。
/// Stage A **不做視覺差異、不張揚 region 名**（現階段各地域仍是草原視覺，張揚會顯空）。
/// 純函式、確定性，可測。
public enum RegionType: Equatable, CaseIterable {
    case meadowOrigin
    case riverlands
    case highlands
    case coastalReach

    private static let cycle: [RegionType] = [.meadowOrigin, .riverlands, .highlands, .coastalReach]

    fileprivate static func at(bandIndex: Int) -> RegionType {
        let count = cycle.count
        let normalized = ((bandIndex % count) + count) % count
        return cycle[normalized]
    }
}

/// Region 選擇（純函式）：`bandIndex = floor(distance / regionLength)` + 確定性序列。
public enum Region {

    /// 每地域里程長（provisional，`16` §2.3b）：≈8h/地域，先設一個大值讓 Stage A 幾乎都在第一地域。
    public static let regionLength: Double = 345_600

    /// `bandIndex = floor(distance / regionLength)`。
    public static func bandIndex(atDistance distance: Double) -> Int {
        Int(floor(distance / regionLength))
    }

    /// 依 distance 算出目前地域（確定性、只看 distance）。
    public static func at(distance: Double) -> RegionType {
        RegionType.at(bandIndex: bandIndex(atDistance: distance))
    }
}
