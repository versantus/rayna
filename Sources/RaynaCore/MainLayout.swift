import Foundation

/// Which main screen the iPhone shows. Stored as `mainLayout` inside the existing RaynaPrefs payload.
/// Missing or unknown values are Immersive. The Mac panel does not use this; it only has to decode the key.
public enum MainLayout: String, Codable, CaseIterable, Hashable {
    case immersive
    case hero
    case balanced

    public static let storageKey = "mainLayout"

    /// Immersive is the default. A missing or unrecognised value stays Immersive.
    public static func decode(_ raw: String?) -> MainLayout {
        guard let raw, let layout = MainLayout(rawValue: raw) else { return .immersive }
        return layout
    }

    public var title: String {
        switch self {
        case .immersive: return "Immersive"
        case .hero: return "Hero"
        case .balanced: return "Balanced"
        }
    }
}

/// Whether today's bonus is added, and whether a Health workout should turn the day on.
/// The stored keys stay `runDay`, `runBonusML`, `healthRunDay` and `healthAutoRun`.
public enum ExerciseDay {
    public struct Session: Equatable {
        public var at: Date
        /// A walk or stretch is not heavy, so it does not count.
        public var heavy: Bool
        public init(at: Date, heavy: Bool) { self.at = at; self.heavy = heavy }
    }

    public static func goal(base: Int, extraOn: Bool, exerciseDay: Bool, bonus: Int, kidMode: Bool) -> Int {
        guard extraOn, exerciseDay, !kidMode, bonus > 0 else { return base }
        return base + bonus
    }

    /// True when a heavy workout falls on the same calendar day as `now`. Yesterday does not count.
    public static func hasHeavyWorkoutToday(_ sessions: [Session], now: Date, calendar: Calendar = .current) -> Bool {
        sessions.contains { $0.heavy && calendar.isDate($0.at, inSameDayAs: now) }
    }

    /// Auto-detect is off, kid mode, or a day already applied: do not read Health.
    public static func shouldAutoApply(extraOn: Bool, autoDetect: Bool, kidMode: Bool,
                                       alreadyAppliedDay: String, today: String, hasHeavyToday: Bool) -> Bool {
        extraOn && autoDetect && !kidMode && alreadyAppliedDay != today && hasHeavyToday
    }
}
