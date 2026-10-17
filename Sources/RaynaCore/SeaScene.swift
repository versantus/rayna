import SwiftUI
import ImageIO

// MARK: - Scene badges: life in the water around Rayna (fish, seagrass, moon and shells, baby rays)
//
// A scene has no water of its own. It is drawn into the ocean WaterBackground already draws, using the same
// waterline for the same progress and size: plants grow from the seabed and never above the water, swimmers stay
// below the waterline (fewer and smaller when it is shallow), and the moon needs sky above the water.
// Sprites ship in RaynaFrames/scene (cut from Higgsfield sheets by tools/rayna-frames/sprites.py).

/// One sprite placed for one moment. `center` and `size` are in points in the scene's frame.
public struct SeaSceneItem: Equatable {
    public var sprite: String
    public var center: CGPoint
    public var size: CGSize
    /// Clockwise turn about the centre.
    public var degrees: Double = 0
    /// Sideways lean of the top against the bottom edge (plants sway from the root).
    public var shear: Double = 0
    public var flipped = false
    /// In the water: drawn a touch bluer so it sits in it.
    public var underwater = true
    /// Soft halo behind the sprite (the moon), 0 for none.
    public var glow: Double = 0
}

public enum SeaSceneLayout {
    /// Width / height of each sprite, so layout needs no image decoding.
    static let aspect: [String: CGFloat] = [
        "fish-yellow": 1.30, "fish-coral": 1.29, "fish-mint": 1.27, "fish-lilac": 1.27,
        "grass-tall": 0.346, "grass-mid": 0.419, "grass-short": 0.839,
        "moon": 1.02, "shell-scallop": 1.06, "shell-spiral": 0.78, "starfish": 0.97,
        "ray-lilac": 0.72, "ray-mint": 0.72, "ray-blue": 0.73,
    ]

    /// The sprite that stands for a scene on small badge marks.
    public static func mark(_ scene: RaynaUnlock) -> String? {
        switch scene {
        case .surge: return "fish-yellow"
        case .tide: return "moon"
        case .flood: return "grass-mid"
        case .podWave: return "ray-mint"
        default: return nil
        }
    }

    /// Everything to draw for `scene` at time `t` (seconds; 0 when Reduce Motion is on).
    public static func items(for scene: RaynaUnlock, progress: Double, size: CGSize, time t: Double) -> [SeaSceneItem] {
        let w = size.width, h = size.height
        guard w > 0, h > 0, scene.slot == .scene else { return [] }
        let u = min(w, 520)                                   // sprite scale; an iPad doesn't get giant fish
        let line = WaterBackground.waterline(progress: progress, height: h)
        let depth = h - line
        let top = line + 0.15 * depth, bottom = h - 0.14 * depth
        let swim = depth > 0.1 * h
        let shallow = depth < 0.3 * h
        let k: CGFloat = shallow ? 0.75 : 1

        func sized(_ name: String, width: CGFloat) -> CGSize { CGSize(width: width, height: width / (aspect[name] ?? 1)) }
        func tall(_ name: String, height: CGFloat) -> CGSize { CGSize(width: height * (aspect[name] ?? 1), height: height) }
        /// Keeps a swimmer's whole body under the wave.
        func underWave(_ y: CGFloat, _ s: CGSize) -> CGFloat { max(y, line + s.height / 2 + 6) }

        var out: [SeaSceneItem] = []
        switch scene {
        case .surge:   // a little shoal crossing the water, alternate fish each way
            guard swim else { return [] }
            let fish = ["fish-yellow", "fish-coral", "fish-mint", "fish-lilac"].prefix(shallow ? 2 : 4)
            for (i, name) in fish.enumerated() {
                let s = sized(name, width: 0.15 * u * k)
                let right = i % 2 == 0
                let span = w + 2 * s.width
                let speed = u * (0.035 + 0.012 * Double(i))
                let start = span * CGFloat((0.12 + 0.24 * Double(i)).truncatingRemainder(dividingBy: 1))
                var x = (start + CGFloat(t * speed) * (right ? 1 : -1)).truncatingRemainder(dividingBy: span)
                if x < 0 { x += span }
                let lane = 0.25 + 0.5 * (Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
                let y = top + (bottom - top) * lane + CGFloat(sin(t * 0.8 + Double(i))) * 0.012 * h
                out.append(SeaSceneItem(sprite: name, center: CGPoint(x: x - s.width, y: underWave(y, s)), size: s,
                                        degrees: sin(t * 1.6 + Double(i)) * 4, flipped: !right))
            }
        case .tide:    // the moon in the sky, shells and a starfish on the sand
            let moon = sized("moon", width: 0.22 * u)
            if line > 0.2 * h + moon.height {
                out.append(SeaSceneItem(sprite: "moon", center: CGPoint(x: 0.8 * w, y: 0.2 * h + moon.height / 2 + CGFloat(sin(t * 0.5)) * 3),
                                        size: moon, underwater: false, glow: 0.35 + 0.15 * sin(t * 0.8)))
            }
            for (name, x, width, wiggle) in [("shell-scallop", 0.12, 0.16, 0.0), ("starfish", 0.8, 0.17, 6.0), ("shell-spiral", 0.94, 0.11, 0.0)] {
                let s = sized(name, width: CGFloat(width) * u)
                out.append(SeaSceneItem(sprite: name, center: CGPoint(x: CGFloat(x) * w, y: h - 6 - s.height / 2), size: s,
                                        degrees: sin(t * 0.7) * wiggle))
            }
        case .flood:   // seagrass and kelp from the seabed, never taller than the water is deep
            for (i, (name, x, most, share)) in [("grass-tall", 0.07, 0.715, 0.92), ("grass-mid", 0.2, 0.494, 0.85),
                                                ("grass-short", 0.86, 0.286, 0.8), ("grass-mid", 0.95, 0.442, 0.85)].enumerated() {
                let s = tall(name, height: min(CGFloat(most) * u, depth * CGFloat(share)))
                out.append(SeaSceneItem(sprite: name, center: CGPoint(x: CGFloat(x) * w, y: h + 4 - s.height / 2), size: s,
                                        shear: sin(t * 0.7 + Double(i) * 1.7) * 0.08))
            }
        case .podWave: // baby rays drifting around her in slow loops
            guard swim else { return [] }
            let rays = [("ray-lilac", 0.14, 0.35), ("ray-mint", 0.86, 0.3), ("ray-blue", 0.2, 0.8)].prefix(shallow ? 2 : 3)
            for (i, (name, x, lane)) in rays.enumerated() {
                let flap = 1 + 0.05 * sin(t * 2.2 + Double(i))
                var s = sized(name, width: 0.15 * u * k)
                s.width *= CGFloat(flap)
                let cx = CGFloat(x) * w + CGFloat(sin(t * 0.25 + Double(i) * 2)) * 0.05 * w
                let cy = top + (bottom - top) * CGFloat(lane) + CGFloat(sin(t * 0.37 + Double(i))) * 0.04 * (bottom - top)
                out.append(SeaSceneItem(sprite: name, center: CGPoint(x: cx, y: underWave(cy, s)), size: s,
                                        degrees: sin(t * 0.4 + Double(i)) * 10))
            }
        default:
            break
        }
        return out
    }
}

/// Decoded scene sprites (small, decoded once).
enum SeaSprites {
    private static let lock = NSLock()
    private static var cache: [String: CGImage] = [:]

