import Foundation

/// 季節系統（`16_STAGE_A_SPEC.md` §1）：純函式，`Season = f(distance)`。**不 import SpriteKit**，
/// 只回傳 `Palette.RGBA`，由 `GameScene` 套到 overlay 節點的 color/alpha（同 `DayNightCycle` 範式）。
/// 確定性、只看里程，不看牆鐘——離線可重現。
public enum Season: Equatable, CaseIterable {
    case spring
    case summer
    case autumn
    case winter

    /// 每季里程長（provisional，`16` §1.1）：≈2h travel @P1；一整年 = 4× ≈ 8h。
    public static let seasonLength: Double = 86_400

    /// 依 `Season.allCases` 順序排列的循環序列（春→夏→秋→冬→春…），`distance 0` 從春天啟程。
    private static let cycle: [Season] = [.spring, .summer, .autumn, .winter]

    /// `index = floor(distance / seasonLength) mod 4`。負值 distance（理論上不會發生，但求穩健）
    /// 以 Swift 的 `truncatingRemainder` 需另行修正為非負餘數。
    public static func at(distance: Double) -> Season {
        let rawIndex = Int(floor(distance / seasonLength))
        let count = cycle.count
        let normalized = ((rawIndex % count) + count) % count
        return cycle[normalized]
    }

    /// 每季 authored 色調：不透明色 + overlay alpha（`16` §1.2 表）。
    private var tintColor: Palette.RGBA {
        switch self {
        case .spring: return Palette.parseHex("#9FD68A")!
        case .summer: return Palette.parseHex("#F2CE73")!
        case .autumn: return Palette.parseHex("#E0A257")!
        case .winter: return Palette.parseHex("#BFD2E6")!
        }
    }

    private var tintAlpha: Double {
        switch self {
        case .spring: return 0.14
        case .summer: return 0.10
        case .autumn: return 0.18
        case .winter: return 0.20
        }
    }

    /// 下一個季節（用於交界插值）。
    private var next: Season {
        let count = Self.cycle.count
        guard let idx = Self.cycle.firstIndex(of: self) else { return self }
        return Self.cycle[(idx + 1) % count]
    }

    /// 交界模糊帶寬度（里程）：在每季結束前這段距離內，開始朝下一季線性插值，
    /// 慢、無跳變（同 `DayNightCycle` 的 keyframe 插值範式）。
    private static let blendZone: Double = seasonLength * 0.25

    /// 依 distance 算出目前 tint：季節中段為純該季色，交界前 `blendZone` 里程內
    /// 向下一季線性插值，確保連續、不跳變。
    public static func tint(atDistance distance: Double) -> Palette.RGBA {
        let length = seasonLength
        let rawIndex = Int(floor(distance / length))
        let count = cycle.count
        let normalizedIndex = ((rawIndex % count) + count) % count
        let current = cycle[normalizedIndex]

        // 該季節內的相對位置 [0, length)。
        let seasonStart = Double(rawIndex) * length
        let intoSeasons = distance - seasonStart

        let blendStart = length - blendZone
        guard intoSeasons > blendStart else {
            return current.color(atAlpha: current.tintAlpha)
        }

        let u = min(1.0, (intoSeasons - blendStart) / blendZone)
        let next = current.next
        return interpolate(from: current, to: next, u: u)
    }

    private func color(atAlpha alpha: Double) -> Palette.RGBA {
        Palette.RGBA(red: tintColor.red, green: tintColor.green, blue: tintColor.blue, alpha: alpha)
    }

    private static func interpolate(from a: Season, to b: Season, u: Double) -> Palette.RGBA {
        let ac = a.tintColor
        let bc = b.tintColor
        let aAlpha = a.tintAlpha
        let bAlpha = b.tintAlpha
        return Palette.RGBA(
            red: ac.red + (bc.red - ac.red) * u,
            green: ac.green + (bc.green - ac.green) * u,
            blue: ac.blue + (bc.blue - ac.blue) * u,
            alpha: aAlpha + (bAlpha - aAlpha) * u
        )
    }
}
