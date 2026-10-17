import RaynaCore
import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var pod = PodService.shared
    @State private var confettiID = 0
    @State private var showConfetti = false
    @State private var wiggleAt: Date? = nil
    @State private var flipAt: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    quipBubble
                    RaynaView(progress: state.progress, wiggleAt: wiggleAt, flipAt: flipAt,
                              size: RaynaStage.side(width: 352, height: 380), accessories: state.accessories)
                        .frame(maxWidth: .infinity)
                        .frame(height: RaynaStage.side(width: 352, height: 380))
                    amount
                    if pod.status == .inPod && !pod.visibleMembers.isEmpty { podCard }
                    if state.showSwap { swapCard }
                    buttons
                    GlassSizeQuickAdd(glassML: $state.glassML)
                    if state.runDay && state.exerciseExtraOn && !state.kidMode {
                        Label("Exercise day +\(state.runBonusML) ml", systemImage: RaynaCopy.exerciseDaySymbol)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Spacer()
                        Button("Quit Rayna") { NSApp.terminate(nil) }
                            .keyboardShortcut("q")
                    }
                }
                .padding(14)
            }
            .background {
                ZStack {
                    WaterBackground(progress: state.progress)
                    if state.kidMode { RayVisitorsLayer(visitors: RayVisitor.visiting(streak: state.streak)) }
                }
            }

            if showConfetti {
                ConfettiView().id(confettiID)
                if state.kidMode { ConfettiView().id(confettiID + 1).scaleEffect(1.6) }
            }
            if let u = state.unlockBanner {
                RaynaUnlockBanner(unlock: u, onShare: {
                    state.unlockBanner = nil
                    ShareWindowController.shared.show(info: state.shareInfo(.unlock(u)))
                }) { state.unlockBanner = nil }
                    .scaleEffect(0.9)
            }
        }
        .frame(width: 380, height: 740)
        .sheet(item: $state.factPage) { f in
            RayFactPage(fact: f, onDone: { state.factPage = nil })
                .frame(width: 420, height: 560)
        }
        .onChange(of: state.celebrate) { newValue in
            if newValue { party() }
        }
        .onChange(of: state.glassEvent) { _ in wiggleAt = Date() }
        .onAppear {
            if state.celebrate && state.progress >= 1 { party() }
            Task { await RaynaCloudSync.shared?.catchUp() }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rayna").font(.system(.title, design: .rounded, weight: .heavy))
                StreakDots(streak: state.streak, goalDays: state.goalDays)
            }
            Spacer(minLength: 8)
            Button {
                JourneyWindowController.shared.show(state: state)
            } label: {
                Image(systemName: "trophy.fill")
            }
            .help("Collection and weekly recap")
            Button {
                SettingsWindowController.shared.show(state: state)
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .help("Settings… (⌘,)")
            .keyboardShortcut(",")
        }
    }

    @ViewBuilder private var quipBubble: some View {
        if let f = state.bubbleFact {
            Button { state.factPage = f } label: {
                VStack(spacing: 6) {
                    RayFactTag()
                    Text(f.text).font(.system(size: 13, weight: .semibold)).multilineTextAlignment(.center)
                    Text("Tap to read more").font(.system(size: 11)).foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.85)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 8) {
                Text(state.quip)
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.center)
                if state.progress >= 1 {
                    Button {
                        ShareWindowController.shared.show(info: state.shareInfo(.goal))
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Share your goal")
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.accentColor.opacity(0.12)))
        }
    }

    private var amount: some View {
        VStack(spacing: 2) {
            Text(RaynaCopy.amountTitle(ml: state.totalML, glassML: state.glassML, kidMode: state.kidMode))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
            Text(RaynaCopy.amountSubtitle(ml: state.totalML, goal: state.effectiveGoal, glassML: state.glassML, kidMode: state.kidMode))
                .font(.system(size: 13, design: .rounded)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var podCard: some View {
        Button { PodWindowController.shared.show() } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.3.fill").foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your pod · \(pod.podName)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        ForEach(pod.visibleMembers.prefix(6)) { m in
                            let shown = pod.displayed(m)
                            ProgressView(value: shown.todayProgress)
                                .tint(shown.todayProgress >= 1 ? .green : .accentColor)
                                .frame(maxWidth: 36)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundColor(.secondary)
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .help("Opens the pod screen")
    }

    private var swapCard: some View {
        Button { state.logSwap() } label: {
            HStack(spacing: 10) {
                Text("🥤➡️💧")
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.swapThanks ?? RaynaCopy.swapButtonTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text(RaynaCopy.swapDetail(streak: state.extras.swapStreak(), total: state.extras.swapsTotal))
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Button { state.addGlass() } label: {
                Label(RaynaCopy.addGlassLabel(glassML: state.glassML, kidMode: state.kidMode), systemImage: "drop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button { state.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .controlSize(.large)
            .disabled(state.totalML == 0)
            .help("Undo last glass")
        }
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
    @ObservedObject private var pod = PodService.shared

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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BrandHeader(title: "Settings",
                            subtitle: "Tune your goal, reminders and extras.",
                            progress: state.progress)
                BrandCard(title: "Friends", symbol: "person.3.fill", tint: RaynaBrand.blue) {
                    Button { PodWindowController.shared.show() } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pods").font(.system(size: 13, weight: .semibold))
                                Text(pod.status == .inPod ? pod.podName : "Hydrate with friends over iCloud")
                                    .font(.system(size: 11)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    Text("Start or join a pod, invite friends, nudge each other and build a pod streak.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                BrandCard(title: RaynaFeatures.kidMode ? "Ray Facts & kids" : "Ray Facts", symbol: "book.closed.fill", tint: .yellow) {
                    BrandRow(symbol: "lightbulb.fill", tint: .yellow, title: "Ray Facts", detail: "Rayna shares a fact at 25/50/75/100%") {
                        Toggle("", isOn: extra({ state.extras.rayFactsOn }, { state.extras.rayFactsOn = $0 })).labelsHidden().toggleStyle(.switch)
                    }
                    if RaynaFeatures.kidMode {
                        BrandRow(symbol: "figure.and.child.holdinghands", tint: RaynaBrand.pink, title: "Kid mode") {
                            Toggle("", isOn: Binding(get: { state.kidMode }, set: { state.setKidMode($0) })).labelsHidden().toggleStyle(.switch)
                        }
                    }
                    Text(RaynaFeatures.kidMode
                         ? "Ray Facts: Rayna shares a real ray fact at 25, 50, 75 and 100% of your goal. Tap her bubble to read it; then it swims off. Kid mode: cups instead of litres, a 1.5 L goal, simpler words, bigger celebrations and ray friends who visit as the streak grows. In a pod, kids are marked so grown-ups can follow along."
                         : "Rayna shares a real ray fact at 25, 50, 75 and 100% of your goal. Tap her bubble to read it; then it swims off.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                BrandCard(title: "Daily goal", symbol: "target", tint: RaynaBrand.blue) {
                    BrandRow(symbol: "drop.fill", tint: RaynaBrand.blue, title: "Goal: \(String(format: "%.2f L", Double(state.goalML) / 1000))") {
                        Stepper("", value: $state.goalML, in: 1000...5000, step: 250).labelsHidden()
                    }
                    GlassSizePicker(glassML: $state.glassML)
                }
                BrandCard(title: "Exercise days", symbol: "dumbbell.fill", tint: RaynaBrand.blue) {
                    BrandRow(symbol: "dumbbell.fill", tint: RaynaBrand.blue, title: "Add extra water on exercise days") {
                        Toggle("", isOn: $state.exerciseExtraOn).labelsHidden().toggleStyle(.switch)
                    }
                    if state.exerciseExtraOn {
                        BrandRow(symbol: "drop.fill", tint: RaynaBrand.aqua, title: "Extra water: +\(state.runBonusML) ml") {
                            Stepper("", value: $state.runBonusML, in: 250...1500, step: 250).labelsHidden()
                        }
                        BrandRow(symbol: "checkmark.circle.fill", tint: .green, title: "Today is an exercise day") {
                            Toggle("", isOn: $state.runDay).labelsHidden().toggleStyle(.switch)
                        }
                    }
                    Text("On an exercise day Rayna adds the extra water to today's goal. An iPhone can turn the day on from Apple Health. This Mac follows that, and you can switch today on or off here. There is no Health connection on the Mac.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                BrandCard(title: "Sounds", symbol: "speaker.wave.2.fill", tint: .pink) {
                    BrandRow(symbol: "speaker.wave.2.fill", tint: .pink, title: "Sounds") {
                        Toggle("", isOn: extra({ RaynaSounds.shared.enabled }, { RaynaSounds.shared.enabled = $0; if $0 { RaynaSounds.shared.play(.splash) } }))
                            .labelsHidden().toggleStyle(.switch)
                    }
                    Text("Gentle ocean sounds: a splash for each glass, bubbles when Rayna wiggles and a chime when you hit your goal. They follow your silent switch and mix with your music.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                BrandCard(title: "Reminders", symbol: "bell.badge.fill", tint: .orange) {
                    BrandRow(symbol: "bell.fill", tint: .orange, title: "Reminders") {
                        Toggle("", isOn: $state.remindersOn).labelsHidden().toggleStyle(.switch)
                    }
                    ReminderIntervalPicker(minutes: $state.intervalMin)
                        .disabled(!state.remindersOn)
                    BrandRow(symbol: "moon.fill", tint: .indigo, title: "Quiet from") {
                        DatePicker("", selection: timeBinding(\.quietStartMin), displayedComponents: .hourAndMinute).labelsHidden()
                    }
                    BrandRow(symbol: "sunrise.fill", tint: .yellow, title: "Quiet until") {
                        DatePicker("", selection: timeBinding(\.quietEndMin), displayedComponents: .hourAndMinute).labelsHidden()
                    }
                    BrandRow(symbol: "bubbles.and.sparkles.fill", tint: .mint, title: "Fizzy-drink swap nudge 🥤➡️💧") {
                        Toggle("", isOn: $state.eveningSwap).labelsHidden().toggleStyle(.switch)
                    }
                    BrandRow(symbol: "flag.checkered", tint: .purple, title: "Swap-a-fizzy-drink challenge (after 18:00)") {
                        Toggle("", isOn: extra({ state.extras.swapChallenge }, { state.extras.swapChallenge = $0 })).labelsHidden().toggleStyle(.switch)
                    }
                    BrandRow(symbol: "app.badge", tint: .red, title: "System notifications too") {
                        Toggle("", isOn: $state.systemNotifications).labelsHidden().toggleStyle(.switch)
                    }
                    Button { NudgeController.shared.show(text: RaynaCopy.nextReminder(), isSwap: false) } label: {
                        Label("Preview nudge", systemImage: "play.circle.fill")
                    }
                    Text("Rayna nudges you during waking hours only. Tap “Drank one 💧” on a notification to log a glass without opening the app.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                if let sync = RaynaCloudSync.shared {
                    BrandCard(title: "iCloud", symbol: "icloud.fill", tint: RaynaBrand.blue) {
                        RaynaSyncSettingsRow(sync: sync).toggleStyle(.switch)
                        Text("Syncs today's water, your history and settings between your iPhone, Apple Watch and Mac through your private iCloud.")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                BrandCard(title: "This Mac", symbol: "laptopcomputer", tint: RaynaBrand.aqua) {
                    BrandRow(symbol: "sparkles.rectangle.stack.fill", tint: RaynaBrand.aqua, title: "Show splash on launch") {
                        Toggle("", isOn: extra({ SplashWindowController.enabled }, { SplashWindowController.enabled = $0 })).labelsHidden().toggleStyle(.switch)
                    }
                    BrandRow(symbol: "power", tint: .green, title: "Launch at login") {
                        Toggle("", isOn: Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) }))
                            .labelsHidden().toggleStyle(.switch)
                    }
                    Button { WelcomeWindowController.shared.show(state: state) } label: {
                        Label("Show welcome…", systemImage: "hand.wave.fill")
                    }
                }
                #if DEBUG
                BrandCard(title: "Debug", symbol: "ladybug.fill", tint: .orange) {
                    Button { state.unlockBadgesForTesting() } label: {
                        Label("Unlock all badges", systemImage: "rosette")
                    }
                    Text("Debug builds only. Launch with RAYNA_BADGES=all, or a comma-separated list: surge, tide, flood, over3, over7, over30, personalBest, podWave.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                #endif
                BrandCard(title: "About", symbol: "hand.raised.fill", tint: .secondary) {
                    Link("Privacy policy", destination: URL(string: "https://rayna-water.netlify.app/privacy.html")!)
                    Link("Rayna for iPhone", destination: URL(string: "https://rayna-water.netlify.app")!)
                    Text("Everything stays on this Mac (and iCloud if you turn it on). No accounts, no tracking.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 22).padding(.top, 34).padding(.bottom, 28)
        }
        .frame(width: 460, height: 720)
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
                RaynaJourneyView(extras: state.extras, recap: state.recap, streak: state.streak, onWear: { set in
                    state.extras.wornBadges = set
                    state.objectWillChange.send()
                    state.localChanged()
                }) {
                    ShareWindowController.shared.show(info: state.shareInfo(state.streak >= 3 ? .streak(state.streak) : .recap))
                }
                Spacer(minLength: 60)
            }.padding(.horizontal, 20).padding(.top, 34)
        }
        .frame(width: 480, height: 640)
        .raynaBackdrop(waveHeight: 70)
        if let w = window {
            w.contentViewController = NSHostingController(rootView: view)
        } else {
            window = RaynaBrand.makeWindow(title: "Rayna's journey", root: view)
        }
        RaynaBrand.present(window)
    }
}
/// Full pod screen: the same `PodView` as iPhone Settings → Pods.
@MainActor
final class PodWindowController {
    static let shared = PodWindowController()
    private var window: NSWindow?

    func show() {
        let root = ScrollView {
            PodView()
                .padding(20)
                .padding(.top, 28)
        }
        .frame(width: 520, height: 680)
        .raynaBackdrop(waveHeight: 70)
        if window == nil {
            window = RaynaBrand.makeWindow(title: "Pod", root: root)
        } else {
            window?.contentViewController = NSHostingController(rootView: root)
        }
        RaynaBrand.present(window)
        let s = AppState.shared
        Task { @MainActor in
            await PodService.shared.openPod(glasses: s.glasses, ml: s.totalML, goal: s.effectiveGoal, streak: s.streak, isKid: s.extras.kidMode)
        }
    }
}

/// Story and square share cards, then the Mac share picker. Same two sizes as the iPhone sheet.
final class ShareWindowController {
    static let shared = ShareWindowController()
    private var window: NSWindow?

    func show(info: RaynaShareInfo) {
        let root = MacSharePreview(info: info) { [weak self] in
            self?.window?.close()
        }
        if window == nil {
            window = RaynaBrand.makeWindow(title: "Share", root: root)
        } else {
            window?.contentViewController = NSHostingController(rootView: root)
        }
        RaynaBrand.present(window)
    }
}

struct MacSharePreview: View {
    let info: RaynaShareInfo
    var onDone: () -> Void
    @State private var story: NSImage?
    @State private var square: NSImage?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Share").font(.system(.title3, design: .rounded, weight: .bold))
                if let story {
                    Image(nsImage: story).resizable().scaledToFit().frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    Button { MacShare.share(info, square: false) } label: {
                        Label("Share story (1080×1920)", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                if let square {
                    Image(nsImage: square).resizable().scaledToFit().frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    Button { MacShare.share(info, square: true) } label: {
                        Label("Share square (1080×1080)", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                if story == nil { ProgressView().padding(40) }
                Button("Done", action: onDone)
            }
            .padding(20)
        }
        .frame(width: 420, height: 640)
        .task {
            if let cg = RaynaShareRenderer.image(info, square: false) {
                story = NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width), height: CGFloat(cg.height)))
            }
            if let cg = RaynaShareRenderer.image(info, square: true) {
                square = NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width), height: CGFloat(cg.height)))
            }
        }
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
        share(urls: RaynaShareRenderer.pngFiles(info))
    }

    /// One card: story or square. Falls back to both files if that PNG was not written.
    @MainActor
    static func share(_ info: RaynaShareInfo, square: Bool) {
        let urls = RaynaShareRenderer.pngFiles(info)
        let name = square ? "Rayna-square.png" : "Rayna-story.png"
        let picked = urls.filter { $0.lastPathComponent == name }
        share(urls: picked.isEmpty ? urls : picked)
    }

    @MainActor
    static func share(urls: [URL]) {
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
