import Foundation

// MARK: - iCloud sync: pure, testable merge model (no CloudKit in here)
//
// Each device keeps a "ledger" mirroring the local store in merge-friendly form. Merging two ledgers is
// commutative, associative and idempotent, so devices converge however often/late they sync:
// - Days: glasses are events with ids (union); Undo adds the id to a tombstone set (union), so an undo on
//   one device removes that exact glass everywhere. Fizzy-drink swaps are a per-device counter (max per device).
//   Totals that existed before sync was turned on are a "baseline" merged by max (no double counting).
//   The exercise-day flag (`runDay`) is last-writer-wins with a timestamp; the bonus (`runBonusML`) and "goal met" merge by max / OR.
// - Settings: last-writer-wins per key (ties: larger value).
// - Profile: goal days and unlocks are unions; best streak and facts shown are max; the current streak
//   follows the device with the latest goal day (ties: max).

public struct SyncGlass: Codable, Equatable {
    public var ml: Int
    public var at: Date
    public init(ml: Int, at: Date) { self.ml = ml; self.at = at }
}

public struct SyncDay: Codable, Equatable {
    public var day: String
    public var baseML = 0
    public var glasses: [String: SyncGlass] = [:]
    public var removed: Set<String> = []
    /// Swaps per device id (a grow-only counter: total = sum).
    public var swapsBy: [String: Int] = [:]
    public var baseSwaps = 0
    public var runDay = false
    public var runDayAt = Date(timeIntervalSince1970: 0)
    public var runBonusML = 0
    public var goalMet = false

    public init(day: String) { self.day = day }

    public var liveGlasses: [(id: String, glass: SyncGlass)] {
        glasses.filter { !removed.contains($0.key) }.map { ($0.key, $0.value) }.sorted { ($0.glass.at, $0.id) < ($1.glass.at, $1.id) }
    }
    public var ml: Int { max(0, baseML + liveGlasses.reduce(0) { $0 + $1.glass.ml }) }
    public var swaps: Int { baseSwaps + swapsBy.values.reduce(0, +) }

    public func merged(with o: SyncDay) -> SyncDay {
        var m = self
        m.baseML = max(baseML, o.baseML)
        m.glasses.merge(o.glasses) { a, _ in a }
        m.removed.formUnion(o.removed)
        m.swapsBy.merge(o.swapsBy) { max($0, $1) }
        m.baseSwaps = max(baseSwaps, o.baseSwaps)
        if o.runDayAt > runDayAt || (o.runDayAt == runDayAt && o.runDay && !runDay) { m.runDay = o.runDay; m.runDayAt = o.runDayAt }
        m.runBonusML = max(runBonusML, o.runBonusML)
        m.goalMet = goalMet || o.goalMet
        return m
    }
}

public struct SyncStamped: Codable, Equatable {
    public var value: Int
    public var at: Date
    public init(_ value: Int, at: Date) { self.value = value; self.at = at }
}

public struct SyncText: Codable, Equatable {
    public var value: String
    public var at: Date
    public init(_ value: String, at: Date) { self.value = value; self.at = at }
}

public struct SyncSettings: Codable, Equatable {
    public var values: [String: SyncStamped] = [:]
    /// String prefs such as `mainLayout`, still inside the RaynaPrefs payload. Missing on older records.
    public var text: [String: SyncText] = [:]
    public init() {}
    public func merged(with o: SyncSettings) -> SyncSettings {
        var m = self
        m.values.merge(o.values) { a, b in (b.at > a.at || (b.at == a.at && b.value > a.value)) ? b : a }
        m.text.merge(o.text) { a, b in (b.at > a.at || (b.at == a.at && b.value > a.value)) ? b : a }
        return m
    }

    private enum CodingKeys: String, CodingKey { case values, text }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        values = try c.decodeIfPresent([String: SyncStamped].self, forKey: .values) ?? [:]
        text = try c.decodeIfPresent([String: SyncText].self, forKey: .text) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(values, forKey: .values)
        if !text.isEmpty { try c.encode(text, forKey: .text) }
    }
}

