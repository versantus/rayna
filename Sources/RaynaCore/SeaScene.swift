import SwiftUI
import ImageIO

// MARK: - Scene badges: life in the water around Rayna (fish, seagrass, moon and shells, baby rays)
//
// A scene has no water of its own. It is drawn into the ocean WaterBackground already draws, using the same
// waterline for the same progress and size: plants grow from the seabed and never above the water, swimmers stay
// below the waterline (fewer and smaller when it is shallow), and the moon needs sky above the water.
// Sprites ship in RaynaFrames/scene (cut from Higgsfield sheets by tools/rayna-frames/sprites.py).

extension SeaSceneLayout {
    /// The sprite that stands for a scene on small badge marks.
    public static func mark(_ scene: RaynaUnlock) -> String? {
        switch scene {
        case .surge: return "fish-yellow"
        case .tide: return "moon"
        case .flood: return "grass-mid"
        case .podWave: return "ray-mint"
        case .seabed: return "starfish"
        case .meadow: return "grass-short"
        default: return nil
        }
    }

    /// Items for a worn scene badge; nothing for badges that are not scenes.
    public static func items(for scene: RaynaUnlock, progress: Double, size: CGSize, time t: Double) -> [SeaSceneItem] {
        guard scene.slot == .scene, let kind = SeaSceneKind(rawValue: scene.rawValue) else { return [] }
        return items(for: kind, progress: progress, size: size, time: t)
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
