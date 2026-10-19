import RaynaCore
import Foundation
import SwiftUI
import ServiceManagement

final class AppState: ObservableObject {
    static let shared = AppState()
    private let d = UserDefaults.standard

    @Published var totalML: Int { didSet { d.set(totalML, forKey: "totalML"); localChanged() } }
    @Published var log: [Date] { didSet { d.set(log, forKey: "log") } }
    @Published var runDay: Bool { didSet { d.set(runDay, forKey: "runDay"); localChanged(); checkGoal() } }
    @Published var goalML: Int { didSet { d.set(goalML, forKey: "goalML"); localChanged(); checkGoal() } }
    @Published var glassML: Int {
        didSet {
            let clean = GlassSize.sanitize(glassML)
            if clean != glassML { glassML = clean; return }
            d.set(clean, forKey: "glassML"); localChanged()
        }
    }
    @Published var intervalMin: Int { didSet { d.set(intervalMin, forKey: "intervalMin"); NotificationManager.shared.resetSchedule() } }
    @Published var remindersOn: Bool { didSet { d.set(remindersOn, forKey: "remindersOn"); NotificationManager.shared.resetSchedule() } }
    @Published var quietStartMin: Int { didSet { d.set(quietStartMin, forKey: "quietStartMin"); localChanged() } }
    @Published var quietEndMin: Int { didSet { d.set(quietEndMin, forKey: "quietEndMin"); localChanged() } }
    @Published var eveningSwap: Bool { didSet { d.set(eveningSwap, forKey: "eveningSwap"); localChanged() } }
    @Published var exerciseExtraOn: Bool { didSet { d.set(exerciseExtraOn, forKey: "exerciseExtraOn"); localChanged(); checkGoal() } }
    @Published var runBonusML: Int { didSet { d.set(runBonusML, forKey: "runBonusML"); localChanged(); checkGoal() } }
    @Published var streak: Int { didSet { d.set(streak, forKey: "streak") } }
    @Published var systemNotifications: Bool { didSet { d.set(systemNotifications, forKey: "systemNotifications"); if systemNotifications { NotificationManager.shared.requestAuth() } } }
    @Published var glassEvent = 0
    @Published var celebrate = false
    @Published var launchAtLogin: Bool = false
    /// Unlock currently being celebrated in the dropdown.
    @Published var unlockBanner: RaynaUnlock?
    @Published var swapThanks: String?
    @Published var bubbleFact: RayFact?
    @Published var factPage: RayFact?
    /// History, unlocks and swap-a-fizzy-drink stats (shared logic with iOS).
    let extras = RaynaExtras(defaults: .standard)
    var goalDays: [String] { get { d.stringArray(forKey: "goalDays") ?? [] } set { d.set(Array(newValue.suffix(30)), forKey: "goalDays") } }
    /// The badges on the live ray and the share card. At most one in each slot.
    var accessories: Set<RaynaUnlock> { extras.wornBadges }
    var recap: RaynaRecap { extras.recap(goalDays: goalDays, streak: streak) }
    /// Rayna's colour (`raynaSkin`, synced with the iPhone). Classic until colours are released.
    var skin: RaynaSkin {
        get {
            let s = d.string(forKey: RaynaSkin.storageKey).flatMap(RaynaSkin.init(rawValue:)) ?? .classic
            return RaynaFeatures.rayColours && s.isAvailable ? s : .classic
        }
        set { d.set(newValue.rawValue, forKey: RaynaSkin.storageKey); RaynaFrames.skin = newValue; objectWillChange.send(); localChanged(); publishToPod() }
    }
    func publishToPod() {
        guard PodService.isEntitled else { return }
        let g = glasses, ml = totalML, goal = effectiveGoal, st = streak, kid = extras.kidMode
        Task { @MainActor in
            await PodService.shared.publish(glasses: g, ml: ml, goal: goal, streak: st, isKid: kid,
                                             appearance: PodAppearance(skin: skin, worn: extras.wornBadges))
        }
    }

    func shareInfo(_ kind: RaynaShareKind) -> RaynaShareInfo {
        RaynaShareInfo(kind: kind, litres: Double(totalML) / 1000, goalL: Double(effectiveGoal) / 1000,
                       streak: streak, weekL: recap.litres, unlocks: accessories)
    }
    var showSwap: Bool { extras.swapChallenge && (RaynaExtras.isSwapTime() || ProcessInfo.processInfo.environment["RAYNA_SWAP"] == "1") }

