import Foundation

/// Reads `QuipLines` and picks one line at a time.
enum QuipCatalog {
    struct Line: Equatable {
        var text: String
        var time: String?
        var kidSafe: Bool
    }

    struct Category {
        var id: String
        var from: Double?
        var lines: [Line]
    }

    struct Band {
        var id: String
        var from: Double
        var lines: [Line]
    }

    static let categories: [Category] = QuipLines.categories.map { cat in
        Category(id: cat.id, from: cat.from, lines: cat.lines.map {
            Line(text: $0.text, time: $0.time, kidSafe: $0.kidSafe)
        })
    }

    static var bands: [Band] {
        categories.compactMap { cat in
            guard let from = cat.from else { return nil }
            return Band(id: cat.id, from: from, lines: cat.lines)
        }.sorted { $0.from < $1.from }
    }

    static var totalCount: Int { categories.reduce(0) { $0 + $1.lines.count } }

    static var allKidSafe: Bool { categories.allSatisfy { $0.lines.allSatisfy(\.kidSafe) } }

    static func lines(id: String) -> [Line] {
        categories.first { $0.id == id }?.lines ?? []
    }

    /// Progress band for a fraction of the goal. Goal is its own band at 1.
    static func band(for progress: Double) -> String {
        let rows = bands
        return rows.last { progress >= $0.from }?.id ?? rows.first?.id ?? "start"
    }

    /// Which list the live ray should read. Kid mode keeps the progress band, because every line is kid-safe.
    /// Exercise day uses the exercise list until the goal, and kid mode has no exercise day.
    static func situation(for progress: Double, kidMode: Bool, exerciseDay: Bool) -> String {
        if progress >= 1 { return "goal" }
        if exerciseDay && !kidMode { return "exercise" }
        return band(for: progress)
    }

    static func dayPart(for date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }

    /// Lines that fit this hour. Untimed lines always fit. Kid mode on an in-progress band also hears the kid list.
    /// While the Halloween cape is on, every status list before the goal is the halloween list alone.
    /// Reminders and the goal celebration stay on their own lists.
    static func pool(id: String, at date: Date, kidMode: Bool, calendar: Calendar = .current, seasonal: Bool = false) -> [String] {
        let part = dayPart(for: date, calendar: calendar)
        if seasonal && id != "reminder" && id != "goal" {
            return eligible("halloween", part: part).map(\.text)
        }
        var chosen = eligible(id, part: part)
        if kidMode {
            let safe = chosen.filter(\.kidSafe)
            if safe.count != chosen.count {
                chosen = safe.isEmpty ? eligible("kid", part: part) : safe
            }
            if id != "kid" && id != "reminder" && id != "goal" && id != "exercise" {
                var seen = Set(chosen.map(\.text))
                for line in eligible("kid", part: part) where line.kidSafe && seen.insert(line.text).inserted {
                    chosen.append(line)
                }
            }
        }
        return chosen.map(\.text)
    }

    private static func eligible(_ id: String, part: String) -> [Line] {
        let lines = lines(id: id)
        let matched = lines.filter { $0.time == nil || $0.time == part }
        return matched.isEmpty ? lines : matched
    }
}

/// One shuffled copy of a list. The same line is not drawn twice in a row, including across a refill.
final class QuipShuffleBag {
    private let lines: [String]
    private var remaining: [String] = []
    private var last: String?
    private let random: () -> UInt64

    init(lines: [String], random: @escaping () -> UInt64 = { UInt64.random(in: 0..<UInt64.max) }) {
        self.lines = lines
        self.random = random
    }

    func next() -> String {
        let pool = lines.isEmpty ? ["Splash me?"] : lines
        if remaining.isEmpty {
            remaining = shuffled(pool)
            if remaining.count > 1, remaining[0] == last {
                remaining.swapAt(0, 1)
            }
        }
        let line = remaining.removeFirst()
        last = line
        return line
    }

    private func shuffled(_ items: [String]) -> [String] {
        var copy = items
        var i = copy.count - 1
        while i > 0 {
            copy.swapAt(i, Int(random() % UInt64(i + 1)))
            i -= 1
        }
        return copy
    }
}

/// Remembers the line for the current band, hour and glass count so a redraw does not advance the bag.
final class QuipPicker {
    static let shared = QuipPicker()

    private let lock = NSLock()
    private var bags: [String: QuipShuffleBag] = [:]
    private var cacheKey: String?
    private var cacheSalt: Int?
    private var cacheLine: String?

    func statusLine(
        progress: Double,
        at date: Date,
        exerciseDay: Bool,
        salt: Int,
        kidMode: Bool,
        calendar: Calendar,
        seasonal: Bool = false
    ) -> String {
        let situation = QuipCatalog.situation(for: progress, kidMode: kidMode, exerciseDay: exerciseDay)
        let part = QuipCatalog.dayPart(for: date, calendar: calendar)
        let key = "\(situation)|\(part)|\(kidMode)|\(seasonal)"
        let lines = QuipCatalog.pool(id: situation, at: date, kidMode: kidMode, calendar: calendar, seasonal: seasonal)
        lock.lock()
        defer { lock.unlock() }
        if cacheKey == key, cacheSalt == salt, let cacheLine { return cacheLine }
        let line = drawLocked(key: key, lines: lines)
        cacheKey = key
        cacheSalt = salt
        cacheLine = line
        return line
    }

    func nextReminder(at date: Date, calendar: Calendar) -> String {
        let part = QuipCatalog.dayPart(for: date, calendar: calendar)
        let lines = QuipCatalog.pool(id: "reminder", at: date, kidMode: false, calendar: calendar)
        lock.lock()
        defer { lock.unlock() }
        return drawLocked(key: "reminder|\(part)", lines: lines)
    }

    func reset() {
        lock.lock()
        bags.removeAll()
        cacheKey = nil
        cacheSalt = nil
        cacheLine = nil
        lock.unlock()
    }

    private func drawLocked(key: String, lines: [String]) -> String {
        let bag = bags[key] ?? QuipShuffleBag(lines: lines)
        let line = bag.next()
        bags[key] = bag
        return line
    }
}
