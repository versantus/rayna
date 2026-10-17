import SwiftUI
import ImageIO
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Higgsfield Rayna: bundled PNG frame sequences (256 px, alpha, 12 fps)

/// One animation clip shipped in `RaynaFrames/<name>/NNN.png`.
public enum RaynaClip: String, CaseIterable {
    case idleHappy = "idle-happy", idleThirsty = "idle-thirsty"
    case wiggle, swimIn = "swim-in", swimOff = "swim-off", poutSwimOff = "pout-swim-off"

    /// Playback rate. Source art is 24 fps; we ship every other frame.
    public var fps: Double { 12 }
    public var loops: Bool { self == .idleHappy || self == .idleThirsty }
    /// Frames shipped per clip (fixed so durations are known before frames are decoded).
    public var frameCount: Int {
        switch self {
        case .idleHappy: return 48
        case .idleThirsty: return 62
        case .wiggle: return 15
        case .swimIn: return 49
        case .swimOff: return 46
        case .poutSwimOff: return 49
        }
    }
    public var duration: Double { Double(frameCount) / fps }
}

/// The five widget / Reduce Motion stills, by progress band.
public enum RaynaBand: Int, CaseIterable {
    case thirsty = 0, meh, fine, happy, goal
    public init(progress p: Double) {
        switch p {
        case ..<0.15: self = .thirsty
        case ..<0.35: self = .meh
        case ..<0.75: self = .fine
        case ..<1.0: self = .happy
        default: self = .goal
        }
    }
    var file: String { "band\(rawValue)" }
}

public enum RaynaFrames {
    private final class Token {}
    private static let lock = NSLock()
    private static var cache: [String: [CGImage]] = [:]
    private static var loading: Set<String> = []
    /// Frames decode here, one clip at a time, never on the main thread.
    private static let queue = DispatchQueue(label: "co.versantus.rayna.frames", qos: .userInitiated)

    /// Finds `Rayna_RaynaCore.bundle` wherever the host put it (Xcode app/appex, SwiftPM .app, swift run).
    /// Cheap locations first; only scans loaded bundles as a last resort.
    static let root: URL? = {
        let name = "Rayna_RaynaCore.bundle"
        func probe(_ base: URL?) -> URL? {
            guard let base else { return nil }
            for u in [base.appendingPathComponent(name).appendingPathComponent("RaynaFrames"),
                      base.appendingPathComponent(name).appendingPathComponent("Contents/Resources/RaynaFrames"),
                      base.appendingPathComponent("RaynaFrames")]
            where FileManager.default.fileExists(atPath: u.path) { return u }
            return nil
        }
        let quick: [URL?] = [Bundle.main.resourceURL, Bundle.main.bundleURL,
                             Bundle(for: Token.self).resourceURL, Bundle(for: Token.self).bundleURL,
                             Bundle.main.executableURL?.deletingLastPathComponent()]
        for b in quick { if let u = probe(b) { return u } }
        for b in Bundle.allBundles.map({ $0.resourceURL }) + Bundle.allFrameworks.map({ $0.resourceURL }) {
            if let u = probe(b) { return u }
        }
        return nil
    }()

    private static func decode(_ url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }

    private static func cached(_ key: String) -> [CGImage]? {
        lock.lock(); defer { lock.unlock() }
        return cache[key]
    }

    /// Decode a clip in the background (no-op if cached or already loading).
    private static func loadAsync(_ dir: String) {
        lock.lock()
        if cache[dir] != nil || loading.contains(dir) { lock.unlock(); return }
        loading.insert(dir); lock.unlock()
        queue.async {
            var imgs: [CGImage] = []
            if let root {
                let d = root.appendingPathComponent(dir)
                let files = ((try? FileManager.default.contentsOfDirectory(atPath: d.path)) ?? [])
                    .filter { $0.hasSuffix(".png") }.sorted()
                imgs = files.compactMap { decode(d.appendingPathComponent($0)) }
            }
            lock.lock(); cache[dir] = imgs; loading.remove(dir); lock.unlock()
        }
    }

    /// Frames for a clip if they're decoded; otherwise starts decoding and returns [] (callers show a still).
    public static func frames(_ clip: RaynaClip) -> [CGImage] {
        if let c = cached(clip.rawValue) { return c }
        loadAsync(clip.rawValue)
        return []
    }
    public static func isReady(_ clip: RaynaClip) -> Bool { cached(clip.rawValue).map { !$0.isEmpty } ?? false }

    /// One 512 px still: small enough to decode synchronously, so something shows on the very first frame.
    public static func still(_ band: RaynaBand) -> CGImage? {
        let key = "stills/" + band.file
        if let c = cached(key) { return c.first }
        guard let root, let img = decode(root.appendingPathComponent("stills/\(band.file).png")) else { return nil }
        lock.lock(); cache[key] = [img]; lock.unlock()
        return img
    }
    /// Warm clips in the background, in the order given (put the visible idle loop first).
    public static func preload(_ clips: [RaynaClip]) { clips.forEach { loadAsync($0.rawValue) } }
    /// The idle loop for `progress` first, then the rest after a short delay.
    public static func preloadForLaunch(progress: Double) {
        preload([progress >= 0.45 ? .idleHappy : .idleThirsty, .wiggle])
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) { preload(RaynaClip.allCases) }
    }
}

/// A still Rayna for the given progress band (widgets, Reduce Motion).
public struct RaynaStill: View {
    public var progress: Double
    public init(progress: Double) { self.progress = progress }
    public var body: some View {
        if let img = RaynaFrames.still(RaynaBand(progress: progress)) {
            Image(decorative: img, scale: 1).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
        } else {
            Color.clear
        }
    }
}

