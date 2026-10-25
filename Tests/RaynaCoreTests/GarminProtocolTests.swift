import XCTest
@testable import RaynaCore

/// Rayna for Garmin: message decoding, dedupe and undo rules on the phone side.
final class GarminProtocolTests: XCTestCase {
    final class FakeSink: GarminDrinkSink {
        var ml = 0
        var adds: [Int] = []
        var removes: [Int] = []
        func logDrink(ml: Int, at: Date) { adds.append(ml); self.ml += ml }
        func removeDrink(ml: Int, at: Date) { removes.append(ml); self.ml -= ml }
        func garminState() -> GarminState { GarminState(ml: ml, goal: 2500, glass: 250, streak: 3, day: RaynaCopy.dayKey(for: Date())) }
    }

    var defaults: UserDefaults!
    let now = Int(Date().timeIntervalSince1970)

    override func setUp() {
        defaults = UserDefaults(suiteName: "GarminProtocolTests-\(UUID().uuidString)")
    }

    func item(_ id: String, _ op: String = "add", ml: Int = 250, ref: String? = nil, at: Int? = nil) -> [String: Any] {
        var d: [String: Any] = ["id": id, "op": op, "ml": NSNumber(value: ml), "at": NSNumber(value: at ?? now)]
        if let ref { d["ref"] = ref }
        return d
    }

    func drinks(_ items: [[String: Any]]) -> [String: Any] { ["v": 1, "t": "drinks", "dev": "w1", "items": items] }

    // MARK: decoding

    func testDecodesDrinksFromConnectIQTypes() {
        let msg = GarminMessage.decode(drinks([item("w1-1"), item("w1-2", "undo", ref: "w1-1")]) as NSDictionary)
        guard case let .drinks(dev, items)? = msg else { return XCTFail("not drinks") }
        XCTAssertEqual(dev, "w1")
        XCTAssertEqual(items.map(\.id), ["w1-1", "w1-2"])
        XCTAssertEqual(items[0].op, .add)
        XCTAssertEqual(items[0].ml, 250)
        XCTAssertEqual(items[1].ref, "w1-1")
        XCTAssertEqual(Int(items[0].at.timeIntervalSince1970), now)
    }

    func testDecodesHelloAndRejectsUnknown() {
        XCTAssertEqual(GarminMessage.decode(["t": "hello", "dev": "w1"]), .hello(device: "w1"))
        XCTAssertNil(GarminMessage.decode(["t": "party"]))
        XCTAssertNil(GarminMessage.decode("not a dictionary"))
        XCTAssertNil(GarminMessage.decode(nil))
    }

    func testSkipsMalformedItemsButKeepsTheRest() {
        let bad: [[String: Any]] = [["id": "", "op": "add", "ml": 250], ["id": "x", "op": "spill", "ml": 250],
                                    ["id": "y", "op": "add", "ml": 0], ["id": "z", "op": "add", "ml": 99_999], item("ok")]
        guard case let .drinks(_, items)? = GarminMessage.decode(drinks(bad)) else { return XCTFail() }
        XCTAssertEqual(items.map(\.id), ["ok"])
    }

    func testItemRoundTrips() {
        let i = GarminItem(id: "w1-9", op: .undo, ml: 330, at: Date(timeIntervalSince1970: 1_761_400_000), ref: "w1-8")
        XCTAssertEqual(GarminItem.decode(i.dictionary), i)
    }

    func testStateEncodesEverythingTheWatchReads() {
        let s = GarminState(ml: 1750, goal: 2500, glass: 250, streak: 14, day: "2026-10-25", ack: ["a"]).dictionary
        XCTAssertEqual(s["t"] as? String, "state")
        XCTAssertEqual(s["v"] as? Int, 1)
        XCTAssertEqual(s["ml"] as? Int, 1750)
        XCTAssertEqual(s["goal"] as? Int, 2500)
        XCTAssertEqual(s["glass"] as? Int, 250)
        XCTAssertEqual(s["streak"] as? Int, 14)
        XCTAssertEqual(s["band"] as? Int, 2)          // 70%: same band as the app's "fine" ray
        XCTAssertEqual(s["sizes"] as? [Int], [150, 200, 250, 330, 400, 500])
        XCTAssertEqual(s["ack"] as? [String], ["a"])
        XCTAssertTrue(JSONSerialization.isValidJSONObject(s))   // only plain types, as Connect IQ needs
    }

    // MARK: dedupe and undo

