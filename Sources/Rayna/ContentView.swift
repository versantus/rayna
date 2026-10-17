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
                        if let f = state.bubbleFact {
                            Button { state.factPage = f } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    RayFactTag()
                                    Text(f.text).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                                    Text("Click to read more").font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.75)))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else {
                        Text(state.quip)
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.1)))
                        }
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

                GlassSizeQuickAdd(glassML: $state.glassML)

                if state.showSwap {
                    Button { state.logSwap() } label: {
                        HStack(spacing: 6) {
                            Text("🥤➡️💧")
                            VStack(alignment: .leading, spacing: 0) {
                                Text(state.swapThanks ?? "I swapped a fizzy drink for water").font(.system(size: 12, weight: .semibold))
                                let st = state.extras.swapStreak()
                                Text(st > 0 ? "Swap streak \(st) · \(state.extras.swapsTotal) total" : "Optional fizzy-drink challenge · logs a glass")
                                    .font(.system(size: 11)).foregroundColor(.secondary)
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
                        Image(systemName: "gearshape")
                    }
                    .help("Settings… (⌘,)")
                    .keyboardShortcut(",")
                    Button {
                        JourneyWindowController.shared.show(state: state)
                    } label: {
                        Image(systemName: "trophy")
                    }
                    .help("Journey…")
                    Button {
                        WelcomeWindowController.shared.show(state: state)
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .help("Welcome… / About Rayna")
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
        .sheet(item: $state.factPage) { f in
            RayFactPage(fact: f, onDone: { state.factPage = nil })
                .frame(width: 420, height: 560)
        }
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

    private func extra(_ get: @escaping () -> Bool, _ set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: get, set: { state.objectWillChange.send(); set($0); state.localChanged() })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandHeader(title: "Rayna Settings",
                        subtitle: "Tune your goal, reminders and extras.",
                        progress: state.progress)
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 14) {
                    BrandCard(title: "Goal", symbol: "target", tint: RaynaBrand.blue) {
                        BrandRow(symbol: "drop.fill", tint: RaynaBrand.blue, title: "Daily goal", detail: "\(state.goalML) ml") {
                            Stepper("", value: $state.goalML, in: 1000...5000, step: 250).labelsHidden()
                        }
                        BrandRow(symbol: "cup.and.saucer.fill", tint: .teal, title: "Glass size", detail: "\(state.glassML) ml") {
                            MacGlassStepper(glassML: $state.glassML)
                        }
                        GlassSizeCustomField(glassML: $state.glassML)
                            .padding(.horizontal, 4)
                    }
                    BrandCard(title: "Reminders", symbol: "bell.badge.fill", tint: .orange) {
                        BrandRow(symbol: "timer", tint: .orange, title: "Remind every", detail: "\(state.intervalMin) min") {
                            Stepper("", value: $state.intervalMin, in: 45...60, step: 5).labelsHidden()
                        }
                        BrandRow(symbol: "app.badge", tint: .red, title: "System notifications too") {
                            Toggle("", isOn: $state.systemNotifications).labelsHidden().toggleStyle(.switch)
                        }
                        Button { NudgeController.shared.show(text: AppState.reminders.randomElement() ?? "Sip o'clock!", isSwap: false) } label: {
                            Label("Preview nudge", systemImage: "play.circle.fill")
                        }
                    }
                    BrandCard(title: "Quiet hours", symbol: "moon.stars.fill", tint: .indigo) {
                        BrandRow(symbol: "moon.fill", tint: .indigo, title: "Quiet from") {
                            DatePicker("", selection: timeBinding(\.quietStartMin), displayedComponents: .hourAndMinute).labelsHidden()
                        }
                        BrandRow(symbol: "sunrise.fill", tint: .yellow, title: "Quiet until") {
                            DatePicker("", selection: timeBinding(\.quietEndMin), displayedComponents: .hourAndMinute).labelsHidden()
                        }
                    }
                }
                BrandCard(title: "Extras", symbol: "sparkles", tint: RaynaBrand.pink) {
                    BrandRow(symbol: "bubbles.and.sparkles.fill", tint: .mint, title: "Fizzy-drink swap nudge", detail: "After 18:00") {
                        Toggle("", isOn: $state.eveningSwap).labelsHidden().toggleStyle(.switch)
                    }
                    BrandRow(symbol: "flag.checkered", tint: .purple, title: "Swap-a-fizzy-drink challenge button", detail: "After 18:00") {
                        Toggle("", isOn: extra({ state.extras.swapChallenge }, { state.extras.swapChallenge = $0 })).labelsHidden().toggleStyle(.switch)
                    }
                    BrandRow(symbol: "lightbulb.fill", tint: .yellow, title: "Ray Facts", detail: "Rayna shares a fact at 25/50/75/100%") {
                        Toggle("", isOn: extra({ state.extras.rayFactsOn }, { state.extras.rayFactsOn = $0 })).labelsHidden().toggleStyle(.switch)
                    }
                    BrandRow(symbol: "speaker.wave.2.fill", tint: .pink, title: "Sounds", detail: "Splash, bubbles, goal chime") {
                        Toggle("", isOn: extra({ RaynaSounds.shared.enabled }, { RaynaSounds.shared.enabled = $0; if $0 { RaynaSounds.shared.play(.splash) } }))
                            .labelsHidden().toggleStyle(.switch)
                    }
                    BrandRow(symbol: "sparkles.rectangle.stack.fill", tint: RaynaBrand.aqua, title: "Show splash on launch") {
                        Toggle("", isOn: extra({ SplashWindowController.enabled }, { SplashWindowController.enabled = $0 })).labelsHidden().toggleStyle(.switch)
                    }
                    BrandRow(symbol: "power", tint: .green, title: "Launch at login") {
                        Toggle("", isOn: Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) }))
                            .labelsHidden().toggleStyle(.switch)
                    }
                    if let sync = RaynaCloudSync.shared {
                        Divider()
                        RaynaSyncSettingsRow(sync: sync).toggleStyle(.switch)
                    }
                    Divider()
                    Button { WelcomeWindowController.shared.show(state: state) } label: {
                        Label("Show welcome…", systemImage: "hand.wave.fill")
                    }
                    #if DEBUG
                    Button { state.unlockBadgesForTesting() } label: {
                        Label("Unlock all badges", systemImage: "rosette")
                    }
                    #endif
                }
            }
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 22).padding(.top, 34)
        .frame(width: 700, height: 720)
        .raynaBackdrop(waveHeight: 70)
    }
}