public struct SyncProfile: Codable, Equatable {
    public var streak = 0
    public var lastGoalDay = ""
    public var bestStreak = 0
    public var unlocks: Set<String> = []
    public var goalDays: Set<String> = []
    public var factsUnlocked = 0
    /// Halloween facts shown. Max-merged so an older device cannot rewind the count. Missing on older records.
    public var halloweenFactsShown = 0
    public init() {}
    public func merged(with o: SyncProfile) -> SyncProfile {
        var m = self
        if o.lastGoalDay > lastGoalDay { m.lastGoalDay = o.lastGoalDay; m.streak = o.streak }
        else if o.lastGoalDay == lastGoalDay { m.streak = max(streak, o.streak) }
        m.bestStreak = max(bestStreak, o.bestStreak, m.streak)
        m.unlocks.formUnion(o.unlocks)
        m.goalDays.formUnion(o.goalDays)
        m.factsUnlocked = max(factsUnlocked, o.factsUnlocked)
        m.halloweenFactsShown = max(halloweenFactsShown, o.halloweenFactsShown)
        return m
    }

    private enum CodingKeys: String, CodingKey {
        case streak, lastGoalDay, bestStreak, unlocks, goalDays, factsUnlocked, halloweenFactsShown
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        lastGoalDay = try c.decodeIfPresent(String.self, forKey: .lastGoalDay) ?? ""
        bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0
        unlocks = try c.decodeIfPresent(Set<String>.self, forKey: .unlocks) ?? []
        goalDays = try c.decodeIfPresent(Set<String>.self, forKey: .goalDays) ?? []
        factsUnlocked = try c.decodeIfPresent(Int.self, forKey: .factsUnlocked) ?? 0
        halloweenFactsShown = try c.decodeIfPresent(Int.self, forKey: .halloweenFactsShown) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(streak, forKey: .streak)
        try c.encode(lastGoalDay, forKey: .lastGoalDay)
        try c.encode(bestStreak, forKey: .bestStreak)
        try c.encode(unlocks, forKey: .unlocks)
        try c.encode(goalDays, forKey: .goalDays)
        try c.encode(factsUnlocked, forKey: .factsUnlocked)
        try c.encode(halloweenFactsShown, forKey: .halloweenFactsShown)
    }
}

/// The device's whole mirror plus what still needs uploading.
public struct SyncLedger: Codable, Equatable {
    public static let keepDays = 60
    public var days: [String: SyncDay] = [:]
    public var settings = SyncSettings()
    public var profile = SyncProfile()
    public var dirtyDays: Set<String> = []
    public var settingsDirty = false
    public var profileDirty = false
    /// False until the first capture (which turns existing local data into baselines).
    public var seeded = false
    public init() {}

    public var hasDirty: Bool { !dirtyDays.isEmpty || settingsDirty || profileDirty }

    public mutating func markAllDirty() { dirtyDays = Set(days.keys); settingsDirty = true; profileDirty = true }

    /// Merges a remote day. Marks it dirty if we know something the server copy lacks.
    @discardableResult
    public mutating func mergeRemote(_ r: SyncDay) -> Bool {
        let mine = days[r.day] ?? SyncDay(day: r.day)
        let m = mine.merged(with: r)
        days[r.day] = m
        if m != r { dirtyDays.insert(r.day) }
        return m != mine
    }
    @discardableResult
    public mutating func mergeRemote(_ r: SyncSettings) -> Bool {
        let m = settings.merged(with: r); let changed = m != settings
        settings = m; if m != r { settingsDirty = true }
        return changed
    }
    @discardableResult
    public mutating func mergeRemote(_ r: SyncProfile) -> Bool {
        let m = profile.merged(with: r); let changed = m != profile
        profile = m; if m != r { profileDirty = true }
        return changed
    }

    public mutating func prune(today: String) {
        let keep = Set(days.keys.sorted().suffix(Self.keepDays)).union([today])
        days = days.filter { keep.contains($0.key) }
        dirtyDays = dirtyDays.intersection(keep)
    }
}

