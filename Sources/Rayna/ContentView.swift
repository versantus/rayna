import RaynaCore
import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var confettiID = 0
    @State private var showConfetti = false
    @State private var wiggleAt: Date? = nil
    @State private var flipAt: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        ProgressRing(progress: state.progress).frame(width: 110, height: 110)
                        RaynaView(progress: state.progress, wiggleAt: wiggleAt, flipAt: flipAt, accessories: state.accessories)
                            .scaleEffect(0.95)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.2f", Double(state.totalML) / 1000))
                                .font(.system(size: 22, weight: .bold))
                            Text(String(format: "/ %.1f L", Double(state.effectiveGoal) / 1000))
                                .font(.system(size: 13)).foregroundColor(.secondary)
                        }
                        Text(state.quip)
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.1)))
                    }
                }

                HStack(spacing: 8) {
                    Button { state.addGlass() } label: {
                        Text("+1 glass (\(state.glassML) ml)").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Button("Undo") { state.undo() }
                        .controlSize(.large)
                    if state.progress >= 1 {
                        Button { MacShare.share(state.shareInfo(.goal)) } label: { Image(systemName: "square.and.arrow.up") }
                            .controlSize(.large)
                            .help("Share a Rayna goal card")
                    }
                }

                if state.showSwap {
                    Button { state.logSwap() } label: {
                        HStack(spacing: 6) {
                            Text("🥤➡️💧")
                            VStack(alignment: .leading, spacing: 0) {
                                Text(state.swapThanks ?? "I swapped a fizzy drink for water").font(.system(size: 12, weight: .semibold))
                                let st = state.extras.swapStreak()
                                Text(st > 0 ? "Swap streak \(st) · \(state.extras.swapsTotal) total" : "Optional fizzy-drink challenge · logs a glass")
                                    .font(.system(size: 10)).foregroundColor(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    Text("Streak").font(.system(size: 12))
                    HStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { i in
                            Circle()
                                .fill(i < state.streak ? Color.accentColor : Color.secondary.opacity(0.25))
                                .frame(width: 8, height: 8)
                        }
                    }
                    Text("\(state.streak) day\(state.streak == 1 ? "" : "s")").font(.system(size: 12))
                    Spacer()
                    Toggle(isOn: $state.runDay) { Text("🏃 Run day +500 ml").font(.system(size: 12)) }
                        .toggleStyle(.switch).controlSize(.mini)
                }

                Divider()
                HStack {
                    Button {
                        SettingsWindowController.shared.show(state: state)
                    } label: {
                        Label("Settings…", systemImage: "gearshape")
                    }
                    .keyboardShortcut(",")
                    Button {
                        JourneyWindowController.shared.show(state: state)
                    } label: {
                        Label("Journey…", systemImage: "trophy")
                    }
                    Spacer()
                    Button("Quit Rayna") { NSApp.terminate(nil) }
                        .keyboardShortcut("q")
                }
            }
            .padding(14)
            .background(WaterBackground(progress: state.progress))

            if showConfetti {
                ConfettiView().id(confettiID)
            }
            if let u = state.unlockBanner {
                RaynaUnlockBanner(unlock: u, onShare: { state.unlockBanner = nil; MacShare.share(state.shareInfo(.unlock(u))) }) { state.unlockBanner = nil }
                    .scaleEffect(0.9)
            }
        }
        .frame(width: 340)
        .onChange(of: state.celebrate) { newValue in
            if newValue { party() }
        }
        .onChange(of: state.glassEvent) { _ in wiggleAt = Date() }
        .onAppear { if state.celebrate && state.progress >= 1 { party() } }
    }

    private func party() {
        confettiID += 1
        showConfetti = true
        flipAt = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            showConfetti = false
            state.celebrate = false
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    private func timeBinding(_ kp: ReferenceWritableKeyPath<AppState, Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                let m = state[keyPath: kp]
                return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
            },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                state[keyPath: kp] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper("Goal: \(state.goalML) ml", value: $state.goalML, in: 1000...5000, step: 250)
            Stepper("Glass: \(state.glassML) ml", value: $state.glassML, in: 100...750, step: 50)
            Stepper("Remind every \(state.intervalMin) min", value: $state.intervalMin, in: 45...60, step: 5)
            DatePicker("Quiet from", selection: timeBinding(\.quietStartMin), displayedComponents: .hourAndMinute)
            DatePicker("Quiet until", selection: timeBinding(\.quietEndMin), displayedComponents: .hourAndMinute)
            Toggle("Fizzy-drink swap nudge (after 18:00)", isOn: $state.eveningSwap)
            Toggle("Swap-a-fizzy-drink challenge button (after 18:00)", isOn: Binding(
                get: { state.extras.swapChallenge },
                set: { state.objectWillChange.send(); state.extras.swapChallenge = $0 }))
            Toggle("System notifications too", isOn: $state.systemNotifications)
            Button("Preview nudge") { NudgeController.shared.show(text: AppState.reminders.randomElement() ?? "Sip o'clock!", isSwap: false) }
            Toggle("Launch at login", isOn: Binding(
                get: { state.launchAtLogin },
                set: { state.setLaunchAtLogin($0) }))
        }
        .font(.system(size: 12))
    }
}