    private var dayKey: String { didSet { d.set(dayKey, forKey: "dayKey") } }
    private var lastGoalDay: String { didSet { d.set(lastGoalDay, forKey: "lastGoalDay") } }
    var lastSwapDay: String { didSet { d.set(lastSwapDay, forKey: "lastSwapDay") } }

    private var timer: Timer?

    private init() {
        d.register(defaults: [
            "goalML": 2500, "glassML": 250, "intervalMin": 60, "remindersOn": true,
            "quietStartMin": 22 * 60, "quietEndMin": 7 * 60 + 30,
            "eveningSwap": true
        ])
        totalML = d.integer(forKey: "totalML")
        log = (d.array(forKey: "log") as? [Date]) ?? []
        runDay = d.bool(forKey: "runDay")
        goalML = d.integer(forKey: "goalML")
        let rawGlass = d.integer(forKey: "glassML")
        let cleanGlass = GlassSize.sanitize(rawGlass)
        if cleanGlass != rawGlass { d.set(cleanGlass, forKey: "glassML") }
        glassML = cleanGlass
        let storedInterval = d.integer(forKey: "intervalMin")
        intervalMin = storedInterval > 0 ? storedInterval : 60
        if d.object(forKey: "remindersOn") == nil { d.set(true, forKey: "remindersOn") }
        remindersOn = d.bool(forKey: "remindersOn")
        quietStartMin = d.integer(forKey: "quietStartMin")
        quietEndMin = d.integer(forKey: "quietEndMin")
        eveningSwap = d.bool(forKey: "eveningSwap")
        exerciseExtraOn = d.object(forKey: "exerciseExtraOn") == nil ? true : d.bool(forKey: "exerciseExtraOn")
        let storedBonus = d.integer(forKey: "runBonusML")
        runBonusML = storedBonus > 0 ? storedBonus : 500
        streak = d.integer(forKey: "streak")
        systemNotifications = d.bool(forKey: "systemNotifications")
        dayKey = d.string(forKey: "dayKey") ?? AppState.key(for: Date())
        lastGoalDay = d.string(forKey: "lastGoalDay") ?? ""
        lastSwapDay = d.string(forKey: "lastSwapDay") ?? ""
        launchAtLogin = SMAppService.mainApp.status == .enabled
        #if DEBUG
        if let spec = ProcessInfo.processInfo.environment["RAYNA_BADGES"], !spec.isEmpty {
            let fresh = extras.unlockForTesting(RaynaExtras.badges(from: spec))
            extras.pendingUnlocks = []
            unlockBanner = fresh.last
        }
        #endif
        if rolloverIfNeeded() { publishToPod() }
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            guard let self, self.rolloverIfNeeded() else { return }
            self.publishToPod()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        RaynaFrames.skin = skin
    }

    /// Re-read synced keys after iCloud sync wrote another device's changes into the defaults.
    func reloadFromDefaults() {
        reloading = true; defer { reloading = false }
        if d.string(forKey: "dayKey") != dayKey, let k = d.string(forKey: "dayKey") { dayKey = k }
        let pairs: [(ReferenceWritableKeyPath<AppState, Int>, String)] = [(\.totalML, "totalML"), (\.goalML, "goalML"), (\.glassML, "glassML"),
            (\.quietStartMin, "quietStartMin"), (\.quietEndMin, "quietEndMin"), (\.streak, "streak")]
        for (kp, k) in pairs where self[keyPath: kp] != d.integer(forKey: k) { self[keyPath: kp] = d.integer(forKey: k) }
        let newLog = (d.array(forKey: "log") as? [Date]) ?? []
        if newLog != log { log = newLog }
        if runDay != d.bool(forKey: "runDay") { runDay = d.bool(forKey: "runDay") }
        if eveningSwap != d.bool(forKey: "eveningSwap") { eveningSwap = d.bool(forKey: "eveningSwap") }
        let extra = d.object(forKey: "exerciseExtraOn") == nil ? true : d.bool(forKey: "exerciseExtraOn")
        if exerciseExtraOn != extra { exerciseExtraOn = extra }
        let bonus = d.integer(forKey: "runBonusML")
        let cleanBonus = bonus > 0 ? bonus : 500
        if runBonusML != cleanBonus { runBonusML = cleanBonus }
        lastGoalDay = d.string(forKey: "lastGoalDay") ?? lastGoalDay
        // Synced glasses can complete the goal without a local +1, so record the goal day/streak here too
        // (otherwise the streak could read 0 days on a device that never saw its own glass hit the goal).
        checkGoal()
        RaynaFrames.skin = skin
        objectWillChange.send()
        publishToPod()
    }
    /// True while applying synced values (so it doesn't count as a local edit).
    private var reloading = false
    /// Local edits: let iCloud sync pick them up (debounced).
    func localChanged() { if !reloading { MainActor.assumeIsolated { RaynaCloudSync.shared?.syncSoon() } } }

