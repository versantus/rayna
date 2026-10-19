import RaynaCore
import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private var timer: Timer?
    private var nextReminder = Date().addingTimeInterval(50 * 60)

    static let category = "RAYNA_REMINDER"
    static let drankAction = "DRANK_ONE"
    static let snoozeAction = "SNOOZE_15"

    func setUp() {
        center.delegate = self
        let drank = UNNotificationAction(identifier: Self.drankAction, title: "Drank one 💧", options: [])
        let snooze = UNNotificationAction(identifier: Self.snoozeAction, title: "Later", options: [])
        let cat = UNNotificationCategory(identifier: Self.category, actions: [drank, snooze],
                                         intentIdentifiers: [], options: [])
        center.setNotificationCategories([cat])
        if AppState.shared.systemNotifications { requestAuth() }
        resetSchedule()
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func requestAuth() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { NSLog("Rayna: notification auth error \(error.localizedDescription)") }
            NSLog("Rayna: notifications granted = \(granted)")
        }
    }

    func snooze() { nextReminder = Date().addingTimeInterval(15 * 60) }

    func resetSchedule() {
        let mins = AppState.shared.intervalMin
        nextReminder = Date().addingTimeInterval(TimeInterval(mins * 60))
    }

    private func tick() {
        let s = AppState.shared
        if s.rolloverIfNeeded() { s.publishToPod() }
        guard s.remindersOn else { return }
        let now = Date()

        // Evening swap nudge: once per day after 18:00
        let hour = Calendar.current.component(.hour, from: now)
        let today = AppState.key(for: now)
        if s.eveningSwap, hour >= 18, !s.isQuiet(at: now), s.lastSwapDay != today {
            s.lastSwapDay = today
            post(title: "Rayna 🥤➡️💧", body: AppState.swapText, actions: false)
        }

        guard now >= nextReminder else { return }
        resetSchedule()
        if s.isQuiet(at: now) { return }
        if s.progress >= 1 { return }
        if let last = s.lastLogged, now.timeIntervalSince(last) < 20 * 60 { return }
        post(title: "Rayna 💧", body: RaynaCopy.nextReminder(at: now), actions: true)
    }

    private func post(title: String, body: String, actions: Bool) {
        NudgeController.shared.show(text: body, isSwap: !actions)
        guard AppState.shared.systemNotifications else { return }
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        if actions { c.categoryIdentifier = Self.category }
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil)
        center.add(req) { error in
            if let error { NSLog("Rayna: post failed \(error.localizedDescription)") }
        }
    }

    // Show banners even though we're "active" (menu-bar apps often are)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.actionIdentifier
        DispatchQueue.main.async {
            if id == Self.drankAction {
                AppState.shared.addGlass(presenting: false)
            } else if id == Self.snoozeAction {
                self.nextReminder = Date().addingTimeInterval(15 * 60)
            }
            completionHandler()
        }
    }
}
