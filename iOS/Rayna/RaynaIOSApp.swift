import SwiftUI
import UIKit
import UserNotifications
import WidgetKit
import RaynaCore
import CloudKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        PodInviteController.install()
        UNUserNotificationCenter.current().delegate = self
        RaynaFrames.preloadForLaunch(progress: RaynaStore.shared.progress)
        DispatchQueue.global(qos: .utility).async { ReminderScheduler.registerCategories() }
        application.registerForRemoteNotifications()
        WatchSync.shared.start()
        RaynaCloudSync.configure(defaults: RaynaStore.shared.defaults) {
            // Remote intake/settings landed in the store: refresh UI, widgets, watch (no re-sync loop).
            RaynaStore.shared.reconcileGoal()   // synced glasses may have completed today's goal
            AppModel.shared.refresh()
            AppModel.shared.afterRemoteChange()
        }
        Task { await RaynaCloudSync.shared?.catchUp() }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in RaynaCloudSync.shared?.noteRemoteNotifications(available: true) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in RaynaCloudSync.shared?.noteRemoteNotifications(available: false) }
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
            await RaynaCloudSync.shared.handlePush()
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
                    if phase == .active {
                        model.refresh()
                        Task { await RaynaCloudSync.shared?.catchUp() }
                    }
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

/// Re-presents the existing pod share so a pending invite can be sent again.
enum PodInviteController {
    @MainActor
    static func install() {
        let pod = PodService.shared
        pod.presentShare = { @MainActor share in present(share) }
        pod.onRoster = { @MainActor members in
            let fresh = RaynaStore.shared.extras.notePodOverAchieved(PodAchievement.everyoneBeatGoal(members))
            guard !fresh.isEmpty else { return }
            AppModel.shared.objectWillChange.send()
            AppModel.shared.checkUnlocks()
        }
    }

    @MainActor
    static func present(_ share: CKShare) {
        let vc = UICloudSharingController(share: share, container: CKContainer(identifier: PodService.containerID))
        vc.availablePermissions = [.allowPublic, .allowPrivate, .allowReadWrite]
        vc.delegate = Delegate.shared
        guard let root = keyRoot() else { return }
        var top = root
        while let next = top.presentedViewController { top = next }
        top.present(vc, animated: true)
    }

    @MainActor
    private static func keyRoot() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    }

    final class Delegate: NSObject, UICloudSharingControllerDelegate {
        static let shared = Delegate()
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            Task { @MainActor in PodService.shared.lastError = PodService.friendly(error) }
        }
        func itemTitle(for csc: UICloudSharingController) -> String? { "Join my Rayna pod" }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            Task { @MainActor in await PodService.shared.fetch() }
        }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            Task { @MainActor in await PodService.shared.fetch() }
        }
    }
}
