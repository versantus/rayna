import Foundation

// MARK: - Unlocks ("Rayna evolves")

/// Streak-based unlocks. Drawn in code on top of the Higgsfield frames (see RaynaAccessories).
public enum RaynaUnlock: String, CaseIterable, Identifiable, Codable {
    case bubbles, headband, medal, baby
    public var id: String { rawValue }
    public var days: Int {
        switch self { case .bubbles: return 3; case .headband: return 7; case .medal: return 14; case .baby: return 30 }
    }
    public var title: String {
        switch self {
        case .bubbles: return "Bubble trail"
        case .headband: return "Run-day headband"
        case .medal: return "Race medal"
        case .baby: return "Baby ray buddy"
        }
    }
    public var emoji: String {
        switch self { case .bubbles: return "🫧"; case .headband: return "🎽"; case .medal: return "🏅"; case .baby: return "🐣" }
    }
    public var blurb: String {
        switch self {
        case .bubbles: return "Three days in a row! Rayna leaves a happy bubble trail."
        case .headband: return "A whole week. Rayna's got her running headband on."
        case .medal: return "Two weeks of goals. That's medal-worthy."
        case .baby: return "Thirty days! A baby ray has joined the swim."
        }
    }
}

// MARK: - Weekly recap

public struct RaynaRecap {
    public struct Day: Identifiable { public let id: String; public let label: String; public let ml: Int; public let goalMet: Bool }
    public let days: [Day]          // oldest first, 7 entries ending today
    public let totalML: Int
    public let bestDay: Day?
    public let goalDays: Int
    public let streak: Int
    public let bestStreak: Int
    public let swapsThisWeek: Int
    public let swapsTotal: Int

    public var litres: Double { Double(totalML) / 1000 }
    public var averageL: Double { litres / 7 }
    /// A standard UK bath is roughly 80 L.
    public var bathtubs: Double { litres / 80 }
    /// Rayna's paddling pool: 1,000 L.
    public var poolPercent: Int { Int((litres / 1000 * 100).rounded()) }
    public var funLine: String {
        if bathtubs >= 0.1 { return String(format: "That's %.0f%% of a bathtub, or %d%% of Rayna's paddling pool. 🛁", bathtubs * 100, poolPercent) }
        return "Every glass counts. Rayna's pool is filling up! 🌊"
    }
}

// MARK: - Extras store (history, unlocks, swaps): works on any UserDefaults (App Group on iOS, standard on macOS)

public struct RaynaExtras {
    public let d: UserDefaults
    public init(defaults: UserDefaults) {
        d = defaults
        d.register(defaults: ["swapChallenge": true])
    }

