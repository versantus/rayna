import RaynaCore
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
    /// Unlock currently being celebrated in the dropdown.
    @Published var unlockBanner: RaynaUnlock?
    @Published var swapThanks: String?
    /// History, unlocks and swap-a-pint stats (shared logic with iOS).
    let extras = RaynaExtras(defaults: .standard)
    var goalDays: [String] { get { d.stringArray(forKey: "goalDays") ?? [] } set { d.set(Array(newValue.suffix(30)), forKey: "goalDays") } }
    var accessories: Set<RaynaUnlock> { Set(extras.unlocked) }
    var recap: RaynaRecap { extras.recap(goalDays: goalDays, streak: streak) }
    func shareInfo(_ kind: RaynaShareKind) -> RaynaShareInfo {
        RaynaShareInfo(kind: kind, litres: Double(totalML) / 1000, goalL: Double(effectiveGoal) / 1000,
                       streak: streak, weekL: recap.litres, unlocks: accessories)
    }
    var showSwap: Bool { extras.swapChallenge && RaynaExtras.isSwapTime() }

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

    static func key(for date: Date) -> String { RaynaCopy.dayKey(for: date) }
    static var yesterdayKey: String { RaynaCopy.yesterdayKey() }

    // MARK: Actions
    func addGlass() {
        rolloverIfNeeded()
        totalML += glassML
        log.append(Date())
        extras.recordDay(totalML)
        glassEvent += 1
        checkGoal()
        NotificationManager.shared.resetSchedule()
    }

    func undo() {
        rolloverIfNeeded()
        guard totalML > 0 else { return }
        totalML = max(0, totalML - glassML)
        if !log.isEmpty { log.removeLast() }
        extras.recordDay(totalML)
        if progress < 1 { celebrate = false }
    }

    /// "I swapped a drink for water": a swap + a glass.
    func logSwap() {
        extras.logSwap()
        objectWillChange.send()
        addGlass()
        swapThanks = RaynaCopy.swapThanks.randomElement()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.swapThanks = nil }
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
            goalDays = goalDays + [today]
            celebrate = true
            if let u = extras.noteStreak(streak).last {
                extras.pendingUnlocks = []
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.unlockBanner = u }
            }
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
        RaynaCopy.isQuiet(date, start: quietStartMin, end: quietEndMin)
    }

    // MARK: Quips (shared with iOS via RaynaCore)
    static let quips = RaynaCopy.quips
    var quip: String { RaynaCopy.quip(for: progress) }
    static let reminders = RaynaCopy.reminders
    static let swapText = RaynaCopy.swapText
}
