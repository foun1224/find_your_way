import XCTest
@testable import FindYourWayCore

final class CharacterHitTestTests: XCTestCase {

    private let characterScreenX = 80.0
    private let characterScreenY = 40.0
    private let characterSize = CGSize(width: 30, height: 44)
    private let sceneSize = CGSize(width: 320, height: 180)

    func testCenterOfCharacterIsHit() {
        let point = CGPoint(x: characterScreenX, y: characterScreenY + characterSize.height / 2)
        XCTAssertTrue(CharacterHitTest.isPointOnCharacter(
            point: point,
            characterScreenX: characterScreenX,
            characterScreenY: characterScreenY,
            characterSize: characterSize,
            sceneSize: sceneSize
        ))
    }

    func testPointFarAwayIsMiss() {
        let point = CGPoint(x: 300, y: 170)
        XCTAssertFalse(CharacterHitTest.isPointOnCharacter(
            point: point,
            characterScreenX: characterScreenX,
            characterScreenY: characterScreenY,
            characterSize: characterSize,
            sceneSize: sceneSize
        ))
    }

    func testPointJustOutsideHorizontalBoundsBeyondPaddingIsMiss() {
        let farX = characterScreenX + characterSize.width / 2 + CharacterHitTest.hitPadding + 1
        let point = CGPoint(x: farX, y: characterScreenY + 10)
        XCTAssertFalse(CharacterHitTest.isPointOnCharacter(
            point: point,
            characterScreenX: characterScreenX,
            characterScreenY: characterScreenY,
            characterSize: characterSize,
            sceneSize: sceneSize
        ))
    }

    func testPointWithinPaddingJustOutsideExactBoundsIsHit() {
        // 剛好超出精確 sprite 寬度、但仍在容差內 → 依 Fitts's law 仍算命中，好點不刁鑽。
        let x = characterScreenX + characterSize.width / 2 + CharacterHitTest.hitPadding / 2
        let point = CGPoint(x: x, y: characterScreenY + 10)
        XCTAssertTrue(CharacterHitTest.isPointOnCharacter(
            point: point,
            characterScreenX: characterScreenX,
            characterScreenY: characterScreenY,
            characterSize: characterSize,
            sceneSize: sceneSize
        ))
    }

    func testPointBelowFeetIsMiss() {
        let point = CGPoint(x: characterScreenX, y: characterScreenY - CharacterHitTest.hitPadding - 1)
        XCTAssertFalse(CharacterHitTest.isPointOnCharacter(
            point: point,
            characterScreenX: characterScreenX,
            characterScreenY: characterScreenY,
            characterSize: characterSize,
            sceneSize: sceneSize
        ))
    }

    func testPointAboveHeadIsMiss() {
        let point = CGPoint(x: characterScreenX, y: characterScreenY + characterSize.height + CharacterHitTest.hitPadding + 1)
        XCTAssertFalse(CharacterHitTest.isPointOnCharacter(
            point: point,
            characterScreenX: characterScreenX,
            characterScreenY: characterScreenY,
            characterSize: characterSize,
            sceneSize: sceneSize
        ))
    }

    func testExactBoundaryEdgesAreHitInclusive() {
        let leftEdge = CGPoint(x: characterScreenX - characterSize.width / 2 - CharacterHitTest.hitPadding, y: characterScreenY)
        let rightEdge = CGPoint(x: characterScreenX + characterSize.width / 2 + CharacterHitTest.hitPadding, y: characterScreenY)
        let bottomEdge = CGPoint(x: characterScreenX, y: characterScreenY - CharacterHitTest.hitPadding)
        let topEdge = CGPoint(x: characterScreenX, y: characterScreenY + characterSize.height + CharacterHitTest.hitPadding)

        for point in [leftEdge, rightEdge, bottomEdge, topEdge] {
            XCTAssertTrue(CharacterHitTest.isPointOnCharacter(
                point: point,
                characterScreenX: characterScreenX,
                characterScreenY: characterScreenY,
                characterSize: characterSize,
                sceneSize: sceneSize
            ), "boundary point \(point) should be a hit (inclusive)")
        }
    }

    func testPointOutsideSceneBoundsIsMissEvenIfWithinCharacterMath() {
        // sceneSize 之外的點永遠不算命中，即使數學上落在角色框內（例如座標轉換誤差）。
        let point = CGPoint(x: -5, y: characterScreenY)
        XCTAssertFalse(CharacterHitTest.isPointOnCharacter(
            point: point,
            characterScreenX: characterScreenX,
            characterScreenY: characterScreenY,
            characterSize: characterSize,
            sceneSize: sceneSize
        ))
    }
}
