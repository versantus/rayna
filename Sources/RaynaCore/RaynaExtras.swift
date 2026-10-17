import SwiftUI
import Foundation

// MARK: - Unlocks ("Rayna evolves")

/// Unlocks. Streak badges are drawn in code (see RaynaAccessories). Over-achiever badges use
/// imagesets `badge-<id>` (band3 with the badge baked in) and `badge-<id>-overlay` (badge art alone).
/// `symbolName` is the fallback when that asset is missing.
public enum RaynaUnlock: String, CaseIterable, Identifiable, Codable {
    /// How a badge is earned. Streak badges are the only ones `noteStreak` awards.
    public enum Rule: Equatable {
        case streakDays(Int)
        case dayPercent(Int)
        case exceedStreak(Int)
        case personalBest
        case podOver
    }

    case bubbles, headband, medal, baby
    /// 125% / 150% / 200% of today's goal.
    case surge, tide, flood
    /// Consecutive days strictly over the goal.
    case over3, over7, over30
    case personalBest
    /// Everyone in the pod beat their own goal today.
    case podWave

    public var id: String { rawValue }
    public var rule: Rule {
        switch self {
        case .bubbles: return .streakDays(3)
        case .headband: return .streakDays(7)
        case .medal: return .streakDays(14)
        case .baby: return .streakDays(30)
        case .surge: return .dayPercent(125)
        case .tide: return .dayPercent(150)
        case .flood: return .dayPercent(200)
        case .over3: return .exceedStreak(3)
        case .over7: return .exceedStreak(7)
        case .over30: return .exceedStreak(30)
        case .personalBest: return .personalBest
        case .podWave: return .podOver
        }
    }
    /// Days threshold for streak-style badges. Zero for badges that are not a day count.
    public var days: Int {
        switch rule {
        case .streakDays(let n), .exceedStreak(let n): return n
        default: return 0
        }
    }
    /// SF Symbol used only when the badge imageset is missing. Nil for the original drawn accessories.
    public var symbolName: String? {
        switch self {
        case .bubbles, .headband, .medal, .baby: return nil
        case .surge: return "bolt.fill"
        case .tide: return "drop.fill"
        case .flood: return "sparkles"
        case .over3: return "flame"
        case .over7: return "flame.fill"
        case .over30: return "crown.fill"
        case .personalBest: return "trophy.fill"
        case .podWave: return "person.3.fill"
        }
    }
    /// Badge art alone, transparent, same square as Rayna. Nil for code-drawn streak accessories.
    public var overlayAssetName: String? {
        symbolName == nil ? nil : "badge-\(rawValue)-overlay"
    }
    /// Band3 still with the badge baked in. Nil for code-drawn streak accessories.
    public var compositeAssetName: String? {
        symbolName == nil ? nil : "badge-\(rawValue)"
    }
    public var title: String {
        switch self {
        case .bubbles: return "Bubble trail"
        case .headband: return "Run-day headband"
        case .medal: return "Race medal"
        case .baby: return "Baby ray buddy"
        case .surge: return "Ripple"
        case .tide: return "Spring tide"
        case .flood: return "Flood tide"
        case .over3: return "Extra mile"
        case .over7: return "Week of extra"
        case .over30: return "Month of extra"
        case .personalBest: return "Personal best"
        case .podWave: return "Pod wave"
        }
    }
    public var emoji: String {
        switch self {
        case .bubbles: return "🫧"
        case .headband: return "🎽"
        case .medal: return "🏅"
        case .baby: return "🐣"
        case .surge: return "⚡️"
        case .tide: return "💧"
        case .flood: return "✨"
        case .over3: return "🔥"
        case .over7: return "🔥"
        case .over30: return "👑"
        case .personalBest: return "🏆"
        case .podWave: return "🌊"
        }
    }
    public var blurb: String {
        switch self {
        case .bubbles: return "Three days in a row! Rayna leaves a happy bubble trail."
        case .headband: return "A whole week. Rayna's got her running headband on."
        case .medal: return "Two weeks of goals. That's medal-worthy."
        case .baby: return "Thirty days! A baby ray has joined the swim."
        case .surge: return "125% of your goal in a day. Rayna's riding a ripple."
        case .tide: return "150% today. That's a spring tide."
        case .flood: return "Double your goal. Flood tide! Rayna is delighted."
        case .over3: return "Three days in a row over your goal."
        case .over7: return "A whole week of beating your goal."
        case .over30: return "Thirty days over goal. That's legendary."
        case .personalBest: return "Your biggest drinking day yet."
        case .podWave: return "Everyone in the pod beat their goal today."
        }
    }
    public func lockedHint(streak: Int, bestStreak: Int) -> String {
        switch rule {
        case .streakDays(let d):
            return "\(d)-day streak to unlock · \(max(0, d - max(streak, bestStreak))) to go"
        case .dayPercent(let p):
            return "Drink \(p)% of your goal in a day"
        case .exceedStreak(let d):
            return "Beat your goal \(d) days in a row"
        case .personalBest:
            return "Drink more than any day so far"
        case .podOver:
            return "Everyone in your pod beats their goal on the same day"
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
        d.register(defaults: ["swapChallenge": true, "rayFactsOn": true])
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
    // MARK: Ray Facts (1.1)
    public var rayFactsOn: Bool { get { d.bool(forKey: "rayFactsOn") } nonmutating set { d.set(newValue, forKey: "rayFactsOn") } }
    /// Milestone facts: Rayna shares a fact when today's progress first crosses 25 / 50 / 75 / 100 %.
    /// Returns the fact to show (a newly unlocked one, or a favourite once all are collected).
    public func factForMilestone(progress: Double, now: Date = Date()) -> RayFact? {
        guard rayFactsOn else { return nil }
        let day = RaynaCopy.dayKey(for: now)
        let m = min(4, Int((progress + 0.0001) * 4))
        let done = d.string(forKey: "factMilestoneDay") == day ? d.integer(forKey: "factMilestone") : 0
        guard m > done else { return nil }
        d.set(day, forKey: "factMilestoneDay"); d.set(m, forKey: "factMilestone")
        return unlockNextFact() ?? RayFacts.all.randomElement()
    }
    /// How many facts are unlocked (facts unlock in order, one per milestone).
    public var factsUnlocked: Int { get { d.integer(forKey: "factsUnlocked") } nonmutating set { d.set(min(newValue, RayFacts.all.count), forKey: "factsUnlocked") } }
    /// Ray Facts are ephemeral (no collection); this count only tracks which have been shown, to avoid repeats.
    /// Shows the next fact (if Ray Facts is on and any remain) and returns it.
    @discardableResult
    public func unlockNextFact() -> RayFact? {
        guard rayFactsOn, factsUnlocked < RayFacts.all.count else { return nil }
        let f = RayFacts.all[factsUnlocked]
        factsUnlocked += 1
        return f
    }

    // MARK: Kid mode (1.1)
    /// Kid mode is behind `RaynaFeatures.kidMode` (off for now): when off, kid mode reads as false everywhere.
    public var kidMode: Bool { get { RaynaFeatures.kidMode && d.bool(forKey: "kidMode") } nonmutating set { d.set(newValue, forKey: "kidMode") } }
    /// Adult goal/glass saved while kid mode is on, restored when it's turned off.
    public var adultGoalML: Int { get { d.integer(forKey: "adultGoalML") } nonmutating set { d.set(newValue, forKey: "adultGoalML") } }
    public var adultGlassML: Int { get { d.integer(forKey: "adultGlassML") } nonmutating set { d.set(newValue, forKey: "adultGlassML") } }

    /// Turns kid mode on or off. Returns the goal and glass to store, or nil when the feature flag is off or nothing changes.
    /// Kid mode uses a 1.5 L goal in 200 ml cups and puts the grown-up sizes back afterwards.
    public func applyKidMode(_ on: Bool, goalML: Int, glassML: Int) -> (goalML: Int, glassML: Int)? {
        guard RaynaFeatures.kidMode, on != kidMode else { return nil }
        if on {
            adultGoalML = goalML
            adultGlassML = glassML
            kidMode = true
            return (1500, 200)
        }
        let goal = adultGoalML > 0 ? adultGoalML : goalML
        let glass = adultGlassML > 0 ? adultGlassML : glassML
        kidMode = false
        return (goal, glass)
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

    /// Call when the streak changes. Awards streak badges only (not the over-achiever set).
    @discardableResult
    public func noteStreak(_ streak: Int) -> [RaynaUnlock] {
        if streak > bestStreak { bestStreak = streak }
        let earned = RaynaUnlock.allCases.filter {
            if case .streakDays(let days) = $0.rule { return streak >= days }
            return false
        }
        return award(earned)
    }

    /// Awards percent-of-goal, over-goal streak and personal-best badges from today's total.
    /// A day beats the goal only when `ml > goal`. Earlier days are compared with this same goal
    /// (history stores millilitres, not the goal that day). The first logged day is not a personal best.
    @discardableResult
    public func noteIntake(ml: Int, goal: Int, now: Date = Date()) -> [RaynaUnlock] {
        guard goal > 0, ml > 0 else { return [] }
        var earned: [RaynaUnlock] = []
        let percent = ml * 100 / goal
        let over = exceedStreak(goal: goal, now: now)
        for badge in RaynaUnlock.allCases {
            switch badge.rule {
            case .dayPercent(let need) where percent >= need: earned.append(badge)
            case .exceedStreak(let days) where over >= days: earned.append(badge)
            case .personalBest where isPersonalBest(ml: ml, now: now): earned.append(badge)
            default: break
            }
        }
        return award(earned)
    }

    /// Awards the pod badge once, when every member has beaten their own goal today.
    @discardableResult
    public func notePodOverAchieved(_ over: Bool) -> [RaynaUnlock] {
        guard over else { return [] }
        return award(RaynaUnlock.allCases.filter { if case .podOver = $0.rule { return true }; return false })
    }

    /// Consecutive days with `ml > goal`, ending today. Today must itself be over; a streak does not
    /// carry through a morning before today's extra glass.
    public func exceedStreak(goal: Int, now: Date = Date()) -> Int {
        guard goal > 0 else { return 0 }
        let cal = Calendar.current
        let h = history
        var day = now
        var n = 0
        while n < 60 {
            if (h[RaynaCopy.dayKey(for: day)] ?? 0) <= goal { break }
            n += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    /// True when today is strictly above every earlier day, and at least one earlier day was logged.
    public func isPersonalBest(ml: Int, now: Date = Date()) -> Bool {
        let today = RaynaCopy.dayKey(for: now)
        let prev = history.filter { $0.key != today }.values.max() ?? 0
        return prev > 0 && ml > prev
    }

    /// Inserts badges the same way a real award does. Returns only the ones that were new.
    /// Debug builds call this from `RAYNA_BADGES` and the Unlock all badges button. Tests call it too.
    @discardableResult
    public func unlockForTesting(_ badges: [RaynaUnlock]) -> [RaynaUnlock] {
        award(badges)
    }

    /// `all`, or a comma-separated list of `RaynaUnlock` raw values. Unknown tokens are skipped.
    public static func badges(from spec: String) -> [RaynaUnlock] {
        let trimmed = spec.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.compare("all", options: .caseInsensitive) == .orderedSame { return RaynaUnlock.allCases }
        return trimmed.split(separator: ",").compactMap {
            RaynaUnlock(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    @discardableResult
    private func award(_ candidates: [RaynaUnlock]) -> [RaynaUnlock] {
        var seen = Set(unlocked)
        let fresh = candidates.filter { seen.insert($0).inserted }
        guard !fresh.isEmpty else { return [] }
        unlocked = unlocked + fresh
        pendingUnlocks = pendingUnlocks + fresh
        return fresh
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


/// Ray friends who visit Rayna in kid mode as the streak grows.
public enum RayVisitor: String, CaseIterable, Identifiable {
    case manta, eagle, electric
    public var id: String { rawValue }
    public var days: Int { switch self { case .manta: return 3; case .eagle: return 7; case .electric: return 14 } }
    public var kind: RayKind { switch self { case .manta: return .manta; case .eagle: return .eagle; case .electric: return .electric } }
    public var name: String { switch self { case .manta: return "Milo the manta"; case .eagle: return "Ellie the eagle ray"; case .electric: return "Zap the electric ray" } }
    public static func visiting(streak: Int) -> [RayVisitor] { allCases.filter { streak >= $0.days } }
}

/// Visitors gently swimming across the water (kid mode).
public struct RayVisitorsLayer: View {
    public var visitors: [RayVisitor]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init(visitors: [RayVisitor]) { self.visitors = visitors }
    public var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { tl in
                let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                ForEach(Array(visitors.enumerated()), id: \.element) { i, v in
                    let speed = 0.03 + Double(i) * 0.012
                    let phase = (t * speed + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
                    let x = geo.size.width * (1.15 - 1.3 * phase)
                    let y = geo.size.height * (0.55 + 0.12 * Double(i)) + sin(t * 1.3 + Double(i)) * 8
                    RayGlyph(kind: v.kind).frame(width: 46, height: 46).opacity(0.85)
                        .rotationEffect(.degrees(-90))
                        .position(x: x, y: y)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(visitors.isEmpty ? "" : "Visiting: " + visitors.map(\.name).joined(separator: ", "))
    }
}

/// Feature flags. Kid mode (and family-pod kid marking) is built but hidden until Nik turns it on.
public enum RaynaFeatures {
    public static let kidMode = false
}
