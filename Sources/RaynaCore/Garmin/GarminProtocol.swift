import Foundation

// MARK: - Rayna for Garmin: phone side of the watch protocol (pure, no Connect IQ SDK in here)
//
// The Garmin watch app (garmin/ in this repo) talks to the iPhone through Garmin Connect Mobile and the
// Connect IQ iOS SDK. Messages are plain dictionaries (Connect IQ serialises Dictionary/Array/String/Number).
//
//   watch -> phone  {"v":1,"t":"drinks","dev":"a1b2c3","items":[{"id":"a1b2c3-17","op":"add","ml":250,"at":1761400000},
//                                                              {"id":"a1b2c3-18","op":"undo","ref":"a1b2c3-17","ml":250,"at":...}]}
//                   {"v":1,"t":"hello","dev":"a1b2c3"}
//   phone -> watch  {"v":1,"t":"state","ml":1750,"goal":2500,"glass":250,"streak":14,"band":3,"day":"2026-10-25",
//                    "sizes":[150,200,250,330,400,500],"ack":["a1b2c3-17", ...]}
//
// The watch keeps every item queued until its id comes back in "ack", so any lost message only causes a resend.
// The phone applies each id at most once (GarminLedger), which makes resends harmless. Logged drinks go through the
// normal store, so iCloud sync, Health, widgets, pods and the Apple Watch all see them like any other glass.

public enum GarminConfig {
    /// Connect IQ app id from garmin/manifest.xml (as a UUID).
    public static let appID = "2936b767-4884-4381-9fd0-0c78b83f4018"
    public static let protocolVersion = 1
    /// URL scheme Garmin Connect Mobile calls back on after device selection (must be in Info.plist when enabled).
    public static let urlScheme = "rayna-ciq"
    /// Ids remembered per day, and days kept, for dedupe.
    public static let maxAckIDs = 60
    public static let keepDays = 3
}

public enum GarminOp: String, Codable, Equatable { case add, undo }

public struct GarminItem: Equatable {
    public var id: String
    public var op: GarminOp
    public var ml: Int
    public var at: Date
    public var ref: String?
    public init(id: String, op: GarminOp, ml: Int, at: Date, ref: String? = nil) {
        self.id = id; self.op = op; self.ml = ml; self.at = at; self.ref = ref
    }
}

public enum GarminMessage: Equatable {
    case drinks(device: String, items: [GarminItem])
    case hello(device: String)

    /// Decodes what the Connect IQ SDK hands us (an NSDictionary of NSString/NSNumber/NSArray). Unknown or malformed
    /// messages return nil; a malformed item is skipped rather than failing the batch.
    public static func decode(_ any: Any?) -> GarminMessage? {
        guard let d = any as? [String: Any], let t = d["t"] as? String else { return nil }
        let device = d["dev"] as? String ?? ""
        switch t {
        case "hello":
            return .hello(device: device)
        case "drinks":
            let raw = d["items"] as? [Any] ?? []
            let items = raw.compactMap { GarminItem.decode($0) }
            return .drinks(device: device, items: items)
        default:
            return nil
        }
    }
}

extension GarminItem {
    static func decode(_ any: Any) -> GarminItem? {
        guard let d = any as? [String: Any],
              let id = d["id"] as? String, !id.isEmpty,
              let op = (d["op"] as? String).flatMap(GarminOp.init(rawValue:)),
              let ml = garminInt(d["ml"]), ml > 0, ml <= GlassSize.maxML else { return nil }
        let at = garminInt(d["at"]).map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()
        return GarminItem(id: id, op: op, ml: ml, at: at, ref: d["ref"] as? String)
    }

    public var dictionary: [String: Any] {
        var d: [String: Any] = ["id": id, "op": op.rawValue, "ml": ml, "at": Int(at.timeIntervalSince1970)]
        if let ref { d["ref"] = ref }
        return d
    }
}

private func garminInt(_ any: Any?) -> Int? {
    if let i = any as? Int { return i }
    if let n = any as? NSNumber { return n.intValue }
    if let d = any as? Double { return Int(d) }
    return nil
}

/// What the watch shows. Sent after every batch, on "hello", and whenever the phone's numbers change.
public struct GarminState: Equatable {
    public var ml: Int
    public var goal: Int
    public var glass: Int
    public var streak: Int
    public var day: String
    public var sizes: [Int] = GlassSize.presets
    public var ack: [String] = []

    public init(ml: Int, goal: Int, glass: Int, streak: Int, day: String, sizes: [Int] = GlassSize.presets, ack: [String] = []) {
        self.ml = ml; self.goal = goal; self.glass = glass; self.streak = streak; self.day = day; self.sizes = sizes; self.ack = ack
    }

    /// Mood band 0...4, same thresholds as RaynaBand.
    public var band: Int {
        let p = goal > 0 ? Double(ml) / Double(goal) : 0
        return RaynaBand(progress: p).rawValue
    }

    public var dictionary: [String: Any] {
        ["v": GarminConfig.protocolVersion, "t": "state", "ml": ml, "goal": goal, "glass": glass, "streak": streak,
         "band": band, "day": day, "sizes": sizes, "ack": ack]
    }
}

/// Where the bridge logs drinks: the app's real store in production, a fake in tests.
public protocol GarminDrinkSink: AnyObject {
    /// A drink from the watch. `at` may be an earlier day (queued overnight while the phone was away).
    func logDrink(ml: Int, at: Date)
    /// Takes back a drink the watch had logged (ml and time of the original).
    func removeDrink(ml: Int, at: Date)
    /// Today's numbers for the reply.
    func garminState() -> GarminState
}

