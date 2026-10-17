import CoreGraphics
import Foundation

// MARK: - Where scene sprites go, frame by frame (pure: no SwiftUI, no other RaynaCore types)
//
// Compiled into RaynaCore and, on its own, into the Watch app, so both draw the same scenes.
// Plants grow from the seabed and never above the water, swimmers stay below the waterline (fewer and smaller
// when it is shallow), and the moon needs sky above the water.

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

/// The four scenes. Raw values are the badge ids (`RaynaUnlock.rawValue`), which is also what the Watch receives.
public enum SeaSceneKind: String, CaseIterable {
    case surge, tide, flood, podWave
}

public enum SeaSceneLayout {
    /// The same waterline the iPhone's water uses (a test keeps them equal); repeated so the Watch can use this file alone.
    public static func waterline(progress: Double, height: CGFloat) -> CGFloat {
        let p = max(0, min(1, progress))
        return height * (1 - (0.06 + 0.88 * p))
    }

    /// Width / height of each sprite, so layout needs no image decoding.
    static let aspect: [String: CGFloat] = [
        "fish-yellow": 1.30, "fish-coral": 1.29, "fish-mint": 1.27, "fish-lilac": 1.27,
        "grass-tall": 0.346, "grass-mid": 0.419, "grass-short": 0.839,
        "moon": 1.02, "shell-scallop": 1.06, "shell-spiral": 0.78, "starfish": 0.97,
        "ray-lilac": 0.72, "ray-mint": 0.72, "ray-blue": 0.73,
    ]

    /// Everything to draw for `scene` at time `t` (seconds; 0 when Reduce Motion is on).
    /// `compact` is for the Watch: a smaller moon off to the side of the litres line, and seabed things only at the
    /// edges so the buttons along the bottom don't sit on top of them.
    public static func items(for scene: SeaSceneKind, progress: Double, size: CGSize, time t: Double,
                             compact: Bool = false) -> [SeaSceneItem] {
        let w = size.width, h = size.height
        guard w > 0, h > 0 else { return [] }
        let u = min(w, 520)                                   // sprite scale; an iPad doesn't get giant fish
        let line = waterline(progress: progress, height: h)
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
            let moon = sized("moon", width: (compact ? 0.15 : 0.22) * u)
            let moonTop = (compact ? 0.16 : 0.2) * h
            if line > moonTop + moon.height {
                out.append(SeaSceneItem(sprite: "moon", center: CGPoint(x: (compact ? 0.88 : 0.8) * w,
                                                                        y: moonTop + moon.height / 2 + CGFloat(sin(t * 0.5)) * 3),
                                        size: moon, underwater: false, glow: 0.35 + 0.15 * sin(t * 0.8)))
            }
            let sand: [(String, Double, Double, Double)] = compact
                ? [("shell-scallop", 0.08, 0.16, 0.0), ("starfish", 0.92, 0.17, 6.0)]
                : [("shell-scallop", 0.12, 0.16, 0.0), ("starfish", 0.8, 0.17, 6.0), ("shell-spiral", 0.94, 0.11, 0.0)]
            for (name, x, width, wiggle) in sand {
                let s = sized(name, width: CGFloat(width) * u)
                out.append(SeaSceneItem(sprite: name, center: CGPoint(x: CGFloat(x) * w, y: h - 6 - s.height / 2), size: s,
                                        degrees: sin(t * 0.7) * wiggle))
            }
        case .flood:   // seagrass and kelp from the seabed, never taller than the water is deep
            let clumps: [(String, Double, Double, Double)] = compact
                ? [("grass-tall", 0.05, 0.715, 0.92), ("grass-mid", 0.95, 0.494, 0.85)]
                : [("grass-tall", 0.07, 0.715, 0.92), ("grass-mid", 0.2, 0.494, 0.85),
                   ("grass-short", 0.86, 0.286, 0.8), ("grass-mid", 0.95, 0.442, 0.85)]
            for (i, (name, x, most, share)) in clumps.enumerated() {
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
        }
        return out
    }
}
