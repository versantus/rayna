import Foundation

/// One reusable season gate. Halloween is the only season that ships.
/// A later season adds a window and its own copy; it does not get its own prefs system.
public enum SeasonID: String, Equatable {
    case halloween
}

/// Where the calendar sits inside a season.
/// Automatic: the costume is on unless the person turns it off.
/// Manual: it is off unless they turn it back on.
/// Closed: nothing seasonal is offered.
public enum SeasonPhase: Equatable {
    case closed, automatic, manual
}

/// Debug override. Never stored as a user preference.
public enum SeasonForce: Equatable {
    case none, showing, hidden
}

public struct SeasonWindow: Equatable {
    public var id: SeasonID
    public var startMonth: Int
    public var startDay: Int
    /// Last day the costume is on by itself. Inclusive.
    public var endMonth: Int
    public var endDay: Int
    /// Last day it can still be turned on by hand. Inclusive.
    public var manualEndMonth: Int
    public var manualEndDay: Int
    /// Opt out of the automatic window. Missing means on.
    public var offKey: String
    /// Opt in during the manual window. Missing means off.
    public var manualOnKey: String
    public var firstYear: Int
    public var lastYear: Int

    public init(id: SeasonID, startMonth: Int, startDay: Int, endMonth: Int, endDay: Int,
                manualEndMonth: Int, manualEndDay: Int, offKey: String, manualOnKey: String,
                firstYear: Int, lastYear: Int) {
        self.id = id
        self.startMonth = startMonth
        self.startDay = startDay
        self.endMonth = endMonth
        self.endDay = endDay
        self.manualEndMonth = manualEndMonth
        self.manualEndDay = manualEndDay
        self.offKey = offKey
        self.manualOnKey = manualOnKey
        self.firstYear = firstYear
        self.lastYear = lastYear
    }
}

public enum SeasonGate {
    /// 17 October through 1 November: on unless turned off.
    /// 2 November through 15 November: off unless turned on.
    /// After that, unavailable until next 17 October.
    /// Years outside 2026...2035 stay hidden (a stuck clock must not grow a cape).
    public static let halloween = SeasonWindow(
        id: .halloween,
        startMonth: 10, startDay: 17,
        endMonth: 11, endDay: 1,
        manualEndMonth: 11, manualEndDay: 15,
        offKey: "halloweenOff",
        manualOnKey: "halloweenManualOn",
        firstYear: 2026, lastYear: 2035)

    /// Month/day inside an inclusive span. A span with `end` before `start` crosses 1 January.
    public static func inSpan(month: Int, day: Int, startMonth: Int, startDay: Int, endMonth: Int, endDay: Int) -> Bool {
        let value = month * 100 + day
        let start = startMonth * 100 + startDay
        let end = endMonth * 100 + endDay
        if start <= end { return value >= start && value <= end }
        return value >= start || value <= end
    }

    public static func phase(_ s: SeasonWindow = SeasonGate.halloween, now: Date = Date(), calendar: Calendar = .current) -> SeasonPhase {
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        if inSpan(month: month, day: day, startMonth: s.startMonth, startDay: s.startDay, endMonth: s.endMonth, endDay: s.endDay) {
            return .automatic
        }
        // The hand-turned window is the rest of the span from the season's first day through the manual last day.
        if inSpan(month: month, day: day, startMonth: s.startMonth, startDay: s.startDay,
                  endMonth: s.manualEndMonth, endDay: s.manualEndDay) {
            return .manual
        }
        return .closed
    }

    /// The automatic window only (17 October through 1 November for Halloween).
    public static func inWindow(_ s: SeasonWindow = SeasonGate.halloween, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        phase(s, now: now, calendar: calendar) == .automatic
    }

    /// The switch the Settings row shows. Ignores the debug force and the year guard.
    public static func costumeOn(_ s: SeasonWindow = SeasonGate.halloween, defaults: UserDefaults, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch phase(s, now: now, calendar: calendar) {
        case .automatic:
            if defaults.object(forKey: s.offKey) == nil { return true }
            return !defaults.bool(forKey: s.offKey)
        case .manual:
            return defaults.bool(forKey: s.manualOnKey)
        case .closed:
            return false
        }
    }

