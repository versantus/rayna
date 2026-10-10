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
        showJourney = env["RAYNA_JOURNEY"] == "1"
        if let u = env["RAYNA_UNLOCK"].flatMap(RaynaUnlock.init(rawValue:)) { unlockBanner = u }
        if env["RAYNA_POD"] == "1" { DispatchQueue.main.async { PodService.shared.loadDemo(); self.showPod = true } }
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
        if wiggle { wiggleAt = Date() }
        objectWillChange.send()
    }

    // MARK: Reads
    var progress: Double { store.progress }
    var totalML: Int { store.totalML }
    var goal: Int { store.effectiveGoal }
    var quip: String { store.quip }
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
        if hit { celebrate = true; flipAt = Date().addingTimeInterval(0.3) }
        swapThanks = RaynaCopy.swapThanks.randomElement()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.swapThanks = nil }
        afterChange()
        checkUnlocks()
    }

    // MARK: Actions
    func addGlass() {
        objectWillChange.send()
        let hit = store.addGlass()
        if !demoMode { HealthManager.shared.logGlass(ml: store.glassML, store: store) }
        glassEvent += 1
        wiggleAt = Date()
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
            await PodService.shared.publish(glasses: s.glasses, ml: s.totalML, goal: s.effectiveGoal, streak: s.streak)
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
