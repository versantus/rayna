import XCTest
@testable import RaynaCore

final class SyncLedgerTests: XCTestCase {
    let today = "2026-10-15"
    var seq = 0
    func id(_ p: String) -> () -> String { { self.seq += 1; return "\(p)-\(self.seq)" } }

    /// Simulates a device: local snapshot → capture → (server merge) → snapshot back.
    func device(_ ml: Int, settings: [String: Int] = ["goalML": 2500]) -> SyncLocalSnapshot {
        SyncLocalSnapshot(today: today, todayML: ml, settings: settings)
    }

    func testOfflineAddsOnTwoDevicesBothCount() {
        var a = SyncLedger(), b = SyncLedger()
        a.capture(device(0), device: "A", newID: id("a")); b.capture(device(0), device: "B", newID: id("b"))
        a.capture(device(250), device: "A", newID: id("a"))   // iPhone +1 glass offline
        b.capture(device(250), device: "B", newID: id("b"))   // Mac +1 glass offline
        a.mergeRemote(b.days[today]!); b.mergeRemote(a.days[today]!)
        XCTAssertEqual(a.days[today]!.ml, 500)
        XCTAssertEqual(a.days[today], b.days[today])
        XCTAssertEqual(a.snapshot(from: device(250)).todayML, 500)
    }

    func testDayMergeIsCommutativeAssociativeIdempotent() {
        var x = SyncDay(day: today); x.glasses["1"] = SyncGlass(ml: 250, at: Date(timeIntervalSince1970: 1))
        var y = SyncDay(day: today); y.glasses["2"] = SyncGlass(ml: 300, at: Date(timeIntervalSince1970: 2)); y.removed = ["1"]
        var z = SyncDay(day: today); z.swapsBy = ["W": 2]; z.baseML = 100
        XCTAssertEqual(x.merged(with: y), y.merged(with: x))
        XCTAssertEqual(x.merged(with: y).merged(with: z), x.merged(with: y.merged(with: z)))
        XCTAssertEqual(x.merged(with: x), x)
        XCTAssertEqual(x.merged(with: y).merged(with: z).ml, 400)
    }

    func testUndoTombstoneRemovesThatGlassEverywhere() {
        var a = SyncLedger(), b = SyncLedger()
        a.capture(device(0), device: "A", newID: id("a"))
        a.capture(device(500), device: "A", newID: id("a"))
        b.mergeRemote(a.days[today]!)
        a.capture(device(250), device: "A", newID: id("a"))     // undo on A
        b.capture(device(750), device: "B", newID: id("b"))     // B added one meanwhile (b local was 500)
        a.mergeRemote(b.days[today]!); b.mergeRemote(a.days[today]!)
        XCTAssertEqual(a.days[today]!.ml, b.days[today]!.ml)
    }

    func testSettingsLastWriterWins() {
        var s1 = SyncSettings(); s1.values["goalML"] = SyncStamped(2000, at: Date(timeIntervalSince1970: 10))
        var s2 = SyncSettings(); s2.values["goalML"] = SyncStamped(3000, at: Date(timeIntervalSince1970: 20))
        s2.values["glassML"] = SyncStamped(300, at: Date(timeIntervalSince1970: 5))
        let m = s1.merged(with: s2)
        XCTAssertEqual(m.values["goalML"]?.value, 3000)
        XCTAssertEqual(m.values["glassML"]?.value, 300)
        XCTAssertEqual(m, s2.merged(with: s1))
        // tie → larger value, deterministic on both sides
        var t1 = SyncSettings(); t1.values["x"] = SyncStamped(1, at: .init(timeIntervalSince1970: 1))
        var t2 = SyncSettings(); t2.values["x"] = SyncStamped(2, at: .init(timeIntervalSince1970: 1))
        XCTAssertEqual(t1.merged(with: t2), t2.merged(with: t1))
    }

    func testLocalSettingChangeIsStampedAndWins() {
        var a = SyncLedger()
        a.capture(device(0), device: "A", now: Date(timeIntervalSince1970: 100))
        a.capture(device(0, settings: ["goalML": 3000]), device: "A", now: Date(timeIntervalSince1970: 200))
        var remote = SyncSettings(); remote.values["goalML"] = SyncStamped(2000, at: Date(timeIntervalSince1970: 150))
        a.mergeRemote(remote)
        XCTAssertEqual(a.settings.values["goalML"]?.value, 3000)
        XCTAssertTrue(a.settingsDirty)
    }

    func testSeedingBaselinesDoNotDoubleCount() {
        var a = SyncLedger(), b = SyncLedger()
        var s = device(750); s.history = ["2026-10-14": 2000]
        a.capture(s, device: "A"); b.capture(s, device: "B")      // same pre-sync data on two devices
        a.mergeRemote(b.days[today]!); a.mergeRemote(b.days["2026-10-14"]!)
        XCTAssertEqual(a.days[today]!.ml, 750)
        XCTAssertEqual(a.days["2026-10-14"]!.ml, 2000)
    }

    func testStaleLocalDayIsNotTreatedAsUndo() {
        var a = SyncLedger()
        a.capture(device(500), device: "A")
        var stale = device(0); stale.todayValid = false
        a.capture(stale, device: "A")
        XCTAssertEqual(a.days[today]!.ml, 500)
    }

    func testProfileStreakFollowsLatestGoalDay() {
        var p1 = SyncProfile(); p1.lastGoalDay = "2026-10-14"; p1.streak = 5; p1.unlocks = ["medal"]
        var p2 = SyncProfile(); p2.lastGoalDay = "2026-10-15"; p2.streak = 6; p2.unlocks = ["bubbles"]
        let m = p1.merged(with: p2)
        XCTAssertEqual(m.streak, 6); XCTAssertEqual(m.bestStreak, 6)
        XCTAssertEqual(m.unlocks, ["medal", "bubbles"])
        XCTAssertEqual(m, p2.merged(with: p1))
    }

    func testMergeRemoteMarksDirtyOnlyWhenServerLacksData() {
        var a = SyncLedger()
        var r = SyncDay(day: today); r.glasses["x"] = SyncGlass(ml: 250, at: Date())
        a.mergeRemote(r)
        XCTAssertFalse(a.dirtyDays.contains(today))
        a.capture(device(500), device: "A")
        a.dirtyDays = []
        a.mergeRemote(r)
        XCTAssertTrue(a.dirtyDays.contains(today))
    }
}
