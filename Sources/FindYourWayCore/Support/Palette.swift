import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(SpriteKit)
import SpriteKit
#endif

/// 色盤（`03_DESIGN_SYSTEM.md` §1.2）。
/// 提供 HEX 字串解析工具，以及 Phase 1 需要的關鍵色常數。
public enum Palette {

    /// RGBA 分量（0.0–1.0）。
    public struct RGBA: Equatable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public let alpha: Double

        public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
    }

    /// 解析 `#RRGGBB` 或 `RRGGBB` 格式的 HEX 字串為 RGBA 分量。
    /// 格式不正確時回傳 nil。
    public static func parseHex(_ hex: String) -> RGBA? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let intValue = UInt32(value, radix: 16) else {
            return nil
        }
        let r = Double((intValue >> 16) & 0xFF) / 255.0
        let g = Double((intValue >> 8) & 0xFF) / 255.0
        let b = Double(intValue & 0xFF) / 255.0
        return RGBA(red: r, green: g, blue: b, alpha: 1.0)
    }

    // MARK: - 色盤常數（HEX，`03` §1.2）

    public static let travelerTerracottaHex = "#C56A4E"
    public static let skyAzureHex = "#8FC7E8"
    public static let meadowGreenHex = "#7FB069"
    public static let cloudCreamHex = "#F5EFE0"
    public static let inkUmberHex = "#3A3330"

    public static var travelerTerracotta: RGBA { parseHex(travelerTerracottaHex)! }
    public static var skyAzure: RGBA { parseHex(skyAzureHex)! }
    public static var meadowGreen: RGBA { parseHex(meadowGreenHex)! }
    public static var cloudCream: RGBA { parseHex(cloudCreamHex)! }
    public static var inkUmber: RGBA { parseHex(inkUmberHex)! }
}

#if canImport(AppKit)
public extension Palette.RGBA {
    /// 轉為 `NSColor`。
    var nsColor: NSColor {
        NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
}

public extension Palette {
    static var travelerTerracottaColor: NSColor { travelerTerracotta.nsColor }
    static var skyAzureColor: NSColor { skyAzure.nsColor }
    static var meadowGreenColor: NSColor { meadowGreen.nsColor }
    static var cloudCreamColor: NSColor { cloudCream.nsColor }
    static var inkUmberColor: NSColor { inkUmber.nsColor }
}
#endif

#if canImport(SpriteKit)
public extension Palette.RGBA {
    /// 轉為 `SKColor`（macOS 上等同 `NSColor`）。
    var skColor: SKColor {
        SKColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
}
#endif