/// Settings live in a real window: a DisclosureGroup inside a MenuBarExtra(.window)
/// panel doesn't reliably expand/resize, so the Settings click appeared to do nothing.
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(state: AppState) {
        if window == nil {
            window = RaynaBrand.makeWindow(title: "Rayna Settings", root: SettingsView().environmentObject(state))
        }
        RaynaBrand.present(window)
    }
}

/// Collection + weekly recap window.
final class JourneyWindowController {
    static let shared = JourneyWindowController()
    private var window: NSWindow?

    func show(state: AppState) {
        let view = ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BrandHeader(title: "Rayna's journey", subtitle: "Streak, unlocks and your weekly recap.", progress: state.progress)
                RaynaJourneyView(extras: state.extras, recap: state.recap, streak: state.streak) {
                    MacShare.share(state.shareInfo(state.streak >= 3 ? .streak(state.streak) : .recap))
                }
                BrandCard(title: "Pod", symbol: "person.3.fill", tint: RaynaBrand.blue) {
                    PodView(onInvite: { url in MacShare.shareURL(url) })
                        .task { await PodService.shared.refreshStatus() }
                }
                Spacer(minLength: 60)
            }.padding(.horizontal, 20).padding(.top, 34)
        }
        .frame(width: 480, height: 720)
        .raynaBackdrop(waveHeight: 70)
        if let w = window {
            w.contentViewController = NSHostingController(rootView: view)
        } else {
            window = RaynaBrand.makeWindow(title: "Rayna's journey", root: view)
        }
        RaynaBrand.present(window)
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