    public static func setCostume(_ on: Bool, _ s: SeasonWindow = SeasonGate.halloween, defaults: UserDefaults, now: Date = Date(), calendar: Calendar = .current) {
        switch phase(s, now: now, calendar: calendar) {
        case .automatic:
            defaults.set(!on, forKey: s.offKey)
        case .manual:
            defaults.set(on, forKey: s.manualOnKey)
        case .closed:
            break
        }
    }

    public static func settingsAvailable(_ s: SeasonWindow = SeasonGate.halloween, now: Date = Date(), calendar: Calendar = .current,
                                         featuresOn: Bool = RaynaFeatures.halloween) -> Bool {
        guard featuresOn, yearOK(s, now: now, calendar: calendar) else { return false }
        return phase(s, now: now, calendar: calendar) != .closed
    }

    /// Hitting the goal any day the season is offered can earn the stamp, even if the cape is turned off.
    public static func canEarn(_ s: SeasonWindow = SeasonGate.halloween, now: Date = Date(), calendar: Calendar = .current,
                               featuresOn: Bool = RaynaFeatures.halloween) -> Bool {
        settingsAvailable(s, now: now, calendar: calendar, featuresOn: featuresOn)
    }

    public static func isShowing(_ s: SeasonWindow = SeasonGate.halloween, now: Date = Date(), calendar: Calendar = .current,
                                 defaults: UserDefaults, force: SeasonForce = .none,
                                 featuresOn: Bool = RaynaFeatures.halloween) -> Bool {
        switch force {
        case .showing: return true
        case .hidden: return false
        case .none: break
        }
        guard featuresOn, yearOK(s, now: now, calendar: calendar) else { return false }
        return costumeOn(s, defaults: defaults, now: now, calendar: calendar)
    }

    /// `RAYNA_SEASON=halloween` forces the cape. `RAYNA_SEASON=off` hides it.
    /// Screenshot launches pass the value as `SIMCTL_CHILD_RAYNA_SEASON`. Debug builds only.
    public static func environmentForce(_ env: [String: String]? = nil) -> SeasonForce {
        #if DEBUG
        let env = env ?? ProcessInfo.processInfo.environment
        switch (env["RAYNA_SEASON"] ?? env["SIMCTL_CHILD_RAYNA_SEASON"])?.lowercased() {
        case "halloween": return .showing
        case "off": return .hidden
        default: return .none
        }
        #else
        _ = env
        return .none
        #endif
    }

    public static func showing(defaults: UserDefaults, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        isShowing(now: now, calendar: calendar, defaults: defaults, force: environmentForce())
    }

    private static func yearOK(_ s: SeasonWindow, now: Date, calendar: Calendar) -> Bool {
        let year = calendar.component(.year, from: now)
        return year >= s.firstYear && year <= s.lastYear
    }
}

/// Little-treat beats. The bag never returns nothing while the day's cap still has room.
public enum SeasonBeat: String, CaseIterable, Equatable {
    case flutter, pop, sparkle
}

enum SeasonTreats {
    static let dailyCap = 6

    static func nextBeat(count: Int, last: SeasonBeat?, draw: Int) -> SeasonBeat? {
        guard count < dailyCap else { return nil }
        let all = SeasonBeat.allCases
        guard !all.isEmpty else { return nil }
        // `count` walks the bag forward, so a steady draw still visits every beat.
        var index = abs(draw + count) % all.count
        if all.count > 1, all[index] == last { index = (index + 1) % all.count }
        return all[index]
    }

    static func nextLine(after last: String?, draw: Int) -> String {
        let lines = SeasonCopy.treats
        guard !lines.isEmpty else { return "" }
        var index = abs(draw) % lines.count
        if lines.count > 1, lines[index] == last { index = (index + 1) % lines.count }
        return lines[index]
    }
}

/// The Moonleap trophy. A string in `unlocks`, never a `RaynaUnlock`, so it cannot take a wear slot.
public enum SeasonStamp {
    public static let id = "moonleap"
    public static let title = "Moonleap"

    /// The card is on the grid only while the costume is showing. Off-season the string stays put.
    public static func showsCard(showing: Bool) -> Bool { showing }
}
