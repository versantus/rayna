#if os(iOS)
import Foundation
import UserNotifications

/// Schedules Rayna's reminders ahead of time with UNUserNotificationCenter, so they fire
/// even when the app isn't running. Re-planned whenever a glass is logged or settings change.
public enum ReminderScheduler {
    public static let category = "RAYNA_REMINDER"
    public static let drankAction = "DRANK_ONE"
    public static let laterAction = "LATER_15"
    static let prefix = "rayna."

    public static func registerCategories() {
        let drank = UNNotificationAction(identifier: drankAction, title: "Drank one 💧", options: [])
        let later = UNNotificationAction(identifier: laterAction, title: "Later", options: [])
        let cat = UNNotificationCategory(identifier: category, actions: [drank, later], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }

    /// Plans the next ~2 days of reminders (iOS allows 64 pending; we stay well under).
    public static func reschedule(store: RaynaStore = .shared, now: Date = Date(), completion: (() -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) && !$0.hasPrefix(prefix + "snooze") }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            guard store.remindersOn else { completion?(); return }
            let requests = plan(store: store, now: now)
            let group = DispatchGroup()
            for r in requests { group.enter(); center.add(r) { _ in group.leave() } }
            group.notify(queue: .main) { completion?() }
        }
    }

    public static func plan(store: RaynaStore, now: Date) -> [UNNotificationRequest] {
        let cal = Calendar.current
        let interval = TimeInterval(max(15, store.intervalMin) * 60)
        var out: [UNNotificationRequest] = []
        // First reminder one interval after the last glass (or after now).
        var t = max(now, store.lastLogged ?? now).addingTimeInterval(interval)
        if t < now.addingTimeInterval(60) { t = now.addingTimeInterval(interval) }
        let horizon = now.addingTimeInterval(48 * 3600)
        let todayDone = store.progress >= 1
        var n = 0
        while t < horizon && out.count < 50 {
            let isToday = cal.isDate(t, inSameDayAs: now)
            if store.isQuiet(at: t) || (isToday && todayDone) {
                t = t.addingTimeInterval(15 * 60); continue
            }
            let c = UNMutableNotificationContent()
            c.title = "Rayna 💧"
            c.body = RaynaCopy.nextReminder(at: t)
            c.sound = .default
            c.categoryIdentifier = category
            c.threadIdentifier = "rayna"
            out.append(request("\(prefix)r\(n)", c, at: t))
            n += 1
            t = t.addingTimeInterval(interval)
        }
        // Fizzy-drink swap nudge at 19:00 (today if still ahead, and tomorrow).
        if store.eveningSwap {
            for d in 0...1 {
                guard let day = cal.date(byAdding: .day, value: d, to: now),
                      let at = cal.date(bySettingHour: 19, minute: 0, second: 0, of: day),
                      at > now, !store.isQuiet(at: at) else { continue }
                let c = UNMutableNotificationContent()
                c.title = "Rayna 🥤➡️💧"
                c.body = RaynaCopy.swapText
                c.sound = .default
                c.threadIdentifier = "rayna"
                out.append(request("\(prefix)swap\(d)", c, at: at))
            }
        }
        return out
    }

    /// "Later": one reminder in 15 minutes.
    public static func snooze(minutes: Int = 15) {
        let c = UNMutableNotificationContent()
        c.title = "Rayna 💧"
        c.body = RaynaCopy.nextReminder()
        c.sound = .default
        c.categoryIdentifier = category
        let trig = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "\(prefix)snooze", content: c, trigger: trig))
    }

    private static func request(_ id: String, _ c: UNNotificationContent, at date: Date) -> UNNotificationRequest {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNNotificationRequest(identifier: id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
    }
}
#endif
