import RaynaCore
import SwiftUI
import AppKit

// MARK: - Shared visual language (matches the menu-bar popover)

enum RaynaBrand {
    static let blue = Color(red: 0.04, green: 0.45, blue: 0.9)
    static let aqua = Color(red: 0.35, green: 0.78, blue: 0.98)
    static let pink = Color(red: 1, green: 0.56, blue: 0.69)
    static let sky = LinearGradient(colors: [aqua.opacity(0.18), blue.opacity(0.06), .clear],
                                    startPoint: .top, endPoint: .bottom)

    /// Bring an LSUIElement (accessory) app's window to the very front.
    static func present(_ window: NSWindow?) {
        NSApp.keyWindow?.orderOut(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    static func makeWindow<V: View>(title: String, root: V) -> NSWindow {
        let w = NSWindow(contentViewController: NSHostingController(rootView: root))
        w.title = title
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.center()
        return w
    }
}

/// Branded header: Rayna in a progress ring + title and subtitle.
struct BrandHeader: View {
    var title: String
    var subtitle: String
    var progress: Double
    var ringSize: CGFloat = 76

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: progress).frame(width: ringSize, height: ringSize)
                RaynaView(progress: max(progress, 0.5)).frame(width: ringSize * 0.86, height: ringSize * 0.86)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 22, weight: .bold, design: .rounded))
                Text(subtitle).font(.system(size: 13)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Rounded material card with a coloured SF Symbol title.
struct BrandCard<Content: View>: View {
    var title: String
    var symbol: String
    var tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title).font(.system(size: 13, weight: .semibold, design: .rounded))
            } icon: {
                Image(systemName: symbol).foregroundColor(tint)
            }
            VStack(alignment: .leading, spacing: 8) { content }
                .font(.system(size: 12.5))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RaynaBrand.aqua.opacity(0.25), lineWidth: 1))
    }
}

/// A settings row: coloured symbol, label that wraps (never truncates), control on the right.
struct BrandRow<Control: View>: View {
    var symbol: String
    var tint: Color
    var title: String
    var detail: String? = nil
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol).foregroundColor(tint).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).fixedSize(horizontal: false, vertical: true)
                if let detail { Text(detail).font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            control
        }
    }
}

/// Window chrome: sky gradient behind, animated water wave pinned to the bottom.
struct BrandBackdrop: ViewModifier {
    var waveHeight: CGFloat = 90
    func body(content: Content) -> some View {
        content
            .background(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    RaynaBrand.sky
                    WaterBackground(progress: 0.5).frame(height: waveHeight)
                }
                .ignoresSafeArea()
            }
            .tint(RaynaBrand.blue)
            .accentColor(RaynaBrand.blue)
    }
}
extension View {
    func raynaBackdrop(waveHeight: CGFloat = 90) -> some View { modifier(BrandBackdrop(waveHeight: waveHeight)) }
}

// MARK: - Welcome (first launch)

struct WelcomeView: View {
    @EnvironmentObject var state: AppState
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                ProgressRing(progress: 0.68).frame(width: 150, height: 150)
                RaynaView(progress: 0.8, size: 130).frame(width: 130, height: 130)
            }
            .padding(.top, 34)
            VStack(spacing: 6) {
                Text("Hi, I'm Rayna!").font(.system(size: 28, weight: .bold, design: .rounded))
                Text("A little stingray who lives in your menu bar and keeps you sipping, one glass at a time.")
                    .font(.system(size: 14)).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 380)
            }
            BrandCard(title: "Quick setup", symbol: "slider.horizontal.3", tint: RaynaBrand.blue) {
                BrandRow(symbol: "target", tint: RaynaBrand.blue, title: "Daily goal", detail: String(format: "%.2f L", Double(state.goalML) / 1000)) {
                    Stepper("", value: $state.goalML, in: 1000...5000, step: 250).labelsHidden()
                }
                GlassSizePicker(glassML: $state.glassML)
                Divider()
                BrandRow(symbol: "power", tint: .green, title: "Launch at login") {
                    Toggle("", isOn: Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) }))
                        .labelsHidden().toggleStyle(.switch)
                }
            }
            .frame(maxWidth: 400)
            Text("Find me any time in the menu bar: click the drop to log a glass.")
                .font(.system(size: 11)).foregroundColor(.secondary)
            Button(action: onDone) {
                Text("Get started").font(.system(size: 14, weight: .semibold)).frame(width: 220)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .keyboardShortcut(.defaultAction)
            Spacer(minLength: 70)
        }
        .padding(.horizontal, 28)
        .frame(width: 480, height: 760)
        .raynaBackdrop(waveHeight: 110)
    }
}

final class WelcomeWindowController {
    static let shared = WelcomeWindowController()
    static let seenKey = "hasSeenWelcome"
    private var window: NSWindow?

    static var hasSeen: Bool { UserDefaults.standard.bool(forKey: seenKey) }

    func showIfFirstLaunch(state: AppState) {
        if CommandLine.arguments.contains("--reset-welcome") { UserDefaults.standard.removeObject(forKey: Self.seenKey) }
        guard !Self.hasSeen else {
            if SplashWindowController.enabled || CommandLine.arguments.contains("--show-splash") { SplashWindowController.shared.show() }
            return
        }
        show(state: state)
    }

    func show(state: AppState) {
        if window == nil {
            let root = WelcomeView(onDone: { [weak self] in
                UserDefaults.standard.set(true, forKey: WelcomeWindowController.seenKey)
                self?.window?.close()
            }).environmentObject(state)
            window = RaynaBrand.makeWindow(title: "Welcome to Rayna", root: root)
        }
        RaynaBrand.present(window)
    }
}

// MARK: - Launch splash (every launch except the first, when Welcome shows)

struct SplashView: View {
    var onTap: () -> Void
    @State private var rise = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(colors: [RaynaBrand.aqua.opacity(0.35), Color.white.opacity(0.95)], startPoint: .bottom, endPoint: .top)
            VStack(spacing: 8) {
                RaynaView(progress: 0.8, size: 120)
                    .frame(width: 120, height: 120)
                    .offset(y: reduceMotion ? 0 : (rise ? -4 : 6))
                Text("Rayna").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundColor(RaynaBrand.blue)
                Text("Sip, sip, hooray!").font(.system(size: 13)).foregroundColor(.secondary)
            }
            .padding(.bottom, 30)
            VStack { Spacer(); WaterBackground(progress: 0.55).frame(height: 90) }
        }
        .frame(width: 300, height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(RaynaBrand.aqua.opacity(0.4), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { rise = true } } }
    }
}

final class SplashWindowController {
    static let shared = SplashWindowController()
    static let enabledKey = "showSplash"
    private var window: NSWindow?

    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    func show(duration: TimeInterval = 1.8) {
        guard window == nil else { return }
        let host = NSHostingController(rootView: SplashView(onTap: { [weak self] in self?.dismiss() }))
        let w = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 300), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        w.contentViewController = host
        w.setContentSize(NSSize(width: 300, height: 300))
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.level = .floating
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.isReleasedWhenClosed = false
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.alphaValue = 0
        w.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.25; w.animator().alphaValue = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in self?.dismiss() }
    }

    func dismiss() {
        guard let w = window else { return }
        window = nil
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup({ $0.duration = reduce ? 0.1 : 0.45; w.animator().alphaValue = 0 }) { w.orderOut(nil) }
    }
}
