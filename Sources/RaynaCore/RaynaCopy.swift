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
        (1, "GOAL! Happy spin deployed. You're race-ready! 🎉")
    ]
    public static func quip(for progress: Double) -> String {
        quips.last(where: { progress >= $0.0 })?.1 ?? quips[0].1
    }

    public static let reminders = [
        "Sip o'clock! Half-marathon legs run on water, not wishes. 💧",
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
    public static let swapText = "Evening swap? Trade your next drink for a glass of water. Tomorrow-you says cheers. 🍺➡️💧"

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
