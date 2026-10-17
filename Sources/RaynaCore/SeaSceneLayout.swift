import CoreGraphics
import Foundation

// MARK: - Where scene sprites go, frame by frame (pure: no SwiftUI, no other RaynaCore types)
//
// Compiled into RaynaCore and, on its own, into the Watch app, so both draw the same scenes.
// Plants grow from the seabed and never above the water, swimmers stay below the waterline (fewer and smaller
// when it is shallow), and the moon needs sky above the water.

/// One thing drawn for one moment. `center` and `size` are in points in the scene's frame.
public struct SeaSceneItem: Equatable {
    /// How to draw it. Sprites use `sprite`; the rest are drawn in code.
    public enum Look: Equatable {
        case sprite
        /// A sprite that gives off light (jellyfish): drawn with a soft halo.
        case glow
        /// A shaft of light from the surface: `center.x` at the top, leaning by `shear`, `size.width` wide at the bottom.
        case ray
        /// A four-point twinkle of radius `size.width`.
        case sparkle
        /// A glowing speck (plankton) of radius `size.width`.
        case dot
        /// A rising bubble of radius `size.width`.
        case bubble
        /// Dusk below the waterline (`center.y`), deepening towards the bottom.
        case dusk
    }
    public var look: Look = .sprite
    public var opacity: Double = 1
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
    /// Free from the start.
    case seabed, meadow
    /// The scene & colour pack (not released yet).
    case reef, jellies, treasure, turtles
}

public enum SeaSceneLayout {
    /// The same waterline the iPhone's water uses (a test keeps them equal); repeated so the Watch can use this file alone.
    public static func waterline(progress: Double, height: CGFloat) -> CGFloat {
        let p = max(0, min(1, progress))
        return height * (1 - (0.06 + 0.88 * p))
    }

    /// Creatures with a swim-cycle animation (RaynaFrames/scene/anim/<loop>/NNN.png, a 5-second loop):
    /// sprite name → (loop folder, frame count). Babies and look-alikes share a loop.
    static let loops: [String: (loop: String, frames: Int)] = [
        "clown-big": ("clown", 40), "clown-small": ("clown", 40), "tang-blue": ("tang-blue", 40), "tang-yellow": ("tang-yellow", 40),
        "jelly-pink": ("jelly-pink", 40), "jelly-lilac": ("jelly-lilac", 40), "jelly-aqua": ("jelly-aqua", 40),
        "octopus": ("octopus", 40), "turtle": ("turtle", 40), "turtle-baby": ("turtle", 40), "seahorse": ("seahorse", 40),
        "fish-yellow": ("fish-yellow", 40), "fish-coral": ("fish-coral", 40), "fish-mint": ("fish-mint", 40), "fish-lilac": ("fish-lilac", 40),
        "ray-mint": ("ray-mint", 40), "ray-lilac": ("ray-lilac", 40), "ray-blue": ("ray-blue", 40),
    ]
    /// Seconds one loop takes, so limbs move at their natural speed.
    static let loopSeconds = 5.0

    /// The frame of `name`'s swim cycle at time `t` ("loop#NN"), or `name` itself when it has no animation.
    /// `phase` offsets each creature so two of the same kind don't flap in time.
    public static func animated(_ name: String, at t: Double, phase: Double = 0) -> String {
        guard let l = loops[name] else { return name }
        let k = ((t + phase * 1.37) / loopSeconds).truncatingRemainder(dividingBy: 1)
        let i = Int((k < 0 ? k + 1 : k) * Double(l.frames)) % l.frames
        return "\(l.loop)#\(i)"
    }

    /// The still sprite for an animated frame name (the Watch draws stills).
    public static func base(_ name: String) -> String {
        guard let hash = name.firstIndex(of: "#") else { return name }
        let loop = String(name[..<hash])
        return loops.first { $0.value.loop == loop }?.key ?? loop
    }

