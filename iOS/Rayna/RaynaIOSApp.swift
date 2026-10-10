import SwiftUI
import UserNotifications
import WidgetKit
import RaynaCore
import CloudKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        RaynaFrames.preloadForLaunch(progress: RaynaStore.shared.progress)
        DispatchQueue.global(qos: .utility).async { ReminderScheduler.registerCategories() }
        application.registerForRemoteNotifications()
        WatchSync.shared.start()   // silent CloudKit pushes for pods
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        c.delegateClass = SceneDelegate.self
        return c
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task { @MainActor in
            await PodService.shared.handlePush()
            completionHandler(.newData)
        }
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

/// Receives accepted pod invites (CloudKit share links).
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        Task { @MainActor in
            await PodService.shared.accept(metadata)
            AppModel.shared.showPod = true
            AppModel.shared.publishToPod()
        }
    }
}
