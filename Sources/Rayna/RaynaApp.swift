import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotificationManager.shared.setUp()
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
                Image(systemName: state.progress >= 1 ? "drop.fill" : "drop")
                Text("\(Int((state.progress * 100).rounded()))%")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
