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
    /// The scene worn on the phone ("" for none): fish, grass, moon and shells, or baby rays in the watch sea.
    @Published var scene = ""
    /// Glasses and undos tapped before the phone heard about them. Sent on activation.
    private var unsentGlasses = 0
    private var unsentUndos = 0

    var progress: Double { goal > 0 ? min(Double(ml) / Double(goal), 1) : 0 }

    override init() {
        super.init()
        load()
        // Screenshots: SIMCTL_CHILD_RAYNA_DEMO_ML=1500 xcrun simctl launch …
        if let v = ProcessInfo.processInfo.environment["RAYNA_DEMO_ML"].flatMap(Int.init) { ml = v; goal = 2500; streak = 14; save() }
        if let v = ProcessInfo.processInfo.environment["RAYNA_DEMO_SCENE"] { scene = v; save() }
        if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() }
    }

    private func load() {
        let today = Self.today
        ml = d.string(forKey: WatchKeys.day) == today ? d.integer(forKey: WatchKeys.ml) : 0
        goal = max(1000, d.integer(forKey: WatchKeys.goal) == 0 ? 2500 : d.integer(forKey: WatchKeys.goal))
        glassML = d.integer(forKey: WatchKeys.glassML) == 0 ? 250 : d.integer(forKey: WatchKeys.glassML)
        streak = d.integer(forKey: WatchKeys.streak)
        scene = d.string(forKey: WatchKeys.scene) ?? ""
    }

    private func save() {
        d.set(ml, forKey: WatchKeys.ml); d.set(goal, forKey: WatchKeys.goal); d.set(glassML, forKey: WatchKeys.glassML)
        d.set(streak, forKey: WatchKeys.streak); d.set(Self.today, forKey: WatchKeys.day); d.set(scene, forKey: WatchKeys.scene)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static var today: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func addGlass() {
        ml += glassML; wiggle += 1; save()
        unsentGlasses += 1
        relay()
    }

    /// Takes back the last glass. Shown straight away; the phone does the real undo and replies with the total.
    func undo() {
        guard ml > 0 else { return }
        ml = max(0, ml - glassML); save()
        if unsentGlasses > 0 { unsentGlasses -= 1 } else { unsentUndos += 1 }   // a + not sent yet just cancels
        relay()
    }

    /// Reachable: sendMessage, which wakes the phone. Otherwise transferUserInfo, which waits until it is.
    private func relay() {
        guard unsentGlasses + unsentUndos > 0, WCSession.default.activationState == .activated else { return }
        var msg: [String: Any] = [:]
        if unsentGlasses > 0 { msg[WatchKeys.addGlass] = unsentGlasses }
        if unsentUndos > 0 { msg[WatchKeys.undoGlass] = unsentUndos }
        unsentGlasses = 0; unsentUndos = 0
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(msg, replyHandler: { [weak self] ctx in
                DispatchQueue.main.async { self?.apply(ctx) }
            }, errorHandler: { _ in WCSession.default.transferUserInfo(msg) })
        } else {
            WCSession.default.transferUserInfo(msg)
        }
    }

    private func apply(_ ctx: [String: Any]) {
        if let v = ctx[WatchKeys.ml] as? Int { ml = v }
        if let v = ctx[WatchKeys.goal] as? Int { goal = v }
        if let v = ctx[WatchKeys.glassML] as? Int { glassML = v }
        if let v = ctx[WatchKeys.streak] as? Int { streak = v }
        if let v = ctx[WatchKeys.scene] as? String { scene = v }
        save()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let ctx = session.receivedApplicationContext
        DispatchQueue.main.async {
            if !ctx.isEmpty { self.apply(ctx) }
            self.relay()
        }
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.apply(applicationContext) }
    }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.apply(message) }
    }
}

@main
struct RaynaWatchApp: App {
    @StateObject private var model = WatchModel.shared
    var body: some Scene {
        WindowGroup { WatchHome().environmentObject(model) }
    }
}

