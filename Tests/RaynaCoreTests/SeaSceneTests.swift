import SwiftUI
import XCTest
@testable import RaynaCore

final class SeaSceneTests: XCTestCase {
    private let phone = CGSize(width: 390, height: 760)
    private let scenes: [RaynaUnlock] = [.surge, .tide, .flood, .podWave]
    private let levels = [0.0, 0.15, 0.5, 0.95, 1.2]
    private let times = [0.0, 3.7, 41.0, 600.5]

    private func waterline(_ p: Double) -> CGFloat { WaterBackground.waterline(progress: p, height: phone.height) }

    func testTheWatchUsesTheSameWaterline() {
        for p in levels { for h in [200.0, 514.0, 760.0] {
            XCTAssertEqual(SeaSceneLayout.waterline(progress: p, height: h), WaterBackground.waterline(progress: p, height: h))
        } }
        XCTAssertEqual(Set(SeaSceneKind.allCases.map(\.rawValue)), Set(RaynaUnlock.allCases.filter { $0.slot == .scene }.map(\.rawValue)))
    }

    func testOnlySceneBadgesDrawAnything() {
        for u in RaynaUnlock.allCases where u.slot != .scene {
            XCTAssertTrue(SeaSceneLayout.items(for: u, progress: 0.5, size: phone, time: 0).isEmpty, u.rawValue)
        }
        for s in scenes {
            XCTAssertFalse(SeaSceneLayout.items(for: s, progress: 0.5, size: phone, time: 0).isEmpty, s.rawValue)
            XCTAssertNotNil(SeaSceneLayout.mark(s))
        }
    }

    func testSwimmersStayUnderTheWater() {
        for s in [RaynaUnlock.surge, .podWave] {
            for p in levels { for t in times {
                for item in SeaSceneLayout.items(for: s, progress: p, size: phone, time: t) {
                    XCTAssertGreaterThanOrEqual(item.center.y - item.size.height / 2, waterline(p), "\(s) \(p) \(t)")
                }
            } }
        }
    }

    func testPlantsNeverGrowAboveTheWater() {
        for p in levels { for t in times {
            for item in SeaSceneLayout.items(for: RaynaUnlock.flood, progress: p, size: phone, time: t) {
                XCTAssertLessThanOrEqual(item.size.height, phone.height - waterline(p) + 0.5, "\(p)")
                XCTAssertEqual(item.center.y + item.size.height / 2, phone.height + 4, accuracy: 0.01, "rooted on the seabed")
            }
        } }
        let low = SeaSceneLayout.items(for: RaynaUnlock.flood, progress: 0.1, size: phone, time: 0).map(\.size.height).max()!
        let high = SeaSceneLayout.items(for: RaynaUnlock.flood, progress: 0.9, size: phone, time: 0).map(\.size.height).max()!
        XCTAssertGreaterThan(high, low * 2, "more water, taller kelp")
    }

    func testTheMoonNeedsSky() {
        let size = phone
        let moon = { (p: Double) in SeaSceneLayout.items(for: RaynaUnlock.tide, progress: p, size: size, time: 0).first { $0.sprite == "moon" } }
        let half = try? XCTUnwrap(moon(0.5))
        XCTAssertLessThan((half?.center.y ?? .infinity) + (half?.size.height ?? 0) / 2, waterline(0.5))
        XCTAssertNil(moon(0.95), "no sky left at the top")
        XCTAssertEqual(SeaSceneLayout.items(for: RaynaUnlock.tide, progress: 0.95, size: phone, time: 0).count, 3, "shells stay on the sand")
    }

    func testCompactKeepsTheMoonAndSandClearOfTheWatchText() {
        let watch = CGSize(width: 205, height: 251)
        let items = SeaSceneLayout.items(for: SeaSceneKind.tide, progress: 0.3, size: watch, time: 0, compact: true)
        let moon = items.first { $0.sprite == "moon" }!
        XCTAssertGreaterThan(moon.center.x - moon.size.width / 2, watch.width * 0.78, "beside the centred litres line")
        XCTAssertTrue(items.filter { $0.sprite != "moon" }.allSatisfy { $0.center.x < watch.width * 0.2 || $0.center.x > watch.width * 0.8 })
    }

    func testShallowWaterHasFewerSwimmers() {
        XCTAssertEqual(SeaSceneLayout.items(for: RaynaUnlock.surge, progress: 0.15, size: phone, time: 0).count, 2)
        XCTAssertEqual(SeaSceneLayout.items(for: RaynaUnlock.surge, progress: 0.6, size: phone, time: 0).count, 4)
        XCTAssertEqual(SeaSceneLayout.items(for: RaynaUnlock.podWave, progress: 0.15, size: phone, time: 0).count, 2)
        XCTAssertEqual(SeaSceneLayout.items(for: RaynaUnlock.podWave, progress: 0.6, size: phone, time: 0).count, 3)
    }

    func testItMovesOverTimeAndHoldsStillAtOneMoment() {
        for s in scenes {
            let a = SeaSceneLayout.items(for: s, progress: 0.6, size: phone, time: 0)
            XCTAssertEqual(a, SeaSceneLayout.items(for: s, progress: 0.6, size: phone, time: 0), "\(s) is deterministic")
            XCTAssertNotEqual(a, SeaSceneLayout.items(for: s, progress: 0.6, size: phone, time: 2.5), "\(s) animates")
        }
    }

    func testEverySpriteShipsWithTheApp() {
        for s in scenes { for p in [0.1, 0.6] {
            for item in SeaSceneLayout.items(for: s, progress: p, size: phone, time: 0) {
                XCTAssertNotNil(SeaSprites.image(item.sprite), item.sprite)
            }
        } }
    }

    /// RAYNA_SCENE_FRAMES=<dir> swift test --filter SeaSceneTests/testRenderFrames
    /// writes frames of each scene at 50% for a preview; skipped otherwise.
    @MainActor func testRenderFrames() throws {
        guard let dir = ProcessInfo.processInfo.environment["RAYNA_SCENE_FRAMES"] else { throw XCTSkip("set RAYNA_SCENE_FRAMES") }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let pack = ProcessInfo.processInfo.environment["RAYNA_SCENE_PACK"] == "1"
        let list: [RaynaUnlock] = pack ? [.reef, .jellies, .treasure, .turtles] : scenes
        let only = ProcessInfo.processInfo.environment["RAYNA_SCENE_ONLY"].flatMap(RaynaUnlock.init(rawValue:))
        let fps = Double(ProcessInfo.processInfo.environment["RAYNA_SCENE_FPS"] ?? "12") ?? 12
        let frames = pack ? Int(fps * 12) : 48     // pack: 12 s, to show the variety
        for s in list where only == nil || only == s {
            for (n, p) in (pack ? [0.45, 0.85] : [0.15, 0.5, 0.9]).enumerated() {
                for f in 0..<frames {
                    var scene = SeaScene(scene: s, progress: p)
                    scene.frozenTime = Double(f) / (pack ? fps : 12)
                    let r = ImageRenderer(content: scene.frame(width: 390, height: 760))
                    r.scale = 1
                    guard let cg = r.cgImage else { continue }
                    let url = URL(fileURLWithPath: dir).appendingPathComponent("\(s.rawValue)-\(n)-\(String(format: "%03d", f)).png")
                    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
                    CGImageDestinationAddImage(dest, cg, nil)
                    CGImageDestinationFinalize(dest)
                }
            }
        }
    }
}