    // MARK: Derived
    /// Kid mode has no exercise-day bonus, matching the iPhone. The flag stays `runDay`.
    var effectiveGoal: Int {
        ExerciseDay.goal(base: goalML, extraOn: exerciseExtraOn, exerciseDay: runDay, bonus: runBonusML, kidMode: extras.kidMode)
    }
    var kidMode: Bool { extras.kidMode }
    var glasses: Int { glassML > 0 ? totalML / glassML : 0 }
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
        let wasHit = progress >= 1 && lastGoalDay == AppState.key(for: Date())
        checkGoal()
        RaynaSounds.shared.play(.splash)
        let hitNow = !wasHit && progress >= 1
        RaynaSounds.shared.play(hitNow ? .chime : .bubbles, after: hitNow ? 0.3 : 0.25)
        publishToPod()
        NotificationManager.shared.resetSchedule()
        bubbleFact = extras.factForMilestone(progress: progress)   // milestones only
    }

    func undo() {
        let rolled = rolloverIfNeeded()
        guard totalML > 0 else {
            if rolled { publishToPod() }
            return
        }
        totalML = max(0, totalML - glassML)
        if !log.isEmpty { log.removeLast() }
        extras.recordDay(totalML)
        if progress < 1 { celebrate = false }
        publishToPod()
    }

    /// Kid mode: cups, a 1.5 L goal and simpler words. The feature flag gates it on both platforms.
    func setKidMode(_ on: Bool) {
        guard let next = extras.applyKidMode(on, goalML: goalML, glassML: glassML) else { return }
        goalML = next.goalML
        glassML = next.glassML
        objectWillChange.send()
        localChanged()
    }

    /// "I swapped a fizzy drink for water": a swap + a glass.
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

    #if DEBUG
    /// Inserts badges into the collection. `spec` is `all` or comma-separated ids such as `surge,podWave`.
    func unlockBadgesForTesting(_ spec: String = "all") {
        let fresh = extras.unlockForTesting(RaynaExtras.badges(from: spec))
        extras.pendingUnlocks = []
        objectWillChange.send()
        if unlockBanner == nil { unlockBanner = fresh.last }
    }
    #endif

    private func checkGoal() {
        if progress >= 1 {
            let today = AppState.key(for: Date())
            if lastGoalDay != today {
                streak = (lastGoalDay == AppState.yesterdayKey) ? streak + 1 : 1
                lastGoalDay = today
                goalDays = goalDays + [today]
                celebrate = true
                extras.noteStreak(streak)
            }
        }
        celebrateNewUnlocks()
    }

    /// Shows one new badge. Streak badges win over an over-achiever badge earned on the same glass.
    private func celebrateNewUnlocks() {
        let streakPending = extras.pendingUnlocks
        let intake = extras.noteIntake(ml: totalML, goal: effectiveGoal)
        guard unlockBanner == nil else { extras.pendingUnlocks = []; return }
        let streak = streakPending.last { if case .streakDays = $0.rule { return true }; return false }
        guard let u = streak ?? intake.last ?? extras.pendingUnlocks.last else { return }
        extras.pendingUnlocks = []
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.unlockBanner = u }
    }

    @discardableResult
    func rolloverIfNeeded() -> Bool {
        let today = AppState.key(for: Date())
        var rolled = false
        if dayKey != today {
            dayKey = today
            totalML = 0
            log = []
            runDay = false
            celebrate = false
            rolled = true
        }
        if lastGoalDay != today && lastGoalDay != AppState.yesterdayKey && streak != 0 {
            streak = 0
            rolled = true
        }
        return rolled
    }

    // MARK: Quiet hours
    func isQuiet(at date: Date = Date()) -> Bool {
        RaynaCopy.isQuiet(date, start: quietStartMin, end: quietEndMin)
    }

    // MARK: Quips (shared with iOS via RaynaCore)
    var quip: String {
        RaynaCopy.quip(for: progress, exerciseDay: runDay && !kidMode, salt: totalML, kidMode: kidMode)
    }
    static var reminders: [String] { RaynaCopy.reminders }
    static let swapText = RaynaCopy.swapText
}
