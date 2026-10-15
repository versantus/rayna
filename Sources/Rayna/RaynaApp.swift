import RaynaCore
import SwiftUI
import AppKit
import CloudKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        Task { @MainActor in
            await PodService.shared.accept(metadata)
            AppState.shared.publishToPod()
        }
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        Task { @MainActor in
            await PodService.shared.handlePush()
            await RaynaCloudSync.shared?.handlePush()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        RaynaCloudSync.configure(defaults: .standard) { AppState.shared.reloadFromDefaults() }
        NSApp.registerForRemoteNotifications()
        RaynaCloudSync.shared.syncNow()
        // Fallback when a push is missed (e.g. after sleep): sync every 5 minutes.
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in Task { @MainActor in RaynaCloudSync.shared?.syncNow() } }
        RaynaFrames.preloadForLaunch(progress: AppState.shared.progress)
        DispatchQueue.main.async { NotificationManager.shared.setUp() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { WelcomeWindowController.shared.showIfFirstLaunch(state: AppState.shared) }
        // Dev/marketing: `Rayna --export-share-cards <dir>` writes sample story + square PNGs and quits.
        if let i = CommandLine.arguments.firstIndex(of: "--export-share-cards"), i + 1 < CommandLine.arguments.count {
            let dir = URL(fileURLWithPath: CommandLine.arguments[i + 1])
            let info = RaynaShareInfo(kind: .goal, litres: 2.5, goalL: 2.5, streak: 14, weekL: 17.5, unlocks: [.bubbles, .headband, .medal])
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
