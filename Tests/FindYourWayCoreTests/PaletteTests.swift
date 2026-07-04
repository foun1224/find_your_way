import XCTest
@testable import FindYourWayCore

final class PaletteTests: XCTestCase {

    func testParseHexWithHashPrefix() {
        let rgba = Palette.parseHex("#C56A4E")
        XCTAssertNotNil(rgba)
        XCTAssertEqual(rgba!.red, Double(0xC5) / 255.0, accuracy: 0.0001)
        XCTAssertEqual(rgba!.green, Double(0x6A) / 255.0, accuracy: 0.0001)
        XCTAssertEqual(rgba!.blue, Double(0x4E) / 255.0, accuracy: 0.0001)
        XCTAssertEqual(rgba!.alpha, 1.0, accuracy: 0.0001)
    }

    func testParseHexWithoutHashPrefix() {
        let rgba = Palette.parseHex("8FC7E8")
        XCTAssertNotNil(rgba)
        XCTAssertEqual(rgba!.red, Double(0x8F) / 255.0, accuracy: 0.0001)
        XCTAssertEqual(rgba!.green, Double(0xC7) / 255.0, accuracy: 0.0001)
        XCTAssertEqual(rgba!.blue, Double(0xE8) / 255.0, accuracy: 0.0001)
    }

    func testParseHexInvalidReturnsNil() {
        XCTAssertNil(Palette.parseHex("not-a-color"))
        XCTAssertNil(Palette.parseHex("#12345"))
        XCTAssertNil(Palette.parseHex("#GGGGGG"))
    }

    func testTravelerTerracottaMatchesSpecHex() {
        XCTAssertEqual(Palette.travelerTerracotta, Palette.parseHex("#C56A4E"))
    }

    func testKeyPaletteValues() {
        XCTAssertEqual(Palette.skyAzure, Palette.parseHex("#8FC7E8"))
        XCTAssertEqual(Palette.meadowGreen, Palette.parseHex("#7FB069"))
        XCTAssertEqual(Palette.cloudCream, Palette.parseHex("#F5EFE0"))
        XCTAssertEqual(Palette.inkUmber, Palette.parseHex("#3A3330"))
    }

    func testSceneryContrastColors() {
        XCTAssertEqual(Palette.pineShadow, Palette.parseHex("#4C8054"))
        XCTAssertEqual(Palette.trailOchre, Palette.parseHex("#C9A36B"))
    }
}