    /// Width / height of each sprite, so layout needs no image decoding.
    static let aspect: [String: CGFloat] = [
        "fish-yellow": 1.028, "fish-coral": 1.31, "fish-mint": 1.236, "fish-lilac": 1.215,
        "grass-tall": 0.346, "grass-mid": 0.419, "grass-short": 0.839,
        "moon": 1.02, "shell-scallop": 1.06, "shell-spiral": 0.78, "starfish": 0.97,
        "ray-lilac": 0.855, "ray-mint": 0.855, "ray-blue": 0.855,
        "reef-bed": 3.52, "wreck-bed": 3.05, "lagoon-bed": 4.09,
        "clown-big": 1.333, "clown-small": 1.333, "tang-blue": 1.606, "tang-yellow": 1.229,
        "jelly-pink": 0.677, "jelly-lilac": 0.686, "jelly-aqua": 0.668,
        "chest": 0.97, "coins": 1.57, "octopus": 1.279, "clam": 0.94,
        "turtle": 1.317, "turtle-baby": 1.317, "seahorse": 0.5,
    ]

    /// Everything to draw for `scene` at time `t` (seconds; 0 when Reduce Motion is on).
    /// `compact` is for the Watch: a smaller moon off to the side of the litres line, and seabed things only at the
    /// edges so the buttons along the bottom don't sit on top of them.
    public static func items(for scene: SeaSceneKind, progress: Double, size: CGSize, time t: Double,
                             compact: Bool = false) -> [SeaSceneItem] {
        var list = layout(for: scene, progress: progress, size: size, time: t, compact: compact)
        // Every creature plays its swim cycle; each gets its own offset (its place in the list) so they're not in step.
        for i in list.indices where loops[list[i].sprite] != nil {
            list[i].sprite = animated(list[i].sprite, at: t, phase: Double(i))
        }
        return list
    }

