import Foundation

/// Where one badge slot sits in a frame: unit coordinates in the frame square, a clockwise turn,
/// and how visible the badge is (badges fade out while she turns side-on to swim away).
public struct RaynaSlotPose: Equatable {
    public var x: Double
    public var y: Double
    public var degrees: Double
    public var opacity: Double

    public init(x: Double, y: Double, degrees: Double = 0, opacity: Double = 1) {
        self.x = x; self.y = y; self.degrees = degrees; self.opacity = opacity
    }

    /// The resting pose (idle-happy, first frame) that badges are laid out in.
    /// Fin is 65% of the way from her chest to her right wing tip (see tools/rayna-frames/track.py).
    public static func rest(_ slot: BadgeSlot) -> RaynaSlotPose {
        switch slot {
        case .head: return RaynaSlotPose(x: 0.50, y: 0.07)
        case .chest: return RaynaSlotPose(x: 0.50, y: 0.44)
        case .fin: return RaynaSlotPose(x: 0.6955, y: 0.3749)
        case .scene: return RaynaSlotPose(x: 0.5, y: 0.5)     // the whole square; never moves
        }
    }
}

public typealias RaynaSlotPoses = [BadgeSlot: RaynaSlotPose]

/// Per-frame slot poses made by tools/rayna-frames/track.py and shipped as
/// `RaynaFrames/anchors/<clip>.json` and `anchors/stills.json`.
public enum RaynaAnchors {
    private static let lock = NSLock()
    private static var cache: [String: [RaynaSlotPoses]] = [:]

    /// `{"head": [[x, y, degrees, opacity], ...], "chest": ..., "fin": ...}`, one row per frame.
    static func decode(_ data: Data) -> [RaynaSlotPoses]? {
        guard let raw = try? JSONDecoder().decode([String: [[Double]]].self, from: data) else { return nil }
        return table(raw)
    }

    private static func table(_ raw: [String: [[Double]]]) -> [RaynaSlotPoses]? {
        let count = raw.values.map(\.count).min() ?? 0
        guard count > 0 else { return nil }
        return (0..<count).map { i in
            var poses: RaynaSlotPoses = [:]
            for slot in BadgeSlot.onBody {
                if let r = raw[slot.rawValue]?[i], r.count == 4 {
                    poses[slot] = RaynaSlotPose(x: r[0], y: r[1], degrees: r[2], opacity: r[3])
                }
            }
            return poses
        }
    }

    private static func load(_ key: String, _ build: (Data) -> [RaynaSlotPoses]?) -> [RaynaSlotPoses] {
        lock.lock(); defer { lock.unlock() }
        if let c = cache[key] { return c }
        var rows: [RaynaSlotPoses] = []
        if let url = RaynaFrames.root?.appendingPathComponent("anchors/\(key).json"),
           let data = try? Data(contentsOf: url) {
            rows = build(data) ?? []
        }
        cache[key] = rows
        return rows
    }

    /// Poses for one frame of a clip. Nil when the data is missing, so badges stay at rest.
    public static func poses(_ clip: RaynaClip, frame: Int) -> RaynaSlotPoses? {
        let rows = load(clip.rawValue, decode)
        guard !rows.isEmpty else { return nil }
        return rows[min(max(frame, 0), rows.count - 1)]
    }

    /// Poses for the still shown at `progress` (widgets, Reduce Motion, cards).
    public static func still(progress: Double) -> RaynaSlotPoses? {
        still(RaynaBand(progress: progress))
    }

    static func still(_ band: RaynaBand) -> RaynaSlotPoses? {
        let rows = load("stills") { data in
            guard let raw = try? JSONDecoder().decode([String: [String: [Double]]].self, from: data) else { return nil }
            return RaynaBand.allCases.map { b in
                table((raw[b.file] ?? [:]).mapValues { [$0] })?.first ?? [:]
            }
        }
        guard rows.indices.contains(band.rawValue), !rows[band.rawValue].isEmpty else { return nil }
        return rows[band.rawValue]
    }
}