/// Which watch items have been applied, so resends never double count. Persisted in the App Group defaults.
public struct GarminLedger: Codable, Equatable {
    public struct Applied: Codable, Equatable {
        public var ml: Int
        public var at: Date
        public var undone: Bool
    }
    /// Applied adds and undos, by item id.
    public var applied: [String: Applied] = [:]
    /// Undos that arrived before the add they refer to (the add is then skipped when it turns up).
    public var earlyUndos: [String: Date] = [:]

    public init() {}

    public static let storageKey = "garminLedger"

    public static func load(_ d: UserDefaults) -> GarminLedger {
        guard let data = d.data(forKey: storageKey), let l = try? JSONDecoder().decode(GarminLedger.self, from: data) else { return GarminLedger() }
        return l
    }

    public func save(_ d: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) { d.set(data, forKey: Self.storageKey) }
    }

    /// Applies new items to `sink` (each id at most once) and returns the ids to acknowledge, which is every item
    /// in the batch: new ones because they're applied now, known ones because they were applied before.
    public mutating func apply(_ items: [GarminItem], to sink: GarminDrinkSink) -> [String] {
        for item in items where applied[item.id] == nil {
            switch item.op {
            case .add:
                if earlyUndos.removeValue(forKey: item.id) != nil {
                    applied[item.id] = Applied(ml: item.ml, at: item.at, undone: true)   // undone before it arrived
                } else {
                    sink.logDrink(ml: item.ml, at: item.at)
                    applied[item.id] = Applied(ml: item.ml, at: item.at, undone: false)
                }
            case .undo:
                applied[item.id] = Applied(ml: item.ml, at: item.at, undone: false)
                guard let ref = item.ref else { continue }
                if var target = applied[ref] {
                    if !target.undone {
                        sink.removeDrink(ml: target.ml, at: target.at)
                        target.undone = true
                        applied[ref] = target
                    }
                } else {
                    earlyUndos[ref] = item.at
                }
            }
        }
        return items.map(\.id)
    }

    /// Ids applied on `day` (newest last, capped), echoed in every state message so a watch that missed a reply
    /// still clears its queue.
    public func ackIDs(day: String) -> [String] {
        let ids = applied.filter { RaynaCopy.dayKey(for: $0.value.at) == day }
            .sorted { ($0.value.at, $0.key) < ($1.value.at, $1.key) }
            .map(\.key)
        return Array(ids.suffix(GarminConfig.maxAckIDs))
    }

    /// Forgets items older than `keepDays` (the watch never resends anything that old: it ages out first).
    public mutating func prune(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Double(GarminConfig.keepDays) * 86_400)
        applied = applied.filter { $0.value.at >= cutoff }
        earlyUndos = earlyUndos.filter { $0.value >= cutoff }
    }
}

/// Message handling without any transport: decode, dedupe, log, and build the reply.
public final class GarminBridgeCore {
    public let defaults: UserDefaults
    public weak var sink: GarminDrinkSink?

    public init(defaults: UserDefaults, sink: GarminDrinkSink?) {
        self.defaults = defaults
        self.sink = sink
    }

    /// Handles one message from the watch. Returns the reply to send back (a state message), or nil if unknown.
    public func handle(_ message: Any?, now: Date = Date()) -> [String: Any]? {
        guard let sink, let msg = GarminMessage.decode(message) else { return nil }
        var ledger = GarminLedger.load(defaults)
        var ack: [String] = []
        if case let .drinks(_, items) = msg {
            ack = ledger.apply(items, to: sink)
        }
        ledger.prune(now: now)
        ledger.save(defaults)
        return reply(ledger: ledger, extraAck: ack)
    }

    /// The current state for the watch (e.g. after a change on the phone).
    public func currentState() -> [String: Any]? {
        reply(ledger: GarminLedger.load(defaults), extraAck: [])
    }

    private func reply(ledger: GarminLedger, extraAck: [String]) -> [String: Any]? {
        guard let sink else { return nil }
        var s = sink.garminState()
        var ack = ledger.ackIDs(day: s.day)
        for id in extraAck where !ack.contains(id) { ack.append(id) }
        s.ack = Array(ack.suffix(GarminConfig.maxAckIDs + extraAck.count))
        return s.dictionary
    }
}

/// The production sink: logs into RaynaStore like a normal glass (so iCloud sync, history and goals follow).
/// `didChange(added:)` lets the app run its usual side effects (Health, widgets, Apple Watch, pod, UI).
public final class StoreGarminSink: GarminDrinkSink {
    public let store: RaynaStore
    public var didChange: (_ deltaML: Int, _ goalReached: Bool) -> Void

    public init(store: RaynaStore, didChange: @escaping (_ deltaML: Int, _ goalReached: Bool) -> Void = { _, _ in }) {
        self.store = store
        self.didChange = didChange
    }

    public func logDrink(ml: Int, at: Date) {
        if Calendar.current.isDateInToday(at) {
            let hit = store.addDrink(ml: ml, at: at)
            didChange(ml, hit)
        } else {
            // Queued on the watch over midnight: it belongs to that day's history, not today.
            let key = RaynaCopy.dayKey(for: at)
            var h = store.extras.history
            h[key, default: 0] += ml
            store.extras.history = h
            didChange(0, false)
        }
    }

    public func removeDrink(ml: Int, at: Date) {
        if Calendar.current.isDateInToday(at) {
            store.removeDrink(ml: ml)
            didChange(-ml, false)
        } else {
            let key = RaynaCopy.dayKey(for: at)
            var h = store.extras.history
            if let v = h[key] { h[key] = max(0, v - ml); store.extras.history = h }
            didChange(0, false)
        }
    }

    public func garminState() -> GarminState {
        store.rolloverIfNeeded()
        return GarminState(ml: store.totalML, goal: store.effectiveGoal, glass: store.glassML, streak: store.streak,
                           day: RaynaCopy.dayKey(for: Date()))
    }
}
