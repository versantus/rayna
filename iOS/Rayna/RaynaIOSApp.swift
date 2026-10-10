import SwiftUI
import UserNotifications
import WidgetKit
import RaynaCore

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        RaynaFrames.preloadForLaunch(progress: RaynaStore.shared.progress)
        DispatchQueue.global(qos: .utility).async { ReminderScheduler.registerCategories() }
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /// Notification actions are handled in the background (no app launch to foreground).
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        switch response.actionIdentifier {
        case ReminderScheduler.drankAction:
            RaynaStore.shared.addGlass()
            WidgetCenter.shared.reloadAllTimelines()
            DispatchQueue.main.async { AppModel.shared.refresh(wiggle: true) }
            ReminderScheduler.reschedule { completionHandler() }
            return
        case ReminderScheduler.laterAction:
            ReminderScheduler.snooze()
        default:
            break
        }
        completionHandler()
    }
}

@main
struct RaynaIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refresh() }
                }
        }
    }
}
