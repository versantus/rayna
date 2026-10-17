import XCTest
@testable import RaynaCore

/// The scene & colour pack and Rayna's colours stay hidden until released (RaynaFeatures), and work in Labs.
final class PackTests: XCTestCase {
    override func tearDown() { RaynaFeatures.labs = false; RaynaFrames.skin = .classic }

    private func extras() -> RaynaExtras {
        let d = UserDefaults(suiteName: "rayna-pack-tests")!
        d.removePersistentDomain(forName: "rayna-pack-tests")
        return RaynaExtras(defaults: d)
    }

    func testThePackIsHiddenUntilReleased() {
        RaynaFeatures.labs = false
        XCTAssertFalse(RaynaFeatures.scenePack || RaynaFeatures.rayColours)
        let x = extras()
        XCTAssertTrue(x.unlocked.filter(\.isPremium).isEmpty)
        x.wornBadges = [.reef]
        XCTAssertTrue(x.wornBadges.isEmpty, "can't wear a pack scene before release")
        RaynaFrames.skin = .lilac
        XCTAssertEqual(RaynaFrames.skin, .classic, "colours are off until release")
    }

    func testLabsPreviewsThePack() {
        RaynaFeatures.labs = true
        let x = extras()
        XCTAssertEqual(Set(x.unlocked.filter(\.isPremium)), [.reef, .jellies, .treasure, .turtles])
        x.wornBadges = [.jellies]
        XCTAssertEqual(x.wornBadges, [.jellies])
        RaynaFrames.skin = .midnight
        XCTAssertEqual(RaynaFrames.skin, .midnight)
    }

    func testOlderBadgesKeepTheirCodesAfterThePack() {
        XCTAssertEqual(WornBadge.code(for: .podWave), 12)
        XCTAssertEqual(WornBadge.code(for: .seabed), 13)
        XCTAssertEqual(WornBadge.code(for: .meadow), 14)
        XCTAssertEqual(Set(RaynaUnlock.allCases.filter { $0.slot == .scene }.map(\.rawValue)), Set(SeaSceneKind.allCases.map(\.rawValue)))
    }

    func testColoursOnlyChangeHerBody() {
        let teal = SIMD3<Float>(0.12, 0.62, 0.66), amber = SIMD3<Float>(0.75, 0.5, 0.15)
        let blush = SIMD3<Float>(0.95, 0.6, 0.65), cream = SIMD3<Float>(0.96, 0.94, 0.86)
        for skin in RaynaSkin.allCases where skin != .classic {
            XCTAssertNotEqual(skin.map(teal), teal, "\(skin) recolours the body")
            for keep in [amber, blush, cream] { XCTAssertEqual(skin.map(keep), keep, "\(skin) leaves eyes, blush and rim") }
        }
        XCTAssertEqual(RaynaSkin.classic.map(teal), teal)
        XCTAssertEqual(RaynaSkin.coral.cube(size: 8).count, 8 * 8 * 8 * 4 * MemoryLayout<Float>.size)
        XCTAssertEqual(RaynaSkin.allCases.filter(\.isFree), [.classic, .coral, .mint])
    }

    func testEveryPackCreatureStaysInTheWaterAndMoves() {
        let phone = CGSize(width: 390, height: 760)
        for kind in [SeaSceneKind.reef, .jellies, .treasure, .turtles] {
            for p in [0.2, 0.5, 0.9] { for t in [0.0, 4.2, 37.0, 333.3] {
                let line = SeaSceneLayout.waterline(progress: p, height: phone.height)
                for item in SeaSceneLayout.items(for: kind, progress: p, size: phone, time: t) where item.look == .sprite || item.look == .glow {
                    XCTAssertGreaterThanOrEqual(item.center.y + item.size.height / 2, line, "\(kind) \(item.sprite) under the wave")
                }
            } }
            let a = SeaSceneLayout.items(for: kind, progress: 0.6, size: phone, time: 1)
            let b = SeaSceneLayout.items(for: kind, progress: 0.6, size: phone, time: 3)
            XCTAssertNotEqual(a, b, "\(kind) animates")
            XCTAssertFalse(SeaSceneLayout.items(for: kind, progress: 0.6, size: CGSize(width: 205, height: 251), time: 1, compact: true).isEmpty)
        }
    }

    func testEveryPackSpriteShips() {
        let phone = CGSize(width: 390, height: 760)
        for kind in [SeaSceneKind.reef, .jellies, .treasure, .turtles] { for t in stride(from: 0.0, to: 40, by: 2.5) {
            for item in SeaSceneLayout.items(for: kind, progress: 0.6, size: phone, time: t) where item.look == .sprite || item.look == .glow {
                XCTAssertNotNil(SeaSprites.image(item.sprite), item.sprite)
            }
        } }
    }
}