    func testResentBatchIsAppliedOnceAndAckedEveryTime() {
        let sink = FakeSink()
        let core = GarminBridgeCore(defaults: defaults, sink: sink)
        let batch = drinks([item("w1-1"), item("w1-2", ml: 500)])
        let r1 = core.handle(batch)
        let r2 = core.handle(batch)   // reply lost, watch resends
        XCTAssertEqual(sink.adds, [250, 500])
        XCTAssertEqual(r1?["ml"] as? Int, 750)
        XCTAssertEqual(r2?["ml"] as? Int, 750)
        XCTAssertEqual(Set(r2?["ack"] as? [String] ?? []), ["w1-1", "w1-2"])
    }

    func testUndoRemovesThatDrinkOnce() {
        let sink = FakeSink()
        let core = GarminBridgeCore(defaults: defaults, sink: sink)
        _ = core.handle(drinks([item("w1-1", ml: 330)]))
        let undo = drinks([item("w1-2", "undo", ml: 330, ref: "w1-1")])
        _ = core.handle(undo)
        _ = core.handle(undo)
        XCTAssertEqual(sink.removes, [330])
        XCTAssertEqual(sink.ml, 0)
    }

    func testUndoArrivingBeforeItsAddCancelsIt() {
        let sink = FakeSink()
        let core = GarminBridgeCore(defaults: defaults, sink: sink)
        _ = core.handle(drinks([item("w1-2", "undo", ref: "w1-1")]))
        let r = core.handle(drinks([item("w1-1")]))
        XCTAssertEqual(sink.adds, [])
        XCTAssertEqual(sink.ml, 0)
        XCTAssertTrue((r?["ack"] as? [String] ?? []).contains("w1-1"))
    }

    func testHelloRepliesWithStateAndTodaysAcks() {
        let sink = FakeSink()
        let core = GarminBridgeCore(defaults: defaults, sink: sink)
        _ = core.handle(drinks([item("w1-1")]))
        let r = core.handle(["v": 1, "t": "hello", "dev": "w1"])
        XCTAssertEqual(r?["ml"] as? Int, 250)
        XCTAssertEqual(r?["ack"] as? [String], ["w1-1"])
    }

    func testLedgerPersistsAcrossLaunches() {
        let sink = FakeSink()
        _ = GarminBridgeCore(defaults: defaults, sink: sink).handle(drinks([item("w1-1")]))
        _ = GarminBridgeCore(defaults: defaults, sink: sink).handle(drinks([item("w1-1")]))   // app relaunched
        XCTAssertEqual(sink.adds, [250])
    }

    func testPruneForgetsOldItems() {
        var l = GarminLedger()
        let sink = FakeSink()
        let old = GarminItem(id: "old", op: .add, ml: 250, at: Date().addingTimeInterval(-5 * 86_400))
        _ = l.apply([old, GarminItem(id: "new", op: .add, ml: 250, at: Date())], to: sink)
        l.prune()
        XCTAssertNil(l.applied["old"])
        XCTAssertNotNil(l.applied["new"])
    }

    // MARK: the real store

    func testStoreSinkLogsCustomSizesThroughTheStore() {
        let store = RaynaStore(defaults: defaults)
        store.rolloverIfNeeded()
        var events: [Int] = []
        let sink = StoreGarminSink(store: store) { delta, _ in events.append(delta) }
        let core = GarminBridgeCore(defaults: defaults, sink: sink)
        _ = core.handle(drinks([item("w1-1", ml: 330), item("w1-2", ml: 150)]))
        XCTAssertEqual(store.totalML, 480)
        XCTAssertEqual(store.glassML, 250)   // the user's glass setting is untouched
        _ = core.handle(drinks([item("w1-3", "undo", ml: 150, ref: "w1-2")]))
        XCTAssertEqual(store.totalML, 330)
        XCTAssertEqual(events, [330, 150, -150])
        let state = core.currentState()
        XCTAssertEqual(state?["ml"] as? Int, 330)
        XCTAssertEqual(state?["goal"] as? Int, store.effectiveGoal)
    }

    func testStoreSinkPutsYesterdaysQueuedDrinkIntoHistory() {
        let store = RaynaStore(defaults: defaults)
        store.rolloverIfNeeded()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let key = RaynaCopy.dayKey(for: yesterday)
        let sink = StoreGarminSink(store: store)
        sink.logDrink(ml: 400, at: yesterday)
        XCTAssertEqual(store.totalML, 0)
        XCTAssertEqual(store.extras.history[key], 400)
    }

    func testAddGlassIsUnchanged() {
        let store = RaynaStore(defaults: defaults)
        store.glassML = 330
        store.addGlass()
        store.addDrink(ml: 150)
        XCTAssertEqual(store.totalML, 480)
        store.undo()
        XCTAssertEqual(store.totalML, 150)
    }
}