/// Settings live in a real window: a DisclosureGroup inside a MenuBarExtra(.window)
/// panel doesn't reliably expand/resize, so the Settings click appeared to do nothing.
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(state: AppState) {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView().padding(20).frame(width: 340).environmentObject(state))
            let w = NSWindow(contentViewController: host)
            w.title = "Rayna Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        // Close the menu-bar panel, then bring the (accessory) app forward.
        NSApp.keyWindow?.orderOut(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}

/// Collection + weekly recap window.
final class JourneyWindowController {
    static let shared = JourneyWindowController()
    private var window: NSWindow?

    func show(state: AppState) {
        let view = ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RaynaJourneyView(extras: state.extras, recap: state.recap, streak: state.streak) {
                    MacShare.share(state.shareInfo(state.streak >= 3 ? .streak(state.streak) : .recap))
                }
                Divider()
                Text("Pod").font(.system(.title3, design: .rounded, weight: .bold))
                PodView(onInvite: { url in MacShare.shareURL(url) })
                    .task { await PodService.shared.refreshStatus() }
            }.padding(20)
        }
        .frame(width: 460, height: 700)
        if let w = window {
            w.contentViewController = NSHostingController(rootView: view)
        } else {
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.title = "Rayna's journey"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.keyWindow?.orderOut(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}

extension MacShare {
    @MainActor
    static func shareURL(_ url: URL) {
        let picker = NSSharingServicePicker(items: [url])
        let win = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible })
        guard let view = win?.contentView else { return }
        let p = view.convert(win!.mouseLocationOutsideOfEventStream, from: nil)
        picker.show(relativeTo: NSRect(x: p.x, y: p.y, width: 1, height: 1), of: view, preferredEdge: .minY)
    }
}

/// Renders the share cards to PNGs and shows the system share picker (AirDrop, Messages, Mail, Photos…).
enum MacShare {
    @MainActor
    static func share(_ info: RaynaShareInfo) {
        let urls = RaynaShareRenderer.pngFiles(info)
        guard !urls.isEmpty else { return }
        let picker = NSSharingServicePicker(items: urls)
        // Anchor at the mouse in whichever window is frontmost (menu-bar panel or Journey window).
        let win = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible })
        guard let view = win?.contentView else {
            NSWorkspace.shared.activateFileViewerSelecting(urls); return
        }
        let p = view.convert(win!.mouseLocationOutsideOfEventStream, from: nil)
        picker.show(relativeTo: NSRect(x: p.x, y: p.y, width: 1, height: 1), of: view, preferredEdge: .minY)
    }
}
