import XCTest
@testable import RaynaCore

final class AnchorTests: XCTestCase {
    private func rows(_ name: String) throws -> [RaynaSlotPoses] {
        let root = try XCTUnwrap(RaynaFrames.root, "RaynaFrames resources not found")
        let data = try Data(contentsOf: root.appendingPathComponent("anchors/\(name).json"))
        return try XCTUnwrap(RaynaAnchors.decode(data))
    }

    func testEveryClipHasOnePosePerFrame() throws {
        for clip in RaynaClip.allCases {
            let poses = try rows(clip.rawValue)
            XCTAssertEqual(poses.count, clip.frameCount, clip.rawValue)
            for p in poses {
                XCTAssertEqual(Set(p.keys), Set(BadgeSlot.onBody), clip.rawValue)
                XCTAssertTrue(p.values.allSatisfy { (0...1).contains($0.opacity) }, clip.rawValue)
            }
        }
    }

    func testBadgesStayOnThroughTheIdleLoopsAndWiggle() throws {
        for clip in [RaynaClip.idleHappy, .idleThirsty, .wiggle] {
            XCTAssertTrue(try rows(clip.rawValue).allSatisfy { $0.values.allSatisfy { $0.opacity == 1 } }, clip.rawValue)
        }
    }

    func testBadgesFadeAsSheSwimsOff() throws {
        let off = try rows(RaynaClip.swimOff.rawValue)
        XCTAssertEqual(off.first?[.head]?.opacity, 1)
        XCTAssertEqual(off.last?[.head]?.opacity, 0)
        let arrive = try rows(RaynaClip.swimIn.rawValue)
        XCTAssertEqual(arrive.first?[.chest]?.opacity, 0)
        XCTAssertEqual(arrive.last?[.chest]?.opacity, 1)
    }

    func testRestingPoseIsTheFirstIdleFrame() throws {
        let first = try XCTUnwrap(rows(RaynaClip.idleHappy.rawValue).first)
        for slot in BadgeSlot.onBody {
            let rest = RaynaSlotPose.rest(slot), p = try XCTUnwrap(first[slot])
            XCTAssertEqual(p.x, rest.x, accuracy: 0.01, slot.rawValue)
            XCTAssertEqual(p.y, rest.y, accuracy: 0.01, slot.rawValue)
            XCTAssertEqual(p.degrees, 0, accuracy: 2, slot.rawValue)
        }
    }

    func testEveryStillHasAllThreeSlots() {
        for band in RaynaBand.allCases {
            XCTAssertEqual(Set(RaynaAnchors.still(band)?.keys ?? [:].keys), Set(BadgeSlot.onBody), "band\(band.rawValue)")
        }
        XCTAssertNotNil(RaynaAnchors.poses(.wiggle, frame: 999), "out-of-range frames clamp")
    }

    func testDecodeRejectsJunk() {
        XCTAssertNil(RaynaAnchors.decode(Data("nope".utf8)))
        XCTAssertNil(RaynaAnchors.decode(Data("{}".utf8)))
    }
}