// MARK: - Local snapshot <-> ledger

/// The synced slice of the local store (same keys on iOS's App Group defaults and macOS's standard defaults).
public struct SyncLocalSnapshot: Equatable {
    public var today: String
    public var todayML: Int
    public var log: [Date]
    public var runDay: Bool
    public var runBonusML: Int
    public var history: [String: Int]
    public var swaps: [String: Int]
    public var settings: [String: Int]
    public var streak: Int
    public var lastGoalDay: String
    public var bestStreak: Int
    public var unlocks: [String]
    public var goalDays: [String]
    public var factsUnlocked: Int
    public var halloweenFactsShown: Int = 0
    /// String settings such as `mainLayout`. Absent keys are left alone, so a default is not uploaded.
    public var text: [String: String] = [:]
    /// False when the local store hasn't rolled over to `today` yet (its today fields are stale/empty).
    public var todayValid = true

    public init(today: String, todayML: Int = 0, log: [Date] = [], runDay: Bool = false, runBonusML: Int = 0,
                history: [String: Int] = [:], swaps: [String: Int] = [:], settings: [String: Int] = [:],
                streak: Int = 0, lastGoalDay: String = "", bestStreak: Int = 0, unlocks: [String] = [],
                goalDays: [String] = [], factsUnlocked: Int = 0, halloweenFactsShown: Int = 0, text: [String: String] = [:]) {
        self.today = today; self.todayML = todayML; self.log = log; self.runDay = runDay; self.runBonusML = runBonusML
        self.history = history; self.swaps = swaps; self.settings = settings; self.streak = streak
        self.lastGoalDay = lastGoalDay; self.bestStreak = bestStreak; self.unlocks = unlocks
        self.goalDays = goalDays; self.factsUnlocked = factsUnlocked; self.halloweenFactsShown = halloweenFactsShown; self.text = text
    }
}

public extension SyncLedger {
    /// Folds local changes since the last capture into the ledger (diff-based, so glasses logged from widgets,
    /// notifications, the watch or Live Activities are picked up too). Glass added → new event; glass removed →
    /// newest live event tombstoned.
    mutating func capture(_ s: SyncLocalSnapshot, device: String, now: Date = Date(), newID: () -> String = { UUID().uuidString }) {
        let epoch = Date(timeIntervalSince1970: 0)
        if !seeded {
            // First run: existing numbers become baselines (merged by max, so two devices don't double count).
            var keys = Set(s.history.keys).union(s.swaps.keys); keys.insert(s.today)
            for k in keys {
                var d = days[k] ?? SyncDay(day: k)
                d.baseML = max(d.baseML, k == s.today ? s.todayML : (s.history[k] ?? 0))
                d.baseSwaps = max(d.baseSwaps, s.swaps[k] ?? 0)
                if k == s.today { d.runDay = s.runDay; d.runBonusML = s.runDay ? s.runBonusML : 0 }
                d.goalMet = d.goalMet || s.goalDays.contains(k)
                days[k] = d; dirtyDays.insert(k)
            }
            for (k, v) in s.settings where settings.values[k] == nil { settings.values[k] = SyncStamped(v, at: epoch) }
            settingsDirty = true
            seeded = true
        }
        // Today: glasses (only if the local store is on today, else its zero would look like undos)
        var t = days[s.today] ?? SyncDay(day: s.today)
        let before = t
        var diff = s.todayValid ? s.todayML - t.ml : 0
        if diff > 0 {
            t.glasses[newID()] = SyncGlass(ml: diff, at: s.log.last ?? now)
        } else if diff < 0 {
            for g in t.liveGlasses.reversed() where diff < 0 {
                t.removed.insert(g.id); diff += g.glass.ml
            }
            if diff > 0 { t.glasses[newID()] = SyncGlass(ml: diff, at: s.log.last ?? now) }   // over-removed: re-add rest
            if diff < 0 { t.baseML = max(0, t.baseML + diff) }                                   // pre-sync glasses undone (local only)
        }
        let localSwaps = s.swaps[s.today] ?? 0
        if localSwaps > t.swaps { t.swapsBy[device, default: 0] += localSwaps - t.swaps }
        if s.todayValid && s.runDay != t.runDay { t.runDay = s.runDay; t.runDayAt = now }
        if s.runDay { t.runBonusML = max(t.runBonusML, s.runBonusML) }
        if s.goalDays.contains(s.today) { t.goalMet = true }
        if t != before { days[s.today] = t; dirtyDays.insert(s.today) }
        // Past days only grow (e.g. history from before sync); never shrink remote totals.
        for (k, v) in s.history where k != s.today {
            var d = days[k] ?? SyncDay(day: k); let b = d
            if v > d.ml { d.baseML += v - d.ml }
            if s.goalDays.contains(k) { d.goalMet = true }
            if d != b { days[k] = d; dirtyDays.insert(k) }
        }
        // Settings: anything different from the ledger was changed here, now.
        for (k, v) in s.settings where settings.values[k]?.value != v {
            settings.values[k] = SyncStamped(v, at: now); settingsDirty = true
        }
        for (k, v) in s.text where settings.text[k]?.value != v {
            settings.text[k] = SyncText(v, at: now); settingsDirty = true
        }
        // Profile
        var p = SyncProfile()
        p.streak = s.streak; p.lastGoalDay = s.lastGoalDay; p.bestStreak = s.bestStreak
        p.unlocks = Set(s.unlocks); p.goalDays = Set(s.goalDays); p.factsUnlocked = s.factsUnlocked
        p.halloweenFactsShown = s.halloweenFactsShown
        let mp = profile.merged(with: p)
        if mp != profile { profile = mp; profileDirty = true }
        prune(today: s.today)
    }

