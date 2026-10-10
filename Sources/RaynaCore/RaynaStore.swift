import Foundation

/// Hydration state persisted in the shared App Group so the iOS app, its widget and
/// notification actions all see the same numbers. All data stays on the device.
public final class RaynaStore {
    public static let appGroup = "group.co.versantus.raynawater"
    public static let shared = RaynaStore()

    public let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: RaynaStore.appGroup) ?? .standard
        self.defaults.register(defaults: [
            "goalML": 2500, "glassML": 250, "intervalMin": 60,
            "quietStartMin": 22 * 60, "quietEndMin": 7 * 60 + 30,
            "eveningSwap": true, "remindersOn": true
        ])
    }

    // MARK: Stored values
    public var totalML: Int { get { defaults.integer(forKey: "totalML") } set { defaults.set(newValue, forKey: "totalML") } }
    public var log: [Date] { get { (defaults.array(forKey: "log") as? [Date]) ?? [] } set { defaults.set(newValue, forKey: "log") } }
    public var runDay: Bool { get { defaults.bool(forKey: "runDay") } set { defaults.set(newValue, forKey: "runDay"); checkGoal() } }
    public var goalML: Int { get { defaults.integer(forKey: "goalML") } set { defaults.set(newValue, forKey: "goalML"); checkGoal() } }
    public var glassML: Int { get { defaults.integer(forKey: "glassML") } set { defaults.set(newValue, forKey: "glassML") } }
    public var intervalMin: Int { get { defaults.integer(forKey: "intervalMin") } set { defaults.set(newValue, forKey: "intervalMin") } }
    public var quietStartMin: Int { get { defaults.integer(forKey: "quietStartMin") } set { defaults.set(newValue, forKey: "quietStartMin") } }
    public var quietEndMin: Int { get { defaults.integer(forKey: "quietEndMin") } set { defaults.set(newValue, forKey: "quietEndMin") } }
    public var eveningSwap: Bool { get { defaults.bool(forKey: "eveningSwap") } set { defaults.set(newValue, forKey: "eveningSwap") } }
    public var remindersOn: Bool { get { defaults.bool(forKey: "remindersOn") } set { defaults.set(newValue, forKey: "remindersOn") } }
    public private(set) var streak: Int { get { defaults.integer(forKey: "streak") } set { defaults.set(newValue, forKey: "streak") } }
    /// Day keys (yyyy-MM-dd) on which the goal was reached, newest last (kept to ~30).
    public private(set) var goalDays: [String] { get { defaults.stringArray(forKey: "goalDays") ?? [] } set { defaults.set(Array(newValue.suffix(30)), forKey: "goalDays") } }
    private var dayKey: String { get { defaults.string(forKey: "dayKey") ?? "" } set { defaults.set(newValue, forKey: "dayKey") } }
    private var lastGoalDay: String { get { defaults.string(forKey: "lastGoalDay") ?? "" } set { defaults.set(newValue, forKey: "lastGoalDay") } }

    /// History, unlocks and swap-a-fizzy-drink stats (same App Group defaults).
    public var extras: RaynaExtras { RaynaExtras(defaults: defaults) }

    // MARK: Derived
    /// Run-day bonus in ml (500 by default; Health can scale it by workout length).
    public var runBonusML: Int { get { let v = defaults.integer(forKey: "runBonusML"); return v > 0 ? v : 500 } set { defaults.set(newValue, forKey: "runBonusML"); checkGoal() } }
    /// Day key on which Health auto-applied the run bonus (so a manual "off" isn't overridden again).
    public var healthRunDay: String { get { defaults.string(forKey: "healthRunDay") ?? "" } set { defaults.set(newValue, forKey: "healthRunDay") } }
    public var healthAutoRun: Bool { get { defaults.bool(forKey: "healthAutoRun") } set { defaults.set(newValue, forKey: "healthAutoRun") } }
    public var healthWriteWater: Bool { get { defaults.bool(forKey: "healthWriteWater") } set { defaults.set(newValue, forKey: "healthWriteWater") } }
    public var effectiveGoal: Int { goalML + (runDay && !extras.kidMode ? runBonusML : 0) }   // no run day in kid mode
    public var progress: Double { effectiveGoal > 0 ? min(Double(totalML) / Double(effectiveGoal), 1) : 0 }
    public var glasses: Int { glassML > 0 ? totalML / glassML : 0 }
    public var quip: String { RaynaCopy.quip(for: progress) }
    public var lastLogged: Date? { log.last }
    public func isQuiet(at date: Date) -> Bool { RaynaCopy.isQuiet(date, start: quietStartMin, end: quietEndMin) }
    public func goalMet(on date: Date) -> Bool { goalDays.contains(RaynaCopy.dayKey(for: date)) }

    // MARK: Actions
    /// Adds a glass. Returns true if this glass just completed today's goal.
    @discardableResult
    public func addGlass(now: Date = Date()) -> Bool {
        rolloverIfNeeded(now: now)
        totalML += glassML
        log = log + [now]
        extras.recordDay(totalML, now: now)
        return checkGoal(now: now)
    }

    public func undo(now: Date = Date()) {
        rolloverIfNeeded(now: now)
        guard totalML > 0 else { return }
        totalML = max(0, totalML - glassML)
        var l = log; if !l.isEmpty { l.removeLast() }; log = l
        extras.recordDay(totalML, now: now)
    }

    /// "I swapped a fizzy drink for water": logs a swap and a glass. Returns true if that glass hit the goal.
    @discardableResult
    public func logSwap(now: Date = Date()) -> Bool {
        extras.logSwap(now: now)
        return addGlass(now: now)
    }

    @discardableResult
    private func checkGoal(now: Date = Date()) -> Bool {
        guard progress >= 1 else { return false }
        let today = RaynaCopy.dayKey(for: now)
        guard lastGoalDay != today else { return false }
        streak = (lastGoalDay == RaynaCopy.yesterdayKey(from: now)) ? streak + 1 : 1
        lastGoalDay = today
        goalDays = goalDays + [today]
        extras.noteStreak(streak)
        return true
    }

    public func rolloverIfNeeded(now: Date = Date()) {
        let today = RaynaCopy.dayKey(for: now)
        if dayKey != today {
            dayKey = today
            totalML = 0
            log = []
            defaults.set(false, forKey: "runDay")
            defaults.set(500, forKey: "runBonusML")
        }
        if lastGoalDay != today && lastGoalDay != RaynaCopy.yesterdayKey(from: now) && streak != 0 {
            streak = 0
        }
    }

    /// Seeds a pleasant demo day (used for App Store screenshots via the `-RaynaDemo <glasses>` launch argument).
    public func seedDemo(glasses: Int, streak s: Int, now: Date = Date()) {
        rolloverIfNeeded(now: now)
        totalML = glasses * glassML
        log = (0..<glasses).map { now.addingTimeInterval(Double($0 - glasses) * 2400) }
        streak = s
        lastGoalDay = RaynaCopy.yesterdayKey(from: now)
        let cal = Calendar.current
        goalDays = (1...max(1, s)).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: now) }.map(RaynaCopy.dayKey(for:))
        extras.seedDemo(todayML: totalML, streak: s, now: now)
        checkGoal(now: now)
        extras.pendingUnlocks = []
    }

    public var recap: RaynaRecap { extras.recap(goalDays: goalDays, streak: streak) }
}
