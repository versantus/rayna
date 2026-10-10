import SwiftUI
import WatchConnectivity
import WidgetKit

/// Watch-side state, synced with the iPhone over WatchConnectivity (App Groups don't reach the watch).
final class WatchModel: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchModel()
    private let d = UserDefaults(suiteName: WatchKeys.watchGroup) ?? .standard

    @Published var ml: Int = 0
    @Published var goal: Int = 2500
    @Published var glassML: Int = 250
    @Published var streak: Int = 0
    @Published var wiggle = 0

    var progress: Double { goal > 0 ? min(Double(ml) / Double(goal), 1) : 0 }

    override init() {
        super.init()
        load()
        // Screenshots: SIMCTL_CHILD_RAYNA_DEMO_ML=1500 xcrun simctl launch …
        if let v = ProcessInfo.processInfo.environment["RAYNA_DEMO_ML"].flatMap(Int.init) { ml = v; goal = 2500; streak = 14; save() }
        if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() }
    }

    private func load() {
        let today = Self.today
        ml = d.string(forKey: WatchKeys.day) == today ? d.integer(forKey: WatchKeys.ml) : 0
        goal = max(1000, d.integer(forKey: WatchKeys.goal) == 0 ? 2500 : d.integer(forKey: WatchKeys.goal))
        glassML = d.integer(forKey: WatchKeys.glassML) == 0 ? 250 : d.integer(forKey: WatchKeys.glassML)
        streak = d.integer(forKey: WatchKeys.streak)
    }

    private func save() {
        d.set(ml, forKey: WatchKeys.ml); d.set(goal, forKey: WatchKeys.goal); d.set(glassML, forKey: WatchKeys.glassML)
        d.set(streak, forKey: WatchKeys.streak); d.set(Self.today, forKey: WatchKeys.day)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static var today: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func addGlass() {
        ml += glassML; wiggle += 1; save()
        let msg: [String: Any] = [WatchKeys.addGlass: 1]
        if WCSession.default.activationState == .activated, WCSession.default.isReachable {
            WCSession.default.sendMessage(msg, replyHandler: { [weak self] ctx in DispatchQueue.main.async { self?.apply(ctx) } },
                                          errorHandler: { _ in WCSession.default.transferUserInfo(msg) })
        } else {
            WCSession.default.transferUserInfo(msg)   // queued; the phone applies it when it wakes
        }
    }

    private func apply(_ ctx: [String: Any]) {
        if let v = ctx[WatchKeys.ml] as? Int { ml = v }
        if let v = ctx[WatchKeys.goal] as? Int { goal = v }
        if let v = ctx[WatchKeys.glassML] as? Int { glassML = v }
        if let v = ctx[WatchKeys.streak] as? Int { streak = v }
        save()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let ctx = session.receivedApplicationContext
        if !ctx.isEmpty { DispatchQueue.main.async { self.apply(ctx) } }
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.apply(applicationContext) }
    }
}

@main
struct RaynaWatchApp: App {
    @StateObject private var model = WatchModel.shared
    var body: some Scene {
        WindowGroup { WatchHome().environmentObject(model) }
    }
}

struct WatchHome: View {
    @EnvironmentObject var model: WatchModel
    @State private var tilt = 0.0
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.15), lineWidth: 6)
                Circle().trim(from: 0, to: model.progress)
                    .stroke(Color(red: 0.3, green: 0.8, blue: 0.9), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image("band\(raynaBand(model.progress))").resizable().scaledToFit().padding(10)
                    .rotationEffect(.degrees(tilt))
            }
            .frame(height: 96)
            Text(String(format: "%.2f / %.1f L", Double(model.ml) / 1000, Double(model.goal) / 1000))
                .font(.system(.footnote, design: .rounded, weight: .bold))
            Button { model.addGlass() } label: {
                Label("+1 glass", systemImage: "drop.fill").font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.1, green: 0.55, blue: 0.85))
        }
        .onChange(of: model.wiggle) { _, _ in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) { tilt = 10 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { withAnimation(.spring) { tilt = 0 } }
        }
        .containerBackground(Color(red: 0.03, green: 0.2, blue: 0.35).gradient, for: .navigation)
    }
}
