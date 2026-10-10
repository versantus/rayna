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

    private init() {
        // Screenshot/demo mode: launch arg `-RaynaDemo <glasses>` or env RAYNA_DEMO=<glasses>
        // (simctl: SIMCTL_CHILD_RAYNA_DEMO=6 xcrun simctl launch ...). Optional RAYNA_SETTINGS=1 opens Settings.
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        var demo: Int? = env["RAYNA_DEMO"].flatMap(Int.init)
        if let i = args.firstIndex(of: "-RaynaDemo"), i + 1 < args.count { demo = Int(args[i + 1]) ?? demo }
        if let g = demo {
            demoMode = true
            store.seedDemo(glasses: g, streak: 5)
            if g * store.glassML >= store.effectiveGoal { celebrate = true; flipAt = Date().addingTimeInterval(0.4) }
        } else {
            demoMode = false
        }
        showSettings = args.contains("-RaynaShowSettings") || env["RAYNA_SETTINGS"] == "1"
        store.rolloverIfNeeded()
    }

    func refresh(wiggle: Bool = false) {
        store.rolloverIfNeeded()
        if wiggle { wiggleAt = Date() }
        objectWillChange.send()
    }

    // MARK: Reads
    var progress: Double { store.progress }
    var totalML: Int { store.totalML }
    var goal: Int { store.effectiveGoal }
    var quip: String { store.quip }
    var streak: Int { store.streak }

    // MARK: Actions
    func addGlass() {
        objectWillChange.send()
        let hit = store.addGlass()
        glassEvent += 1
        wiggleAt = Date()
        if hit {
            celebrate = true
            flipAt = Date().addingTimeInterval(0.3)
        }
        afterChange()
        if !demoMode { requestNotificationsIfNeeded() }
    }

    func undo() {
        objectWillChange.send()
        store.undo()
        if store.progress < 1 { celebrate = false }
        afterChange()
    }

    func binding<T>(_ kp: ReferenceWritableKeyPath<RaynaStore, T>) -> Binding<T> {
        Binding(get: { self.store[keyPath: kp] },
                set: { self.objectWillChange.send(); self.store[keyPath: kp] = $0; self.afterChange() })
    }

    func afterChange() {
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
