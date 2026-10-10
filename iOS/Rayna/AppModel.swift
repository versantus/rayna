import SwiftUI
import UserNotifications
import WidgetKit
import RaynaCore

/// Observable wrapper around the shared App Group store.
final class AppModel: ObservableObject {
    static let shared = AppModel()
    let store = RaynaStore.shared
    let demoMode: Bool

    @Published var wiggleAt: Date?
    @Published var flipAt: Date?
    @Published var celebrate = false
    @Published var glassEvent = 0
    @Published var showSettings = false
    @Published var showJourney = false
    /// Unlock currently being celebrated.
    @Published var unlockBanner: RaynaUnlock?
    @Published var swapThanks: String?
    /// Share cards currently offered (story + square).
    @Published var share: RaynaShareInfo?
    @Published var showPod = false
    /// Newly unlocked ray fact (shown as a small card for a few seconds).
    /// Fact Rayna is currently saying in her bubble (milestones only); tap opens the fact page.
    @Published var bubbleFact: RayFact?
    @Published var factPage: RayFact?
    var journeyToFacts = false

    private init() {
        // Screenshot/demo mode: launch arg `-RaynaDemo <glasses>` or env RAYNA_DEMO=<glasses>
        // (simctl: SIMCTL_CHILD_RAYNA_DEMO=6 xcrun simctl launch ...). Optional RAYNA_SETTINGS=1 opens Settings.
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        var demo: Int? = env["RAYNA_DEMO"].flatMap(Int.init)
        if let i = args.firstIndex(of: "-RaynaDemo"), i + 1 < args.count { demo = Int(args[i + 1]) ?? demo }
        if let g = demo {
            demoMode = true
            let streak = env["RAYNA_STREAK"].flatMap(Int.init) ?? 5
            store.seedDemo(glasses: g, streak: streak)
            if g * store.glassML >= store.effectiveGoal { celebrate = true; flipAt = Date().addingTimeInterval(0.4) }
        } else {
            demoMode = false
        }
        showSettings = args.contains("-RaynaShowSettings") || env["RAYNA_SETTINGS"] == "1"
        showJourney = env["RAYNA_JOURNEY"] == "1" || env["RAYNA_JOURNEY"] == "facts"
        journeyToFacts = env["RAYNA_JOURNEY"] == "facts"
        if let u = env["RAYNA_UNLOCK"].flatMap(RaynaUnlock.init(rawValue:)) { unlockBanner = u }
        if env["RAYNA_POD"] == "1" { DispatchQueue.main.async { PodService.shared.loadDemo(); self.showPod = true } }
        if env["RAYNA_KID"] == "1" { setKidMode(true); store.seedDemo(glasses: Int(env["RAYNA_DEMO"] ?? "4") ?? 4, streak: Int(env["RAYNA_STREAK"] ?? "8") ?? 8) }
        if env["RAYNA_KID"] == "0" { setKidMode(false); if let g = demo { store.seedDemo(glasses: g, streak: Int(env["RAYNA_STREAK"] ?? "5") ?? 5) } }
        #if DEBUG   // screenshot hooks; never in release builds
        if let n = env["RAYNA_FACTS"].flatMap(Int.init) { store.extras.factsUnlocked = n }
        if let n = env["RAYNA_FACT"].flatMap(Int.init), n < store.extras.factsUnlocked {   // demo only, never locked facts
            bubbleFact = RayFacts.all[n] }
        if let n = env["RAYNA_FACTPAGE"].flatMap(Int.init), n < store.extras.factsUnlocked { factPage = RayFacts.all[n] }
        #endif
        if env["RAYNA_POD"] == "card" { DispatchQueue.main.async { PodService.shared.loadDemo() } }
        if env["RAYNA_SHARE"] == "goal" { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.offerShare(.goal) } }
        store.rolloverIfNeeded()
    }

    func refresh(wiggle: Bool = false) {
        store.rolloverIfNeeded()
        if !demoMode {
            HealthManager.shared.applyRunDay(store: store) { applied in if applied { self.objectWillChange.send(); self.afterChange() } }
        }
        checkUnlocks()
        if wiggle { wiggleAt = Date(); if !demoMode { RaynaSounds.shared.play(.bubbles) } }
        objectWillChange.send()
    }

    // MARK: Reads
    var progress: Double { store.progress }
    var totalML: Int { store.totalML }
    var goal: Int { store.effectiveGoal }
    var quip: String { kidMode ? RaynaCopy.kidQuip(for: progress) : store.quip }
    var kidMode: Bool { store.extras.kidMode }

    /// Kid mode: cups, a smaller goal (1.5 L in 200 ml cups) and simpler words. Restores the grown-up goal when off.
    func setKidMode(_ on: Bool) {
        objectWillChange.send()
        let x = store.extras
        guard RaynaFeatures.kidMode, on != x.kidMode else { return }
        if on {
            x.adultGoalML = store.goalML; x.adultGlassML = store.glassML
            store.glassML = 200; store.goalML = 1500
        } else {
            if x.adultGoalML > 0 { store.goalML = x.adultGoalML }
            if x.adultGlassML > 0 { store.glassML = x.adultGlassML }
        }
        x.kidMode = on
        afterChange()
    }

    /// Milestones only (25/50/75/100 %): Rayna says a fact in her bubble until the next glass.
    private func revealFact() {
        bubbleFact = store.extras.factForMilestone(progress: progress)
    }
    var streak: Int { store.streak }
    var extras: RaynaExtras { store.extras }
    var accessories: Set<RaynaUnlock> { Set(store.extras.unlocked) }
    var showSwap: Bool { store.extras.swapChallenge && (RaynaExtras.isSwapTime() || ProcessInfo.processInfo.environment["RAYNA_SWAP"] == "1") }

    func shareInfo(_ kind: RaynaShareKind) -> RaynaShareInfo {
        RaynaShareInfo(kind: kind, litres: Double(store.totalML) / 1000, goalL: Double(store.effectiveGoal) / 1000,
                       streak: store.streak, weekL: store.recap.litres, unlocks: accessories)
    }
    func offerShare(_ kind: RaynaShareKind) { share = shareInfo(kind) }

    func checkUnlocks() {
        if unlockBanner == nil, let u = store.extras.takePendingUnlocks().last {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.unlockBanner = u }
        }
    }

    /// Evening challenge: "I swapped a fizzy drink for water" = a swap + a glass.
    func logSwap() {
        objectWillChange.send()
        let hit = store.logSwap()
        glassEvent += 1
        wiggleAt = Date()
        playGlassSounds(hit: hit)
        revealFact()
        if hit { celebrate = true; flipAt = Date().addingTimeInterval(0.3) }
        swapThanks = RaynaCopy.swapThanks.randomElement()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.swapThanks = nil }
        afterChange()
        checkUnlocks()
    }

    /// Splash on every glass, bubbles with the wiggle, and a chime + whoosh with the goal spin.
    private func playGlassSounds(hit: Bool) {
        guard !demoMode else { return }
        RaynaSounds.shared.play(.splash)
        RaynaSounds.shared.play(hit ? .chime : .bubbles, after: hit ? 0.3 : 0.25)
    }

    // MARK: Actions
    func addGlass() {
        objectWillChange.send()
        let hit = store.addGlass()
        if !demoMode { HealthManager.shared.logGlass(ml: store.glassML, store: store) }
        glassEvent += 1
        wiggleAt = Date()
        playGlassSounds(hit: hit)
        revealFact()
        if hit {
            celebrate = true
            flipAt = Date().addingTimeInterval(0.3)
        }
        afterChange()
        checkUnlocks()
        if !demoMode { requestNotificationsIfNeeded() }
    }

    func undo() {
        objectWillChange.send()
        store.undo()
        if !demoMode { HealthManager.shared.undoGlass() }
        if store.progress < 1 { celebrate = false }
        afterChange()
    }

    func binding<T>(_ kp: ReferenceWritableKeyPath<RaynaStore, T>) -> Binding<T> {
        Binding(get: { self.store[keyPath: kp] },
                set: { self.objectWillChange.send(); self.store[keyPath: kp] = $0; self.afterChange() })
    }

    func publishToPod() {
        guard !demoMode else { return }
        let s = store
        Task { @MainActor in
            await PodService.shared.publish(glasses: s.glasses, ml: s.totalML, goal: s.effectiveGoal, streak: s.streak, isKid: s.extras.kidMode)
        }
    }

    func afterChange() {
        publishToPod()
        WatchSync.shared.push()
        LiveActivityManager.sync(store: store)
        WidgetCenter.shared.reloadAllTimelines()
        if !demoMode { ReminderScheduler.reschedule() }
    }

    func requestNotificationsIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            guard s.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                ReminderScheduler.reschedule()
            }
        }
    }
}
