import SwiftUI
import ImageIO
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Higgsfield Rayna: bundled PNG frame sequences (256 px, alpha, 12 fps)

/// One animation clip shipped in `RaynaFrames/<name>/NNN.png`.
public enum RaynaClip: String, CaseIterable {
    case idleHappy = "idle-happy", idleThirsty = "idle-thirsty"
    case wiggle, roll, swimIn = "swim-in", swimOff = "swim-off", poutSwimOff = "pout-swim-off"

    /// Playback rate. Source art is 24 fps; we ship every other frame.
    public var fps: Double { self == .roll ? 18 : 12 }
    public var loops: Bool { self == .idleHappy || self == .idleThirsty }
    public var duration: Double { Double(RaynaFrames.frames(self).count) / fps }
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

    /// Finds `Rayna_RaynaCore.bundle` wherever the host put it (Xcode app/appex, SwiftPM .app, swift run).
    static let root: URL? = {
        let name = "Rayna_RaynaCore.bundle"
        var c: [URL?] = [Bundle.main.resourceURL, Bundle.main.bundleURL,
                         Bundle(for: Token.self).resourceURL, Bundle(for: Token.self).bundleURL,
                         Bundle.main.executableURL?.deletingLastPathComponent()]
        c += Bundle.allBundles.map { $0.resourceURL } + Bundle.allFrameworks.map { $0.resourceURL }
        for base in c.compactMap({ $0 }) {
            for u in [base.appendingPathComponent(name).appendingPathComponent("RaynaFrames"),
                      base.appendingPathComponent(name).appendingPathComponent("Contents/Resources/RaynaFrames"),
                      base.appendingPathComponent("RaynaFrames")]
            where FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return nil
    }()

    private static func load(_ dir: String) -> [CGImage] {
        lock.lock(); defer { lock.unlock() }
        if let c = cache[dir] { return c }
        guard let root else { return [] }
        let d = root.appendingPathComponent(dir)
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: d.path)) ?? [])
            .filter { $0.hasSuffix(".png") }.sorted()
        let imgs = files.compactMap { f -> CGImage? in
            guard let src = CGImageSourceCreateWithURL(d.appendingPathComponent(f) as CFURL, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        }
        cache[dir] = imgs
        return imgs
    }

    public static func frames(_ clip: RaynaClip) -> [CGImage] { load(clip.rawValue) }
    public static func still(_ band: RaynaBand) -> CGImage? {
        lock.lock(); let c = cache["stills/" + band.file]; lock.unlock()
        if let c { return c.first }
        guard let root, let src = CGImageSourceCreateWithURL(root.appendingPathComponent("stills/\(band.file).png") as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        lock.lock(); cache["stills/" + band.file] = [img]; lock.unlock()
        return img
    }
    /// Warm the cache off the main thread.
    public static func preload(_ clips: [RaynaClip] = RaynaClip.allCases) {
        DispatchQueue.global(qos: .utility).async { clips.forEach { _ = frames($0) } }
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

/// Animated Rayna: picks a clip by state and plays its frames with TimelineView.
/// idle-happy (progress ≥ 45%) / idle-thirsty loops, wiggle on +1 glass, roll at goal,
/// or an explicit `script` (nudge panel). Reduce Motion shows the band still.
public struct RaynaView: View {
    public var progress: Double
    public var wiggleAt: Date? = nil
    public var flipAt: Date? = nil
    public var pout = false
    public var size: CGFloat = 100
    public var fullTail = false
    public var script: RaynaScript? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(progress: Double, wiggleAt: Date? = nil, flipAt: Date? = nil, pout: Bool = false,
                size: CGFloat = 100, fullTail: Bool = false, script: RaynaScript? = nil) {
        self.progress = progress; self.wiggleAt = wiggleAt; self.flipAt = flipAt; self.pout = pout
        self.size = size; self.fullTail = fullTail; self.script = script
    }

    public var body: some View {
        Group {
            if reduceMotion {
                RaynaStill(progress: progress)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24)) { tl in
                    if let img = frame(at: tl.date) {
                        Image(decorative: img, scale: 1).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                    } else {
                        RaynaStill(progress: progress)
                    }
                }
            }
        }
        .frame(width: size, height: fullTail ? size * 1.32 : size)
        .accessibilityLabel("Rayna the stingray, \(Int(progress * 100)) percent hydrated")
    }

    private var idle: RaynaClip { progress >= 0.45 ? .idleHappy : .idleThirsty }

    private func pick(_ clip: RaynaClip, _ age: Double) -> CGImage? {
        let f = RaynaFrames.frames(clip)
        guard !f.isEmpty else { return nil }
        var i = Int(age * clip.fps)
        i = clip.loops ? ((i % f.count) + f.count) % f.count : min(max(i, 0), f.count - 1)
        return f[i]
    }

    func frame(at date: Date) -> CGImage? {
        if let s = script {
            var age = date.timeIntervalSince(s.start)
            for c in s.clips {
                if age < c.duration { return pick(c, max(age, 0)) }
                age -= c.duration
            }
            if let t = s.then { return pick(t, age) }
            return s.clips.last.flatMap { RaynaFrames.frames($0).last }
        }
        if let f = flipAt, date.timeIntervalSince(f) >= 0, date.timeIntervalSince(f) < RaynaClip.roll.duration {
            return pick(.roll, date.timeIntervalSince(f))
        }
        if let w = wiggleAt, date.timeIntervalSince(w) >= 0, date.timeIntervalSince(w) < RaynaClip.wiggle.duration {
            return pick(.wiggle, date.timeIntervalSince(w))
        }
        return pick(idle, date.timeIntervalSinceReferenceDate)
    }
}