    private static func layout(for scene: SeaSceneKind, progress: Double, size: CGSize, time t: Double,
                               compact: Bool) -> [SeaSceneItem] {
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
        case .seabed:  // free: shells and a starfish on the sand
            let sand: [(String, Double, Double, Double)] = compact
                ? [("shell-scallop", 0.08, 0.16, 0.0), ("starfish", 0.92, 0.17, 6.0)]
                : [("shell-scallop", 0.1, 0.17, 0.0), ("shell-spiral", 0.27, 0.11, 0.0),
                   ("starfish", 0.76, 0.18, 6.0), ("shell-scallop", 0.93, 0.12, 0.0)]
            for (i, (name, x, width, wiggle)) in sand.enumerated() {
                let s = sized(name, width: CGFloat(width) * u)
                out.append(SeaSceneItem(sprite: name, center: CGPoint(x: CGFloat(x) * w, y: h - 6 - s.height / 2), size: s,
                                        degrees: sin(t * 0.7 + Double(i)) * wiggle, flipped: i == 3))
            }
        case .meadow:  // free: a low seagrass meadow along the bottom (Flood tide is the tall kelp forest)
            let clumps: [(String, Double, Double)] = compact
                ? [("grass-short", 0.06, 0.2), ("grass-short", 0.94, 0.17)]
                : [("grass-short", 0.06, 0.2), ("grass-short", 0.24, 0.15), ("grass-short", 0.76, 0.17), ("grass-short", 0.94, 0.21)]
            for (i, (name, x, most)) in clumps.enumerated() {
                let s = tall(name, height: min(CGFloat(most) * u, depth * 0.8))
                out.append(SeaSceneItem(sprite: name, center: CGPoint(x: CGFloat(x) * w, y: h + 4 - s.height / 2), size: s,
                                        shear: sin(t * 0.8 + Double(i) * 1.3) * 0.09, flipped: i % 2 == 1))
            }
        case .reef, .jellies, .treasure, .turtles:
            out = premium(scene, w: w, h: h, u: u, line: line, depth: depth, top: top, bottom: bottom,
                          swim: swim, shallow: shallow, t: t, compact: compact)
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

    // MARK: The scene & colour pack
    //
    // Each scene layers a seabed backdrop, creatures with their own uneven rhythms (so it never feels like a short
    // loop), and effects drawn in code: light shafts, bubbles, twinkles, glowing plankton.

    private static func premium(_ scene: SeaSceneKind, w: CGFloat, h: CGFloat, u: CGFloat, line: CGFloat, depth: CGFloat,
                                top: CGFloat, bottom: CGFloat, swim: Bool, shallow: Bool, t: Double, compact: Bool) -> [SeaSceneItem] {
        var out: [SeaSceneItem] = []
        let band = max(1, bottom - top)
        func sized(_ name: String, _ width: CGFloat) -> CGSize { CGSize(width: width, height: width / (aspect[name] ?? 1)) }
        func under(_ y: CGFloat, _ s: CGSize) -> CGFloat { max(y, line + s.height / 2 + 6) }
        func s(_ v: Double) -> CGFloat { CGFloat(sin(v)) }

        /// Seabed art along the bottom, wider than the screen; sinks out of the way when the water is shallow.
        func bed(_ name: String, scale: CGFloat = 1.4) {
            let size = sized(name, w * scale)
            let y = max(h - size.height / 2 + 2, line + 30 + size.height / 2)
            out.append(SeaSceneItem(sprite: name, center: CGPoint(x: w / 2, y: y), size: size))
        }
        /// Light shafts from the surface, swaying slowly.
        func rays(_ count: Int, warm: Bool = false) {
            for i in 0..<count {
                let x = w * (0.1 + 0.8 * CGFloat(i) / CGFloat(max(1, count - 1))) + s(t * 0.35 + Double(i)) * 14
                out.append(SeaSceneItem(look: .ray, opacity: (warm ? 0.10 : 0.12) + 0.05 * sin(t * 0.7 + Double(i) * 2),
                                        sprite: warm ? "warm" : "", center: CGPoint(x: x, y: line),
                                        size: CGSize(width: 40 + 14 * s(t * 0.5 + Double(i)), height: h - line),
                                        shear: Double(0.12 + 0.05 * sin(t * 0.3 + Double(i)))))
            }
        }
        /// Bubbles rising from a point, staggered.
        func bubbles(from x: CGFloat, _ count: Int, every: Double, seed: Double) {
            for i in 0..<count {
                let k = ((t + seed + Double(i) * every / Double(count)).truncatingRemainder(dividingBy: every)) / every
                let y = (h - 20) - CGFloat(k) * (h - 20 - line)
                guard y > line + 6 else { continue }
                out.append(SeaSceneItem(look: .bubble, opacity: 0.7 * (1 - k * 0.6), sprite: "",
                                        center: CGPoint(x: x + s(t * 2 + Double(i)) * 5, y: y),
                                        size: CGSize(width: 2 + CGFloat(i % 3) * 1.5, height: 0)))
            }
        }
        /// A swimmer meandering left and right (turning to face the way it goes), with a tail waggle.
        func meander(_ name: String, width: CGFloat, centreX: CGFloat, range: CGFloat, lane: CGFloat, speed: Double, phase: Double) {
            let x = centreX + range * s(t * speed + phase) + range * 0.3 * s(t * speed * 2.3 + phase * 1.7)
            let vx = cos(t * speed + phase) + 0.69 * cos(t * speed * 2.3 + phase * 1.7)
            var size = sized(name, width)
            size.width *= 1 + 0.05 * s(t * 9 + phase)                 // tail waggle
            let y = top + band * lane + s(t * 0.9 + phase) * band * 0.06
            out.append(SeaSceneItem(sprite: name, center: CGPoint(x: x, y: under(y, size)), size: size,
                                    degrees: Double(s(t * 1.7 + phase)) * 5, flipped: vx < 0))
        }
        /// A swimmer crossing the screen and wrapping round.
        func cross(_ name: String, width: CGFloat, lane: CGFloat, speed: CGFloat, phase: Double, right: Bool = true) {
            var size = sized(name, width)
            size.width *= 1 + 0.04 * s(t * 8 + phase)
            let span = w + 2 * size.width
            var x = (CGFloat(phase) * span + CGFloat(t) * speed * (right ? 1 : -1)).truncatingRemainder(dividingBy: span)
            if x < 0 { x += span }
            let y = top + band * lane + s(t * 0.7 + phase) * band * 0.05
            out.append(SeaSceneItem(sprite: name, center: CGPoint(x: x - size.width, y: under(y, size)), size: size,
                                    degrees: Double(s(t * 1.3 + phase)) * 4, flipped: !right))
        }
        func twinkle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ phase: Double, speed: Double = 2.6) {
            let a = max(0, sin(t * speed + phase))
            guard a > 0.05 else { return }
            out.append(SeaSceneItem(look: .sparkle, opacity: a, sprite: "", center: CGPoint(x: x, y: y), size: CGSize(width: r * (0.6 + 0.6 * CGFloat(a)), height: 0)))
        }

        switch scene {
        case .reef:
            rays(compact ? 3 : 5)
            bed("reef-bed")
            for i in 0..<(compact ? 3 : 9) {                       // polyps glowing on the reef
                twinkle(w * (0.06 + 0.11 * CGFloat(i)), h - 30 - CGFloat((i * 37) % 50), compact ? 3 : 4, Double(i) * 1.9, speed: 1.6)
            }
            bubbles(from: w * 0.2, 4, every: 7, seed: 0); bubbles(from: w * 0.78, 3, every: 9, seed: 3)
            guard swim else { break }
            let f: CGFloat = compact ? 0.8 : 1
            meander("clown-big", width: 0.15 * u * f, centreX: w * 0.35, range: w * 0.22, lane: 0.72, speed: 0.31, phase: 0)
            meander("clown-small", width: 0.11 * u * f, centreX: w * 0.35, range: w * 0.22, lane: 0.8, speed: 0.31, phase: -0.45)   // follows the big one
            cross("tang-blue", width: 0.2 * u * f, lane: 0.42, speed: u * 0.07, phase: 0.2)
            if !compact {
                meander("tang-yellow", width: 0.16 * u, centreX: w * 0.68, range: w * 0.2, lane: 0.25, speed: 0.23, phase: 2)
                // now and then, two little fish dart across fast
                let dash = (t / 13).truncatingRemainder(dividingBy: 1)
                if dash < 0.35 {
                    let x = -40 + CGFloat(dash / 0.35) * (w + 80)
                    for (k, n) in ["fish-yellow", "fish-mint"].enumerated() {
                        let sz = sized(n, 0.08 * u)
                        out.append(SeaSceneItem(sprite: n, center: CGPoint(x: x - CGFloat(k) * 34, y: under(top + band * (0.55 + 0.08 * CGFloat(k)), sz)), size: sz))
                    }
                }
            }
        case .jellies:
            out.append(SeaSceneItem(look: .dusk, sprite: "", center: CGPoint(x: w / 2, y: line), size: CGSize(width: w, height: h - line)))
            for i in 0..<(compact ? 8 : 22) {                      // glowing plankton
                let x = (CGFloat(i * 53) + CGFloat(t) * 6).truncatingRemainder(dividingBy: w)
                let y = line + 8 + CGFloat((i * 37) % 100) / 100 * (depth - 16) + s(t * 0.5 + Double(i)) * 6
                out.append(SeaSceneItem(look: .dot, opacity: 0.35 + 0.35 * sin(t * 2.6 + Double(i)), sprite: "",
                                        center: CGPoint(x: x, y: y), size: CGSize(width: 1.4, height: 0)))
            }
            guard swim else { break }
            let jellies: [(String, CGFloat, CGFloat, Double)] = compact
                ? [("jelly-pink", 0.22, 0.2, 0), ("jelly-aqua", 0.8, 0.17, 1.7)]
                : [("jelly-pink", 0.2, 0.17, 0), ("jelly-aqua", 0.8, 0.15, 1.7), ("jelly-lilac", 0.32, 0.13, 3.1),
                   ("jelly-aqua", 0.9, 0.09, 4.4), ("jelly-pink", 0.62, 0.08, 5.2)]
            for (i, (name, x0, width, phase)) in jellies.enumerated() {
                let pulse = sin(t * 2.2 + phase)
                var size = sized(name, width * u * (shallow ? 0.75 : 1))
                size.width *= 1 + 0.05 * CGFloat(pulse)
                size.height *= 1 - 0.07 * CGFloat(pulse)
                // rise slowly through the water, then start again from below
                let cycle = 26 + Double(i) * 5
                let k = ((t + phase * 7) .truncatingRemainder(dividingBy: cycle)) / cycle
                let y = bottom + size.height * 0.4 - CGFloat(k) * (bottom - top + size.height * 0.4)
                let fade = min(1, min(k / 0.08, (1 - k) / 0.08))
                out.append(SeaSceneItem(look: .glow, opacity: 0.92 * fade, sprite: name,
                                        center: CGPoint(x: w * x0 + s(t * 0.4 + phase) * 16, y: under(y, size)), size: size,
                                        degrees: Double(s(t * 0.6 + phase)) * 6))
            }
        case .treasure:
            rays(compact ? 3 : 4, warm: true)
            bed("wreck-bed")
            let chest = sized("chest", (compact ? 0.24 : 0.24) * u)
            let chestC = CGPoint(x: w * (compact ? 0.82 : 0.78), y: h - 8 - chest.height / 2)
            if !compact {
                var clam = sized("clam", 0.17 * u)
                clam.height *= 1 + 0.03 * s(t * 0.9)            // breathing
                out.append(SeaSceneItem(sprite: "clam", center: CGPoint(x: w * 0.56, y: h - 6 - clam.height / 2), size: clam))
                bubbles(from: w * 0.56, 4, every: 6, seed: 1)
                let coins = sized("coins", 0.18 * u)
                out.append(SeaSceneItem(sprite: "coins", center: CGPoint(x: w * 0.93, y: h - 4 - coins.height / 2), size: coins))
            }
            // the octopus peeks out from behind the chest, has a look round, and hides again
            let cycle = 16.0, k = t.truncatingRemainder(dividingBy: cycle) / cycle
            let up = CGFloat(min(1, max(0, min(k / 0.15, (1 - k) / 0.15))))
            if up > 0.02 {
                let oct = sized("octopus", (compact ? 0.2 : 0.2) * u)
                let y = chestC.y - chest.height * 0.15 - up * oct.height * 0.8 + s(t * 1.4) * 4
                out.append(SeaSceneItem(sprite: "octopus", center: CGPoint(x: chestC.x - chest.width * 0.15 + s(t * 0.8) * 6, y: max(y, line + oct.height / 2 + 6)),
                                        size: oct, degrees: Double(s(t * 1.1)) * 8))
            }
            out.append(SeaSceneItem(sprite: "chest", center: chestC, size: chest))
            for i in 0..<(compact ? 3 : 6) {                       // glints on the gold
                twinkle(chestC.x + (CGFloat(i % 3) - 1) * chest.width * 0.28, chestC.y - chest.height * (0.15 + 0.12 * CGFloat(i / 3)), 5, Double(i) * 1.3)
            }
            if swim, !compact {                                    // a little shoal passes through every so often
                let pass = (t / 21).truncatingRemainder(dividingBy: 1)
                if pass < 0.5 {
                    let x = w + 60 - CGFloat(pass / 0.5) * (w + 160)
                    for k in 0..<4 {
                        let sz = sized("fish-yellow", 0.07 * u)
                        out.append(SeaSceneItem(sprite: "fish-yellow", center: CGPoint(x: x + CGFloat(k % 2) * 26 + CGFloat(k) * 18,
                                                                                    y: under(top + band * (0.3 + 0.06 * CGFloat(k)) + s(t * 3 + Double(k)) * 3, sz)),
                                                size: sz, flipped: true))
                    }
                }
            }
        case .turtles:
            rays(compact ? 3 : 5)
            bed("lagoon-bed")
            for i in 0..<(compact ? 2 : 6) { twinkle(w * (0.12 + 0.15 * CGFloat(i)), h - 14 - CGFloat(i % 2) * 8, 3, Double(i) * 2.1, speed: 1.3) }
            bubbles(from: w * 0.15, 3, every: 8, seed: 2)
            guard swim else { break }
            // mother and baby glide across together, with a slow swimming stroke
            let span = w + 0.7 * u, speed = u * 0.045
            let x = (CGFloat(t) * speed + w * 0.3).truncatingRemainder(dividingBy: span) - 0.3 * u
            let stroke = s(t * 1.6)
            var mum = sized("turtle", (compact ? 0.32 : 0.36) * u)
            mum.height *= 1 + 0.04 * stroke
            out.append(SeaSceneItem(sprite: "turtle", center: CGPoint(x: x, y: under(top + band * 0.35 + stroke * 6, mum)), size: mum, degrees: Double(stroke) * 3))
            if !compact || !shallow {
                let baby = sized("turtle-baby", (compact ? 0.15 : 0.17) * u)
                out.append(SeaSceneItem(sprite: "turtle-baby", center: CGPoint(x: x - mum.width * 0.75, y: under(top + band * 0.52 + s(t * 1.6 + 1) * 6, baby)),
                                        size: baby, degrees: Double(s(t * 1.6 + 1)) * 4))
            }
            let horse = sized("seahorse", (compact ? 0.08 : 0.09) * u)
            out.append(SeaSceneItem(sprite: "seahorse", center: CGPoint(x: w * 0.86 + s(t * 0.4) * 10, y: under(top + band * 0.62 + s(t * 1.2) * 14, horse)),
                                    size: horse, degrees: Double(s(t * 1.2 + 0.5)) * 7))
            if !compact { meander("fish-mint", width: 0.08 * u, centreX: w * 0.3, range: w * 0.18, lane: 0.75, speed: 0.5, phase: 1.2) }
        default:
            break
        }
        return out
    }
}