/// Immersive, like the iPhone: the whole screen is the sea, the water rises with today's progress,
/// and Rayna floats in the middle. Litres at the top, + at the bottom.
struct WatchHome: View {
    @EnvironmentObject var model: WatchModel
    @Environment(\.isLuminanceReduced) private var dimmed
    @State private var tilt = 0.0
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width * 1.05, geo.size.height * 0.8)
            ZStack {
                WatchSea(progress: model.progress, scene: SeaSceneKind(rawValue: model.scene), still: dimmed)
                    .ignoresSafeArea()
                Image("band\(raynaBand(model.progress))").resizable().scaledToFit()
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(tilt))
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.46)
                    .accessibilityLabel("Rayna, \(Int(model.progress * 100)) percent of today's goal")
                VStack(spacing: 0) {
                    Text(String(format: "%.2f / %.1f L", Double(model.ml) / 1000, Double(model.goal) / 1000))
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 2)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        Button { model.undo() } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(.white.opacity(model.ml == 0 ? 0.08 : 0.2)))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(model.ml == 0 ? 0.4 : 1))
                        .disabled(model.ml == 0)
                        .accessibilityLabel("Undo last glass")
                        Button { model.addGlass() } label: {
                            Label("+\(model.glassML) ml", systemImage: "drop.fill")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .lineLimit(1).minimumScaleFactor(0.6)
                                .padding(.horizontal, 14)
                                .frame(height: 40)
                                .background(Capsule().fill(Color(red: 0.1, green: 0.55, blue: 0.85)))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                    }
                    .padding(.bottom, 2)
                }
                .ignoresSafeArea(.container, edges: .bottom)      // buttons sit right at the bottom edge
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onChange(of: model.wiggle) { _, _ in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) { tilt = 10 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { withAnimation(.spring) { tilt = 0 } }
        }
        .containerBackground(Color(red: 0.03, green: 0.12, blue: 0.24).gradient, for: .navigation)
    }
}

/// Night sky over a rising sea, with the same waterline as the iPhone (0% near the bottom, 100% near the top).
/// Waves and bubbles move only while the watch is awake; always-on shows it still.
struct WatchSea: View {
    var progress: Double
    var scene: SeaSceneKind? = nil
    var still: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: still)) { tl in
            Canvas { ctx, size in
                let t = still ? 0 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
                let p = max(0, min(1, progress))
                let level = size.height * (1 - (0.06 + 0.88 * p))
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: [Color(red: 0.03, green: 0.10, blue: 0.22), Color(red: 0.04, green: 0.18, blue: 0.33)]),
                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                func wave(_ amp: Double, _ k: Double, _ speed: Double, _ phase: Double) -> Path {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: size.height))
                    for x in stride(from: 0.0, through: Double(size.width) + 4, by: 4) {
                        path.addLine(to: CGPoint(x: x, y: level + sin(x * k + t * speed + phase) * amp))
                    }
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.closeSubpath()
                    return path
                }
                ctx.fill(wave(3, 0.06, 1.3, 1.2), with: .color(Color(red: 0.3, green: 0.7, blue: 0.95).opacity(0.25)))
                ctx.fill(wave(2.5, 0.08, -1.8, 0),
                         with: .linearGradient(Gradient(colors: [Color(red: 0.25, green: 0.65, blue: 0.95).opacity(0.55),
                                                                 Color(red: 0.05, green: 0.35, blue: 0.75).opacity(0.75)]),
                                               startPoint: CGPoint(x: 0, y: level), endPoint: CGPoint(x: 0, y: size.height)))
                if let scene {
                    for item in SeaSceneLayout.items(for: scene, progress: p, size: size, time: t, compact: true) { draw(item, in: ctx) }
                }
                guard !still else { return }
                for i in 0..<5 {                        // a few bubbles rising from the bottom
                    let period = 4.0 + Double(i) * 1.3
                    let k = ((t + Double(i) * 1.7).truncatingRemainder(dividingBy: period)) / period
                    let y = size.height - k * (size.height - level)
                    let x = size.width * (0.15 + 0.17 * Double(i)) + sin(t * 2 + Double(i)) * 3
                    let r = 1.5 + Double(i % 3)
                    ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                               with: .color(.white.opacity(0.5 * (1 - k))), lineWidth: 1)
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// Same drawing as the iPhone's SeaScene: sway about the root, turn about the centre, a little bluer underwater.
    private func draw(_ item: SeaSceneItem, in ctx: GraphicsContext) {
        var c = ctx
        if item.glow > 0 {
            let r = max(item.size.width, item.size.height) * 0.85
            c.fill(Path(ellipseIn: CGRect(x: item.center.x - r, y: item.center.y - r, width: 2 * r, height: 2 * r)),
                   with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.96, blue: 0.8).opacity(item.glow), .clear]),
                                         center: item.center, startRadius: r * 0.4, endRadius: r))
        }
        if item.underwater { c.addFilter(.colorMultiply(Color(red: 0.86, green: 0.95, blue: 1))) }
        c.translateBy(x: item.center.x, y: item.center.y + item.size.height / 2)
        if item.shear != 0 { c.concatenate(CGAffineTransform(a: 1, b: 0, c: -item.shear, d: 1, tx: 0, ty: 0)) }
        c.translateBy(x: 0, y: -item.size.height / 2)
        c.rotate(by: .degrees(item.degrees))
        if item.flipped { c.scaleBy(x: -1, y: 1) }
        c.draw(Image("scene-\(item.sprite)"),
               in: CGRect(x: -item.size.width / 2, y: -item.size.height / 2, width: item.size.width, height: item.size.height))
    }
}