/// A one-shot clip request (used by the nudge panel): play `clips` back to back from `start`.
public struct RaynaScript: Equatable {
    public var clips: [RaynaClip]
    public var start: Date
    /// Loop this after the script ends (nil = hold the last frame).
    public var then: RaynaClip?
    public init(_ clips: [RaynaClip], start: Date = Date(), then: RaynaClip? = nil) {
        self.clips = clips; self.start = start; self.then = then
    }
    public var duration: Double { clips.reduce(0) { $0 + $1.duration } }
}

/// Size of the live ray in the gap between the quip and the stats.
/// She aims for 90% of that slot's width, and shrinks only when the slot is shorter than that.
public enum RaynaStage {
    public static let widthFraction: CGFloat = 0.90

    public static func side(width: CGFloat, height: CGFloat) -> CGFloat {
        guard width > 0, height > 0 else { return 0 }
        return min(width * widthFraction, height)
    }
}

/// Animated Rayna: picks a clip by state and plays its frames with TimelineView.
/// idle-happy (progress ≥ 45%) / idle-thirsty loops, wiggle on +1 glass, a code-driven spin at goal,
/// or an explicit `script` (nudge panel). Reduce Motion shows the band still.
public struct RaynaView: View {
    public var progress: Double
    public var wiggleAt: Date? = nil
    public var flipAt: Date? = nil
    public var pout = false
    public var size: CGFloat = 100
    public var fullTail = false
    public var script: RaynaScript? = nil
    /// Up to one badge in each slot (head, chest, fin).
    public var accessories: Set<RaynaUnlock> = []
    /// Brighten badges that sit under the immersive waterline.
    public var brightenAccessories = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(progress: Double, wiggleAt: Date? = nil, flipAt: Date? = nil, pout: Bool = false,
                size: CGFloat = 100, fullTail: Bool = false, script: RaynaScript? = nil,
                accessories: Set<RaynaUnlock> = [], brightenAccessories: Bool = false) {
        self.progress = progress; self.wiggleAt = wiggleAt; self.flipAt = flipAt; self.pout = pout
        self.size = size; self.fullTail = fullTail; self.script = script; self.accessories = accessories
        self.brightenAccessories = brightenAccessories
    }

    public var body: some View {
        Group {
            if reduceMotion {
                RaynaStill(progress: progress).overlay(RaynaAccessories(unlocks: accessories, date: .distantPast, brighten: brightenAccessories,
                                                                         poses: RaynaAnchors.still(progress: progress)))
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                    if let shown = shown(at: tl.date) {
                        let _ = LaunchTiming.mark("firstAnimatedFrame")
                        let sp = spin(at: tl.date)
                        Image(decorative: shown.image, scale: 1).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                            .overlay(RaynaAccessories(unlocks: accessories, date: tl.date, brighten: brightenAccessories,
                                                      poses: RaynaAnchors.poses(shown.clip, frame: shown.index)))
                            .rotationEffect(.degrees(sp.angle))
                            .scaleEffect(sp.scale)
                            .offset(y: sp.lift * size)
                    } else if script != nil {
                        Color.clear                      // nudge: don't flash a static Rayna before swim-in
                    } else {
                        let _ = LaunchTiming.mark("firstStill")
                        RaynaStill(progress: progress)   // shown while the clip decodes
                    }
                }
            }
        }
        .frame(width: size, height: fullTail ? size * 1.32 : size)
        .accessibilityLabel("Rayna the stingray, \(Int(progress * 100)) percent hydrated")
    }

    /// Goal celebration: a joyful in-plane 360° spin with a little scale-up and bob (code-driven;
    /// replaces the generated barrel roll, which twisted her body unnaturally).
    public static let spinDuration = 1.6
    func spin(at date: Date) -> (angle: Double, scale: Double, lift: Double) {
        guard script == nil, let f = flipAt else { return (0, 1, 0) }
        let t = date.timeIntervalSince(f) / Self.spinDuration
        guard t >= 0, t < 1 else { return (0, 1, 0) }
        let e = t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2   // easeInOutCubic
        let hump = sin(.pi * t)
        return (360 * e, 1 + 0.14 * hump, -0.06 * hump)
    }

    private var idle: RaynaClip { progress >= 0.45 ? .idleHappy : .idleThirsty }

    /// One decoded frame and where it sits in its clip (the badges look up their poses by that).
    struct Shown {
        var image: CGImage
        var clip: RaynaClip
        var index: Int
    }

    private func pick(_ clip: RaynaClip, _ age: Double) -> Shown? {
        let f = RaynaFrames.frames(clip)
        guard !f.isEmpty else { return nil }
        var i = Int(age * clip.fps)
        i = clip.loops ? ((i % f.count) + f.count) % f.count : min(max(i, 0), f.count - 1)
        return Shown(image: f[i], clip: clip, index: i)
    }

    func shown(at date: Date) -> Shown? {
        if let s = script {
            var age = date.timeIntervalSince(s.start)
            for c in s.clips {
                if age < c.duration { return pick(c, max(age, 0)) }
                age -= c.duration
            }
            if let t = s.then { return pick(t, age) }
            return s.clips.last.flatMap { pick($0, $0.duration) }
        }
        if let f = flipAt, date.timeIntervalSince(f) >= 0, date.timeIntervalSince(f) < Self.spinDuration {
            return pick(.idleHappy, date.timeIntervalSince(f))   // wings keep flapping while she spins
        }
        if let w = wiggleAt, date.timeIntervalSince(w) >= 0, date.timeIntervalSince(w) < RaynaClip.wiggle.duration {
            return pick(.wiggle, date.timeIntervalSince(w))
        }
        return pick(idle, date.timeIntervalSinceReferenceDate)
    }
}