    static func image(_ name: String) -> CGImage? {
        lock.lock(); defer { lock.unlock() }
        if let c = cache[name] { return c }
        guard let url = RaynaFrames.root?.appendingPathComponent("scene/\(name).png"),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        cache[name] = img
        return img
    }
}

/// The worn scene, drawn into the water behind Rayna. Give it the same frame and progress as WaterBackground.
public struct SeaScene: View {
    public var scene: RaynaUnlock?
    public var progress: Double
    /// Draw one fixed moment instead of animating (snapshots and tests).
    var frozenTime: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(scene: RaynaUnlock?, progress: Double) {
        self.scene = scene; self.progress = progress
    }

    /// The scene in a set of worn badges, if any.
    public init(worn: Set<RaynaUnlock>, progress: Double) {
        self.init(scene: worn.first { $0.slot == .scene }, progress: progress)
    }

    public var body: some View {
        if let scene {
            TimelineView(.animation(minimumInterval: reduceMotion ? 60 : 1.0 / 30)) { tl in
                Canvas { ctx, size in
                    let t = frozenTime ?? (reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
                    for item in SeaSceneLayout.items(for: scene, progress: progress, size: size, time: t) {
                        draw(item, in: &ctx)
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func draw(_ item: SeaSceneItem, in ctx: inout GraphicsContext) {
        guard let cg = SeaSprites.image(item.sprite) else { return }
        var c = ctx
        if item.glow > 0 {
            let r = max(item.size.width, item.size.height) * 0.85
            c.fill(Path(ellipseIn: CGRect(x: item.center.x - r, y: item.center.y - r, width: 2 * r, height: 2 * r)),
                   with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.96, blue: 0.8).opacity(item.glow), .clear]),
                                         center: item.center, startRadius: r * 0.4, endRadius: r))
        }
        if item.underwater { c.addFilter(.colorMultiply(Color(red: 0.86, green: 0.95, blue: 1))) }
        // Sway about the bottom-centre, turn about the centre.
        c.translateBy(x: item.center.x, y: item.center.y + item.size.height / 2)
        if item.shear != 0 { c.concatenate(CGAffineTransform(a: 1, b: 0, c: -item.shear, d: 1, tx: 0, ty: 0)) }
        c.translateBy(x: 0, y: -item.size.height / 2)
        c.rotate(by: .degrees(item.degrees))
        if item.flipped { c.scaleBy(x: -1, y: 1) }
        c.draw(Image(decorative: cg, scale: 1),
               in: CGRect(x: -item.size.width / 2, y: -item.size.height / 2, width: item.size.width, height: item.size.height))
    }
}

/// A small animated aquarium for a scene badge (collection cards, the unlock card).
public struct SeaSceneCard: View {
    public var scene: RaynaUnlock
    public init(scene: RaynaUnlock) { self.scene = scene }
    public var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.75, green: 0.9, blue: 1), Color(red: 0.45, green: 0.72, blue: 0.95)],
                           startPoint: .top, endPoint: .bottom)
            WaterBackground(progress: 0.7)
            SeaScene(scene: scene, progress: 0.7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// A scene's stand-in sprite, for small marks (the "wearing" rows, swap toast).
struct SeaSceneMark: View {
    var scene: RaynaUnlock
    var body: some View {
        if let name = SeaSceneLayout.mark(scene), let cg = SeaSprites.image(name) {
            Image(decorative: cg, scale: 1).resizable().scaledToFit()
        }
    }
}
