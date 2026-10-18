import RaynaCore
import SwiftUI
import AppKit
import CloudKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        Task { @MainActor in
            await PodService.shared.accept(metadata)
            PodWindowController.shared.show()
            AppState.shared.publishToPod()
        }
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        Task { @MainActor in
            await PodService.shared.handlePush()
            await RaynaCloudSync.shared?.handlePush()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in await RaynaCloudSync.shared?.catchUp() }
        AppState.shared.publishToPod()
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in RaynaCloudSync.shared?.noteRemoteNotifications(available: true) }
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in RaynaCloudSync.shared?.noteRemoteNotifications(available: false) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MacPodInvite.install()
        #if DEBUG
        MainActor.assumeIsolated { PodService.shared.debugTools = true }
        #endif
        Task { @MainActor in
            let tester = await PodService.isTestFlight()
            PodService.shared.testerTools = tester
            RaynaFeatures.labsAllowed = tester      // App Store installs never see Labs, even if left on
        }
        NSApp.setActivationPolicy(.accessory)
        RaynaCloudSync.configure(defaults: .standard) { AppState.shared.reloadFromDefaults() }
        NSApp.registerForRemoteNotifications()
        Task { await RaynaCloudSync.shared?.catchUp() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            AppState.shared.rolloverIfNeeded()
            AppState.shared.publishToPod()
            Task { @MainActor in await RaynaCloudSync.shared?.catchUp() }
        }
        RaynaFrames.preloadForLaunch(progress: AppState.shared.progress)
        DispatchQueue.main.async { NotificationManager.shared.setUp() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { WelcomeWindowController.shared.showIfFirstLaunch(state: AppState.shared) }
        // Dev/marketing: `Rayna --export-share-cards <dir>` writes sample story + square PNGs and quits.
        if let i = CommandLine.arguments.firstIndex(of: "--export-share-cards"), i + 1 < CommandLine.arguments.count {
            let dir = URL(fileURLWithPath: CommandLine.arguments[i + 1])
            let info = RaynaShareInfo(kind: .goal, litres: 2.5, goalL: 2.5, streak: 14, weekL: 17.5, unlocks: [.headband])
            for u in RaynaShareRenderer.pngFiles(info) {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(u.lastPathComponent))
                try? FileManager.default.copyItem(at: u, to: dir.appendingPathComponent(u.lastPathComponent))
            }
            exit(0)
        }
        // Dev/screenshots: `Rayna --show-window settings|journey|welcome`.
        if let i = CommandLine.arguments.firstIndex(of: "--show-window"), i + 1 < CommandLine.arguments.count {
            let which = CommandLine.arguments[i + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                switch which {
                case "settings": SettingsWindowController.shared.show(state: AppState.shared)
                case "journey": JourneyWindowController.shared.show(state: AppState.shared)
                default: WelcomeWindowController.shared.show(state: AppState.shared)
                }
            }
        }
        if CommandLine.arguments.contains("--preview-nudge") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NudgeController.shared.show(text: AppState.reminders[0], isSwap: false)
            }
        }
    }
}

@main
struct RaynaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(state)
        } label: {
            HStack(spacing: 3) {
                if let glyph = MenuGlyph.image {
                    Image(nsImage: glyph)
                } else {
                    Image(systemName: state.progress >= 1 ? "drop.fill" : "drop")
                }
                Text("\(Int((state.progress * 100).rounded()))%")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Rayna's silhouette as a template image (MenuGlyph.png / @2x in Contents/Resources).
enum MenuGlyph {
    static let image: NSImage? = {
        guard let img = NSImage(named: "MenuGlyph") else { return nil }
        img.isTemplate = true
        img.size = NSSize(width: 18, height: 18)
        return img
    }()
}

/// Re-presents the pod CKShare. Falls back to the link picker when cloud sharing can't run (for example an ad-hoc build).
enum MacPodInvite {
    @MainActor
    static func install() {
        let pod = PodService.shared
        pod.presentShare = { @MainActor share in present(share) }
        pod.supplyLocal = { @MainActor in
            let s = AppState.shared
            return PodLive(glasses: s.glasses, ml: s.totalML, goal: s.effectiveGoal, streak: s.streak, isKid: s.extras.kidMode,
                           appearance: PodAppearance(skin: s.skin, worn: s.extras.wornBadges))
        }
        pod.onRoster = { @MainActor members in
            let state = AppState.shared
            let fresh = state.extras.notePodOverAchieved(PodAchievement.everyoneBeatGoal(members))
            guard state.unlockBanner == nil, let u = fresh.last else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { state.unlockBanner = u }
        }
    }

    @MainActor
    static func present(_ share: CKShare) {
        if let service = NSSharingService(named: .cloudSharing), service.canPerform(withItems: [share]) {
            service.delegate = MacPodShareDelegate.shared
            MacPodShareDelegate.shared.hold(service)
            service.perform(withItems: [share])
        } else if let url = share.url {
            MacShare.shareURL(url)
        }
    }
}

final class MacPodShareDelegate: NSObject, NSSharingServiceDelegate {
    static let shared = MacPodShareDelegate()
    private var service: NSSharingService?
    func hold(_ service: NSSharingService) { self.service = service }
    func sharingService(_ sharingService: NSSharingService, didShare items: [Any]) {
        service = nil
        Task { @MainActor in await PodService.shared.fetch() }
    }
    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        service = nil
        Task { @MainActor in PodService.shared.presentCloudError(error) }
    }
}