    /// Day key -> millilitres drunk (last ~60 days).
    public var history: [String: Int] {
        get { (d.dictionary(forKey: "history") as? [String: Int]) ?? [:] }
        nonmutating set {
            let keep = newValue.keys.sorted().suffix(60)
            d.set(newValue.filter { keep.contains($0.key) }, forKey: "history")
        }
    }
    public var bestStreak: Int { get { d.integer(forKey: "bestStreak") } nonmutating set { d.set(newValue, forKey: "bestStreak") } }
    public var unlocked: [RaynaUnlock] {
        get { (d.stringArray(forKey: "unlocks") ?? []).compactMap(RaynaUnlock.init(rawValue:)) }
        nonmutating set { d.set(newValue.map(\.rawValue), forKey: "unlocks") }
    }
    /// Unlocks earned but not yet celebrated in the UI (e.g. earned via a widget or notification action).
    public var pendingUnlocks: [RaynaUnlock] {
        get { (d.stringArray(forKey: "pendingUnlocks") ?? []).compactMap(RaynaUnlock.init(rawValue:)) }
        nonmutating set { d.set(newValue.map(\.rawValue), forKey: "pendingUnlocks") }
    }
    /// Evening swap-a-fizzy-drink challenge on/off.
    public var swapChallenge: Bool { get { d.bool(forKey: "swapChallenge") } nonmutating set { d.set(newValue, forKey: "swapChallenge") } }
    /// Day key -> number of drinks swapped for water.
    public var swaps: [String: Int] {
        get { (d.dictionary(forKey: "swaps") as? [String: Int]) ?? [:] }
        nonmutating set { d.set(newValue, forKey: "swaps") }
    }
    public var swapsTotal: Int { swaps.values.reduce(0, +) }
    public func swapsToday(now: Date = Date()) -> Int { swaps[RaynaCopy.dayKey(for: now)] ?? 0 }
    /// Consecutive days with at least one swap, ending today (or yesterday if none yet today).
    public func swapStreak(now: Date = Date()) -> Int {
        let s = swaps; let cal = Calendar.current
        var day = s[RaynaCopy.dayKey(for: now)] != nil ? now : (cal.date(byAdding: .day, value: -1, to: now) ?? now)
        var n = 0
        while s[RaynaCopy.dayKey(for: day)] != nil { n += 1; day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        return n
    }
    public static func isSwapTime(_ now: Date = Date()) -> Bool { Calendar.current.component(.hour, from: now) >= 18 }

    public func recordDay(_ ml: Int, now: Date = Date()) {
        var h = history; h[RaynaCopy.dayKey(for: now)] = ml; history = h
    }
    public func logSwap(now: Date = Date()) {
        var s = swaps; s[RaynaCopy.dayKey(for: now), default: 0] += 1; swaps = s
    }

    /// Call when the streak changes. Returns unlocks earned for the first time (also queued in pendingUnlocks).
    @discardableResult
    public func noteStreak(_ streak: Int) -> [RaynaUnlock] {
        if streak > bestStreak { bestStreak = streak }
        let have = Set(unlocked)
        let new = RaynaUnlock.allCases.filter { streak >= $0.days && !have.contains($0) }
        guard !new.isEmpty else { return [] }
        unlocked = unlocked + new
        pendingUnlocks = pendingUnlocks + new
        return new
    }
    public func takePendingUnlocks() -> [RaynaUnlock] {
        let p = pendingUnlocks; if !p.isEmpty { pendingUnlocks = [] }; return p
    }

    public func recap(goalDays: [String], streak: Int, now: Date = Date()) -> RaynaRecap {
        let cal = Calendar.current; let h = history; let s = swaps
        let f = DateFormatter(); f.dateFormat = "EEE"
        let days: [RaynaRecap.Day] = (0..<7).reversed().map { back in
            let date = cal.date(byAdding: .day, value: -back, to: now) ?? now
            let k = RaynaCopy.dayKey(for: date)
            return .init(id: k, label: f.string(from: date), ml: h[k] ?? 0, goalMet: goalDays.contains(k))
        }
        let week = Set(days.map(\.id))
        return RaynaRecap(days: days, totalML: days.reduce(0) { $0 + $1.ml },
                          bestDay: days.filter { $0.ml > 0 }.max(by: { $0.ml < $1.ml }),
                          goalDays: days.filter(\.goalMet).count, streak: streak, bestStreak: max(bestStreak, streak),
                          swapsThisWeek: s.filter { week.contains($0.key) }.values.reduce(0, +), swapsTotal: swapsTotal)
    }

    /// Plausible week of history for screenshots/demo mode.
    public func seedDemo(todayML: Int, streak: Int, now: Date = Date()) {
        let cal = Calendar.current
        var h: [String: Int] = [:]
        let pattern = [2250, 2750, 2500, 3000, 2500, 2750, 2500]
        for back in 1...6 { if let d = cal.date(byAdding: .day, value: -back, to: now) { h[RaynaCopy.dayKey(for: d)] = pattern[back] } }
        h[RaynaCopy.dayKey(for: now)] = todayML
        history = h
        var sw: [String: Int] = [:]
        for back in [0, 1, 2, 4] { if let d = cal.date(byAdding: .day, value: -back, to: now) { sw[RaynaCopy.dayKey(for: d)] = 1 } }
        swaps = sw
        unlocked = []; pendingUnlocks = []; bestStreak = 0
        noteStreak(streak)
        pendingUnlocks = []
    }
}

public extension RaynaCopy {
    static let swapPrompt = "Fizzy-drink swap? Trade one fizzy drink for a glass of water. No pressure, Rayna is just cheering. 🥤➡️💧"
    static let swapThanks = [
        "Swap logged! Rayna's doing a happy spin. 💧",
        "Fizz-free and fabulous! Rayna approves. 🌊",
        "Nice one. Every swap counts, and so do you. 😊"
    ]
}
