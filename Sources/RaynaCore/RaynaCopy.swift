import Foundation

/// Rayna's words and day bookkeeping, shared by the macOS and iOS apps.
public enum RaynaCopy {
    public static let quips: [(Double, String)] = [
        (0, "Morning! I'm a bit… flat. Splash me? 🫠"),
        (0.15, "Ooh, a ripple. Keep it flowing!"),
        (0.35, "Gliding nicely. Your calves send regards. 🦵"),
        (0.55, "Over halfway! Stingrays are happy, and so am I. 😄"),
        (0.75, "Nearly there — tide's coming in! 🌊"),
        (0.9, "One more glass and I do a happy spin…"),
        (1, "GOAL! Happy spin deployed. You're set for the day! 🎉")
    ]
    /// Simpler words for kid mode.
    public static let kidQuips: [(Double, String)] = [
        (0, "Hi! I'm thirsty. Can we drink some water? 💧"),
        (0.25, "Yum! More water please! 🐟"),
        (0.5, "Halfway! You're doing great! ⭐️"),
        (0.75, "Nearly there! Just a few more cups! 🌊"),
        (1, "You did it! Water champion! 🏆🎉")
    ]
    public static func kidQuip(for progress: Double) -> String {
        kidQuips.last(where: { progress >= $0.0 })?.1 ?? kidQuips[0].1
    }
    public static func quip(for progress: Double) -> String {
        quips.last(where: { progress >= $0.0 })?.1 ?? quips[0].1
    }

    /// Reminder spacing on iPhone and Mac. A stored value outside this list still shows, so a custom interval is not snapped away.
    public static let reminderMinutes = [30, 45, 60, 90, 120]

    public static let reminders = [
        "Sip o'clock! A heavy session needs water, not wishes. 💧",
        "Psst. Your stingray is drying out. One glass?",
        "Hydration check! 250 ml and I'll stop flapping. 🌊"
    ]
    /// Extra, phone-flavoured reminder lines (iOS notifications rotate through these + `reminders`).
    public static let moreReminders = [
        "Blub blub. That's stingray for 'drink some water'. 🐟",
        "My wings feel crispy. A glass of water would fix that! 💦",
        "Tide's going out… top me up? 🌊",
        "Water break! I'll do a little wiggle if you do. 🪼",
        "Fun fact: I'm 100% happier when you're hydrated. 😄"
    ]
    public static var allReminders: [String] { reminders + moreReminders }
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

    public static func amountSubtitle(ml: Int, goal: Int, glassML: Int, kidMode: Bool) -> String {
        let pct = goal > 0 ? Int((min(Double(ml) / Double(goal), 1) * 100).rounded()) : 0
        if kidMode {
            let cups = Int((Double(goal) / Double(max(glassML, 1))).rounded(.up))
            return "of \(cups) cups · \(pct)%"
        }
        return "of \(String(format: "%.1f", Double(goal) / 1000)) L · \(pct)%"
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
