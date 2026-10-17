import Foundation

/// Rayna's words and day bookkeeping, shared by the macOS and iOS apps.
public enum RaynaCopy {
    /// One sample for each progress band, lowest threshold first. The live line comes from `QuipLines`.
    public static var quips: [(Double, String)] {
        QuipCatalog.bands.map { ($0.from, $0.lines[0].text) }
    }

    /// The line under the title. A shuffle bag keeps the same line from appearing twice in a row.
    /// Kid mode uses the same bands when every line is kid-safe, plus the kid list. Exercise day uses the exercise list until the goal.
    public static func quip(
        for progress: Double,
        at date: Date = Date(),
        exerciseDay: Bool = false,
        salt: Int = 0,
        kidMode: Bool = false,
        calendar: Calendar = .current
    ) -> String {
        QuipPicker.shared.statusLine(
            progress: progress, at: date, exerciseDay: exerciseDay,
            salt: salt, kidMode: kidMode, calendar: calendar)
    }

    public static func kidQuip(for progress: Double, at date: Date = Date(), salt: Int = 0, calendar: Calendar = .current) -> String {
        quip(for: progress, at: date, salt: salt, kidMode: true, calendar: calendar)
    }

    /// Next reminder line. Consecutive calls do not repeat the line just shown.
    public static func nextReminder(at date: Date = Date(), calendar: Calendar = .current) -> String {
        QuipPicker.shared.nextReminder(at: date, calendar: calendar)
    }

    /// Reminder spacing on iPhone and Mac. A stored value outside this list still shows, so a custom interval is not snapped away.
    public static let reminderMinutes = [30, 45, 60, 90, 120]

    /// Every reminder line. Time-of-day lines are included here.
    public static var reminders: [String] {
        QuipCatalog.lines(id: "reminder").map(\.text)
    }

    /// Reminder lines written for a particular part of the day. Already included in `reminders`.
    public static var moreReminders: [String] {
        QuipCatalog.lines(id: "reminder").filter { $0.time != nil }.map(\.text)
    }

    public static var allReminders: [String] { reminders }
    public static let swapText = "Fizzy-drink swap? Trade your next can of pop for a glass of water. Rayna says thanks! 🥤➡️💧"

    public static let swapButtonTitle = "I swapped a fizzy drink for water"

    public static func swapDetail(streak: Int, total: Int) -> String {
        streak > 0
            ? "Swap streak: \(streak) evening\(streak == 1 ? "" : "s") · \(total) total"
            : "Optional fizzy-drink challenge. Logs a glass too."
    }

    public static func amountTitle(ml: Int, glassML: Int, kidMode: Bool) -> String {
        if kidMode { return "\(glassML > 0 ? ml / glassML : 0) cups" }
        return String(format: "%.2f L", Double(ml) / 1000)
    }

    public static func percent(ml: Int, goal: Int) -> Int {
        goal > 0 ? Int((min(Double(ml) / Double(goal), 1) * 100).rounded()) : 0
    }

    public static func amountSubtitle(ml: Int, goal: Int, glassML: Int, kidMode: Bool) -> String {
        let pct = percent(ml: ml, goal: goal)
        if kidMode {
            let cups = Int((Double(goal) / Double(max(glassML, 1))).rounded(.up))
            return "of \(cups) cups · \(pct)%"
        }
        return "of \(String(format: "%.1f", Double(goal) / 1000)) L · \(pct)%"
    }

    /// Pod tile caption. Same litres and percent as the main screen (`1.00 L · 31%`).
    /// A member who has not synced today shows `0.00 L · 0%`. Kid mode, when enabled, keeps cups.
    public static func podTileLabel(_ member: PodMember) -> String {
        let ml = member.isToday ? member.ml : 0
        let pct = member.isToday ? percent(ml: member.ml, goal: member.goal) : 0
        if member.isKid && RaynaFeatures.kidMode {
            return "\(member.isToday ? member.glasses : 0) cups · \(pct)%"
        }
        return String(format: "%.2f L · %d%%", Double(ml) / 1000, pct)
    }

    public static func addGlassLabel(glassML: Int, kidMode: Bool) -> String {
        kidMode ? "+1 cup" : "+1 glass · \(glassML) ml"
    }

    /// SF Symbol for the exercise-day toggle. `dumbbell.fill` is on macOS 13 and iOS 17.
    public static let exerciseDaySymbol = "dumbbell.fill"

    /// Short toggle. The stored flag stays `runDay`. Longer settings copy says "heavy exercise day".
    public static func runDayLabel(bonusML: Int) -> String { "Exercise day (+\(bonusML) ml)" }

    public static func dayKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    public static func yesterdayKey(from date: Date = Date()) -> String {
        dayKey(for: Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date)
    }

    /// True if `date` falls inside quiet hours (minutes since midnight; wraps past midnight).
    public static func isQuiet(_ date: Date, start: Int, end: Int) -> Bool {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if start == end { return false }
        if start < end { return m >= start && m < end }
        return m >= start || m < end
    }
}