    /// What the local store should look like after merging (the UI keeps reading the local store).
    func snapshot(from local: SyncLocalSnapshot) -> SyncLocalSnapshot {
        var s = local
        if let t = days[local.today] {
            s.todayML = t.ml
            s.todayValid = true
            if s.todayML != local.todayML || !local.todayValid {
                let dates = t.liveGlasses.map(\.glass.at)
                s.log = dates.isEmpty ? local.log : dates
            }
            s.runDay = t.runDay
            if t.runDay && t.runBonusML > 0 { s.runBonusML = t.runBonusML }
        }
        var h = local.history, sw = local.swaps
        for (k, d) in days {
            if d.ml > 0 || h[k] != nil { h[k] = d.ml }
            if d.swaps > 0 { sw[k] = d.swaps }
        }
        if s.todayML > 0 || h[local.today] != nil { h[local.today] = s.todayML }
        s.history = h; s.swaps = sw
        for (k, v) in settings.values where s.settings[k] != nil || k == "exerciseExtraOn" || k == WornSet.prefsKey
            || k == SeasonGate.halloween.offKey || k == SeasonGate.halloween.manualOnKey {
            s.settings[k] = v.value
        }
        var texts = s.text
        for (k, v) in settings.text { texts[k] = v.value }
        s.text = texts
        s.lastGoalDay = max(local.lastGoalDay, profile.lastGoalDay)
        s.streak = profile.lastGoalDay >= local.lastGoalDay ? max(profile.streak, profile.lastGoalDay == local.lastGoalDay ? local.streak : 0) : local.streak
        s.bestStreak = max(local.bestStreak, profile.bestStreak)
        s.unlocks = local.unlocks + profile.unlocks.subtracting(local.unlocks).sorted()
        let goal = Set(local.goalDays).union(profile.goalDays).union(days.filter { $0.value.goalMet }.keys)
        s.goalDays = Array(goal.sorted().suffix(30))
        s.factsUnlocked = max(local.factsUnlocked, profile.factsUnlocked)
        s.halloweenFactsShown = max(local.halloweenFactsShown, profile.halloweenFactsShown)
        return s
    }
}
