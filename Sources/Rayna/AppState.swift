import Foundation
import SwiftUI
import ServiceManagement

final class AppState: ObservableObject {
    static let shared = AppState()
    private let d = UserDefaults.standard

    @Published var totalML: Int { didSet { d.set(totalML, forKey: "totalML") } }
    @Published var log: [Date] { didSet { d.set(log, forKey: "log") } }
    @Published var runDay: Bool { didSet { d.set(runDay, forKey: "runDay"); checkGoal() } }
    @Published var goalML: Int { didSet { d.set(goalML, forKey: "goalML"); checkGoal() } }
    @Published var glassML: Int { didSet { d.set(glassML, forKey: "glassML") } }
    @Published var intervalMin: Int { didSet { d.set(intervalMin, forKey: "intervalMin"); NotificationManager.shared.resetSchedule() } }
    @Published var quietStartMin: Int { didSet { d.set(quietStartMin, forKey: "quietStartMin") } }
    @Published var quietEndMin: Int { didSet { d.set(quietEndMin, forKey: "quietEndMin") } }
    @Published var eveningSwap: Bool { didSet { d.set(eveningSwap, forKey: "eveningSwap") } }
    @Published var streak: Int { didSet { d.set(streak, forKey: "streak") } }
    @Published var systemNotifications: Bool { didSet { d.set(systemNotifications, forKey: "systemNotifications"); if systemNotifications { NotificationManager.shared.requestAuth() } } }
    @Published var glassEvent = 0
    @Published var celebrate = false
    @Published var launchAtLogin: Bool = false

    private var dayKey: String { didSet { d.set(dayKey, forKey: "dayKey") } }
    private var lastGoalDay: String { didSet { d.set(lastGoalDay, forKey: "lastGoalDay") } }
    var lastSwapDay: String { didSet { d.set(lastSwapDay, forKey: "lastSwapDay") } }

    private var timer: Timer?

    private init() {
        d.register(defaults: [
            "goalML": 2500, "glassML": 250, "intervalMin": 50,
            "quietStartMin": 22 * 60, "quietEndMin": 7 * 60 + 30,
            "eveningSwap": true
        ])
        totalML = d.integer(forKey: "totalML")
        log = (d.array(forKey: "log") as? [Date]) ?? []
        runDay = d.bool(forKey: "runDay")
        goalML = d.integer(forKey: "goalML")
        glassML = d.integer(forKey: "glassML")
        intervalMin = min(60, max(45, d.integer(forKey: "intervalMin")))
        quietStartMin = d.integer(forKey: "quietStartMin")
        quietEndMin = d.integer(forKey: "quietEndMin")
        eveningSwap = d.bool(forKey: "eveningSwap")
        streak = d.integer(forKey: "streak")
        systemNotifications = d.bool(forKey: "systemNotifications")
        dayKey = d.string(forKey: "dayKey") ?? AppState.key(for: Date())
        lastGoalDay = d.string(forKey: "lastGoalDay") ?? ""
        lastSwapDay = d.string(forKey: "lastSwapDay") ?? ""
        launchAtLogin = SMAppService.mainApp.status == .enabled
        rolloverIfNeeded()
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.rolloverIfNeeded()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: Derived
    var effectiveGoal: Int { goalML + (runDay ? 500 : 0) }
    var progress: Double { effectiveGoal > 0 ? min(Double(totalML) / Double(effectiveGoal), 1) : 0 }
    var lastLogged: Date? { log.last }

    static func key(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    static var yesterdayKey: String {
        key(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
    }

    // MARK: Actions
    func addGlass() {
        rolloverIfNeeded()
        totalML += glassML
        log.append(Date())
        glassEvent += 1
        checkGoal()
        NotificationManager.shared.resetSchedule()
    }

    func undo() {
        rolloverIfNeeded()
        guard totalML > 0 else { return }
        totalML = max(0, totalML - glassML)
        if !log.isEmpty { log.removeLast() }
        if progress < 1 { celebrate = false }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Rayna: launch at login failed: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func checkGoal() {
        guard progress >= 1 else { return }
        let today = AppState.key(for: Date())
        if lastGoalDay != today {
            streak = (lastGoalDay == AppState.yesterdayKey) ? streak + 1 : 1
            lastGoalDay = today
            celebrate = true
        }
    }

    func rolloverIfNeeded() {
        let today = AppState.key(for: Date())
        if dayKey != today {
            dayKey = today
            totalML = 0
            log = []
            runDay = false
            celebrate = false
        }
        if lastGoalDay != today && lastGoalDay != AppState.yesterdayKey && streak != 0 {
            streak = 0
        }
    }

    // MARK: Quiet hours
    func isQuiet(at date: Date = Date()) -> Bool {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if quietStartMin == quietEndMin { return false }
        if quietStartMin < quietEndMin { return m >= quietStartMin && m < quietEndMin }
        return m >= quietStartMin || m < quietEndMin
    }

    // MARK: Quips (from prototype)
    static let quips: [(Double, String)] = [
        (0, "Morning! I'm a bit… flat. Splash me? 🫠"),
        (0.15, "Ooh, a ripple. Keep it flowing!"),
        (0.35, "Gliding nicely. Your calves send regards. 🦵"),
        (0.55, "Over halfway! Stingrays are happy, and so am I. 😄"),
        (0.75, "Nearly there — tide's coming in! 🌊"),
        (0.9, "One more glass and I do a backflip…"),
        (1, "GOAL! Backflip deployed. You're race-ready! 🎉")
    ]
    var quip: String { AppState.quips.last(where: { progress >= $0.0 })?.1 ?? AppState.quips[0].1 }

    static let reminders = [
        "Sip o'clock! Half-marathon legs run on water, not wishes. 💧",
        "Psst. Your stingray is drying out. One glass?",
        "Hydration check! 250 ml and I'll stop flapping. 🌊"
    ]
    static let swapText = "Fancy swapping the next pint for a pint of water? Tomorrow-you says cheers. 🍺➡️💧"
}
